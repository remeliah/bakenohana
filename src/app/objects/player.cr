require "./stats"
require "./status"
require "./channel"

require "../consts/priv"
require "../packets/packets"
require "../repo/relationship"
require "../repo/user"

require "../state/geoloc"

class Player
  getter token : String
  getter username : String
  getter ip : String
  getter login_time : Time
  getter id : Int32
  
  @last_recv_time : Time = Time.utc
  @last_recv_mut = Mutex.new

  property stats : PlayerStats = PlayerStats.new
  property status : PlayerStatus = PlayerStatus.new

  property priv : Privileges

  @friends = Set(Int32).new
  @friends_mut = Mutex.new

  @channels = Array(Channels).new
  @channels_mut = Mutex.new

  property spectators : Array(Player) = [] of Player
  property spectating : Player? = nil

  @queue = IO::Memory.new
  @queue_mut = Mutex.new

  def initialize(
    @id : Int32,
    @username : String, 
    @token : String,
    @ip : String,
    @login_time : Time,
    @priv : Privileges
  )
    @priv = priv
  end

  def enqueue(data : Bytes)
    @queue_mut.synchronize do
      @queue.write data
    end
  end

  def dequeue : Bytes
    @queue_mut.synchronize do
      buf = @queue.to_slice
      @queue = IO::Memory.new
      buf
    end
  end

  def last_recv_time
    @last_recv_mut.synchronize { @last_recv_time }
  end

  def last_recv_time=(time : Time)
    @last_recv_mut.synchronize { @last_recv_time = time }
  end

  def friends : Set(Int32)
    @friends_mut.synchronize { @friends.dup }
  end

  def enrich_geo
    if geo = Geoloc.fetch(@ip)
      @status.latitude = geo.latitude.to_f32
      @status.longitude = geo.longitude.to_f32
      @status.country_code = geo.country_num.to_i32
      @status.country = geo.country_acr.to_s
    end
  end

  def update_offset(offset : Int32)
    @status.utc_offset = offset
  end

  def client_priv : ClientPrivileges # TODO: cache?
    ret = ClientPrivileges::None
    ret |= ClientPrivileges::PLAYER     if @priv & Privileges::UNRESTRICTED != 0
    ret |= ClientPrivileges::MODERATOR  if @priv & Privileges::MODERATOR != 0 || @priv & Privileges::ADMINISTRATOR != 0
    ret |= ClientPrivileges::DEVELOPER  if @priv & Privileges::DEVELOPER != 0
    ret |= ClientPrivileges::PEPPY      if @priv & Privileges::PEPPY != 0
    ret
  end

  def restricted : Bool
    !@priv.includes?(Privileges::UNRESTRICTED)
  end

  def add_friend(player : Player) : Nil
    if @friends_mut.synchronize { @friends.includes?(player.id) }
      rlog "#{@username} tries to add #{player.username}, whos already their friend!", Ansi::LYELLOW
      return
    end

    @friends_mut.synchronize { @friends.add(player.id) }

    RelationshipRepo.create(@id, player.id)
    
    rlog "#{@username} friended #{player.username}."
  end

  def remove_friend(player : Player) : Nil
    unless @friends_mut.synchronize { @friends.includes?(player.id) }
      rlog "#{@username} tries to unfriend #{player.username}, whos not their friend!", Ansi::LYELLOW
      return
    end

    @friends_mut.synchronize { @friends.delete(player.id) }
    
    RelationshipRepo.delete(@id, player.id)
    
    rlog "#{@username} unfriended #{player.username}."
  end

  def get_relationship : Nil
    relation = RelationshipRepo.fetch_all_for(@id)
    
    @friends_mut.synchronize do
      @friends.clear
      relation.each do |rel|
        case rel.type
        when "friend"
          @friends.add(rel.user2)
        when "block"
          # TODO: Add blocks set and mutex
          # @blocks.add(user2_id)
        end
      end
    end
  end

  private def set_priv(priv : Privileges) : Nil
    @priv = priv
    UserRepo.update(
      id: @id,
      priv: @priv.value
    )

    rlog "updated #{@username} (#{@id}) priv to #{@priv.to_s}"
  end

  def add_priv(priv : Privileges) : Nil
    set_priv(@priv | priv)
  end

  def rem_priv(priv : Privileges) : Nil
    set_priv(@priv & ~priv)
  end

  def logout
    if h = @spectating
      h.remove_spectator(self)
    end

    while !@channels_mut.synchronize { @channels.empty? }
      first_channel = @channels_mut.synchronize { @channels.first? }
      break unless first_channel
      leave_channel(first_channel, kick: false)
    end

    PlayerSession.remove(@token)

    logout_packet = Packets.logout(@id)
    PlayerSession.each do |other_player, _|
      next if other_player.token == @token
      other_player.enqueue(logout_packet)
    end

    @queue_mut.synchronize do
      @queue = IO::Memory.new
    end
    
    rlog "#{@username} (#{@id}) logged out"
  end

  # channel stuff

  def channels : Array(Channels)
    @channels_mut.synchronize { @channels.dup }
  end

  def add_channel(channel : Channels)
    @channels_mut.synchronize do
      @channels << channel unless @channels.includes?(channel)
    end
  end

  def remove_channel(channel : Channels)
    @channels_mut.synchronize do
      @channels.delete(channel)
    end
  end

  def join_channel(channel : Channels) : Bool
    if channel.includes?(self) || 
      !channel.can_read?(@priv)
      return false
    end

    channel.append(self)

    add_channel(channel)

    enqueue(Packets.channel_join(channel.name))

    chan_info_packet = Packets.channel_info(channel.name, channel.topic, channel.player_count)
    
    if channel.instance
      channel.players.each do |p|
        p.enqueue(chan_info_packet)
      end
    else
      PlayerSession.each do |p, _|
        if channel.can_read?(p.priv)
          p.enqueue(chan_info_packet)
        end
      end
    end
    
    true
  end

  def leave_channel(channel : Channels, kick : Bool = true) : Nil
    return unless channel.includes?(self)

    channel.remove(self)

    remove_channel(channel)
    
    if kick
      enqueue(Packets.channel_kick(channel.name))
    end

    chan_info_packet = Packets.channel_info(channel.name, channel.topic, channel.player_count)
    
    if channel.instance
      channel.players.each do |p|
        p.enqueue(chan_info_packet)
      end
    else
      PlayerSession.each do |p, _|
        if channel.can_read?(p.priv)
          p.enqueue(chan_info_packet)
        end
      end
    end
  end

  def send_msg(msg : String, sender : Player, chan : Channel | Nil = nil) : Nil
    target = chan.try(&.name) || @username

    data = Packets.send_message(
      sender.username,
      msg,
      target,
      sender.id
    )

    enqueue(data)
  end

  # spectating shit

  def add_spectator(player : Player) : Nil
    chan_name = "#spec_#{@id}"

    spec_chan = ChannelSession.get_by_name(chan_name)
    unless spec_chan
      spec_chan = Channels.new(
        name: chan_name,
        topic: "#{@username}'s spectator channel.",
        auto_join: false,
        instance: true
      )

      join_channel(spec_chan)
      ChannelSession.append(spec_chan)
    end

    unless player.join_channel(spec_chan)
      rlog "#{@username} failed to join #{spec_chan}?", Ansi::LYELLOW
      return
    end

    player_joined = Packets.f_spectator_joined(player.id)
    @spectators.each do |spectator|
      spectator.enqueue(player_joined)
      player.enqueue(Packets.f_spectator_joined(spectator.id))
    end
    enqueue(Packets.spectator_joined(player.id))

    @spectators << player
    player.spectating = self

    rlog "#{player.username} is now spectating #{@username}"
  end

  def remove_spectator(player : Player) : Nil
    @spectators.delete(player)
    player.spectating = nil

    channel = ChannelSession.get_by_name("#spec_#{@id}")
    raise "missing channel?" unless channel

    player.leave_channel(channel)

    if @spectators.empty?
      leave_channel(channel)
    else
      channel_info = Packets.channel_info(
        channel.name,
        channel.topic,
        channel.player_count
      )

      fellow = Packets.f_spectator_left(player.id)
      enqueue(channel_info)

      @spectators.each do |spectator|
        spectator.enqueue(fellow + channel_info)
      end
    end

    enqueue(Packets.spectator_left(player.id))
    rlog "#{player.username} is no longer spectating #{@username}"
  end
end
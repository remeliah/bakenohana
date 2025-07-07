require "./stats"
require "./status"
require "./channel"

require "../consts/priv"
require "../packets/packets"

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

  def client_priv : ClientPrivileges # TODO: cache?
    ret = ClientPrivileges::None
    ret |= ClientPrivileges::PLAYER     if @priv & Privileges::UNRESTRICTED != 0
    ret |= ClientPrivileges::SUPPORTER  if @priv & Privileges::SUPPORTER != 0
    ret |= ClientPrivileges::MODERATOR  if @priv & Privileges::MODERATOR != 0
    ret |= ClientPrivileges::DEVELOPER  if @priv & Privileges::ADMINISTRATOR != 0
    ret |= ClientPrivileges::OWNER      if @priv & Privileges::DEVELOPER != 0
    ret
  end

  def restricted : Bool
    !@priv.includes?(Privileges::UNRESTRICTED)
  end

  def add_friend(player : Player) : Nil
    if @friends_mut.synchronize { @friends.includes?(player.id) }
      puts "#{@username} tries to add #{player.username}, whos already their friend!"
      return
    end

    @friends_mut.synchronize { @friends.add(player.id) }
    
    Services.db.execute(
      "replace into relationships (user1, user2, type) values (?, ?, 'friend')",
      @id, player.id
    )
    
    puts "#{@username} friended #{player.username}."
  end

  def remove_friend(player : Player) : Nil
    unless @friends_mut.synchronize { @friends.includes?(player.id) }
      puts "#{@username} tries to unfriend #{player.username}, whos not their friend!"
      return
    end

    @friends_mut.synchronize { @friends.delete(player.id) }
    
    Services.db.execute(
      "delete from relationships where user1 = ? and user2 = ?",
      @id, player.id
    )
    
    puts "#{@username} unfriended #{player.username}."
  end

  def get_relationship : Nil
    rows = Services.db.fetch_all( # TODO: store on repo?
      "select user2, type from relationships where user1 = ?",
      @id
    )
    
    @friends_mut.synchronize do
      @friends.clear
      rows.each do |row|
        user2_id = row["user2"].as(Int32)
        relationship_type = row["type"].as(String)
        
        case relationship_type
        when "friend"
          @friends.add(user2_id)
        when "block"
          # TODO: Add blocks set and mutex
          # @blocks.add(user2_id)
        end
      end
    end
  end

  def logout
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
    
    puts "player #{@username} (#{@id}) logged out"
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

  def send(msg : String, sender : Player, chan : Channel | Nil = nil) : Nil
    target = chan.try(&.name) || @username

    data = Packets.send_message(
      sender.username,
      msg,
      target,
      sender.id
    )

    enqueue(data)
  end
end
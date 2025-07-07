require "../consts/priv"

class Channels
  getter name : String
  getter r_name : String
  getter topic : String
  getter read_priv : Privileges
  getter write_priv : Privileges
  getter auto_join : Bool
  getter instance : Bool

  @_name : String
  @players = Array(Player).new
  @players_mut = Mutex.new

  def initialize(
    name : String,
    @topic : String,
    @read_priv : Privileges = Privileges::NORMAL,
    @write_priv : Privileges = Privileges::NORMAL,
    @auto_join : Bool = true,
    @instance : Bool = false
  )
    @_name = name
    @r_name = name
    
    if @_name.starts_with?("#spec_")
      @name = "#spectator"
    elsif @_name.starts_with?("#multi_")
      @name = "#multiplayer"
    else
      @name = @_name
    end
  end

  def to_s(io)
    io << "<#{@_name}>"
  end

  def includes?(player : Player) : Bool
    @players_mut.synchronize do
      @players.includes?(player)
    end
  end

  def can_read?(priv : Privileges) : Bool
    return true if @read_priv == Privileges::None
    (priv & @read_priv) != Privileges::None
  end

  def can_write?(priv : Privileges) : Bool
    return true if @write_priv == Privileges::None
    (priv & @write_priv) != Privileges::None
  end

  def send(msg : String, sender : Player, to_self : Bool = false) : Nil
    data = Packets.send_message(
      sender.username,
      msg,
      @name,
      sender.id
    )

    @players_mut.synchronize do
      @players.each do |p|
        if to_self || p.id != sender.id
          p.enqueue(data)
        end
      end
    end
  end

  def send_selective(msg : String, sender : Player, recipients : Set(Player)) : Nil
    recipients.each do |p|
      if includes?(p)
        p.send(msg, sender: sender, chan: self)
      end
    end
  end

  def append(player : Player) : Nil
    @players_mut.synchronize do
      @players << player
    end
  end

  def remove(player : Player) : Nil
    @players_mut.synchronize do
      @players.delete(player)
      
      if @players.empty? && @instance
        # if it's an instance channel and this
        # is the last member leaving, just remove
        # the channel from the global list.
        ChannelSession.remove(self)
      end
    end
  end

  def enqueue(data : Bytes, immune : Array(Int32) = [] of Int32) : Nil
    @players_mut.synchronize do
      @players.each do |p|
        unless immune.includes?(p.id)
          p.enqueue(data)
        end
      end
    end
  end

  def players : Array(Player)
    @players_mut.synchronize { @players.dup }
  end

  def player_count : Int32
    @players_mut.synchronize { @players.size }
  end
end
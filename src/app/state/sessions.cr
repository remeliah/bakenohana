require "../objects/channel"

module PlayerSession
  @@players = Hash(String, Player).new
  @@bot : Player = Player.new( # TODO: use db
    id: 1,
    username: "boat",
    token: "_bot",
    ip: "0",
    login_time: Time.utc,
    priv: Privileges::BOAT
  )
  @@mutex = Mutex.new

  def self.add(token : String, p : Player)
    @@mutex.synchronize do
      @@players[token] = p
    end
  end

  def self.get(token : String) : Player?
    @@mutex.synchronize do
      @@players[token]?
    end
  end

  def self.get(*, token : String? = nil, id : Int32? = nil, username : String? = nil) : Player?
    @@mutex.synchronize do
      if token
        @@players[token]?
      elsif id
        return @@bot if id == 1
        @@players.values.find { |player| player.id == id }
      elsif username
        return @@bot if username == "boat" # trolage
        @@players.values.find { |player| player.username == username }
      else
        nil
      end
    end
  end

  def self.bot : Player
    @@bot
  end

  def self.players : Hash(String, Player)
    @@mutex.synchronize { @@players.dup }
  end

  def self.remove(token : String)
    @@mutex.synchronize do
      @@players.delete(token)
    end
  end

  def self.each(&block : Player, String ->)
    yield @@bot, @@bot.token
    # HACK: to avoid holding lock during iter
    players_ = @@mutex.synchronize { @@players.dup }
    players_.each do |token, player|
      yield player, token
    end
  end

  def self.restricted : Set(Player)
    @@mutex.synchronize do
      @@players.values.select(&.restricted).to_set
    end
  end

  def self.unrestricted : Set(Player)
    @@mutex.synchronize do
      @@players.values.reject(&.restricted).to_set
    end
  end
end

module ChannelSession
  @@channels = Array(Channels).new
  @@mutex = Mutex.new

  def self.each(&block : Channels ->)
    # HACK: to avoid holding lock during iter
    channels_ = @@mutex.synchronize { @@channels.dup }
    channels_.each do |channel|
      yield channel
    end
  end

  def self.includes?(o : Channels | String) : Bool
    @@mutex.synchronize do
      case o
      when String
        @@channels.any? { |c| c.name == o }
      when Channel
        @@channels.includes?(o)
      else
        false
      end
    end
  end

  def self.[](index : Int32) : Channels
    @@mutex.synchronize do
      @@channels[index]
    end
  end

  def self.[](index : Range(Int32, Int32)) : Array(Channels)
    @@mutex.synchronize do
      @@channels[index]
    end
  end

  def self.[](name : String) : Channels?
    get_by_name(name)
  end

  def self.[]?(index : Int32) : Channels?
    @@mutex.synchronize do
      @@channels[index]?
    end
  end

  def self.[]?(name : String) : Channels?
    get_by_name(name)
  end

  def self.to_s(io)
    @@mutex.synchronize do
      io << "["
      @@channels.join(io, ", ") { |c, io| io << c.r_name }
      io << "]"
    end
  end

  def self.get_by_name(name : String) : Channels?
    @@mutex.synchronize do
      @@channels.find { |c| c.r_name == name }
    end
  end

  def self.append(channel : Channels) : Nil
    @@mutex.synchronize do
      @@channels << channel
    end
  end

  def self.extend(channels : Array(Channels)) : Nil
    @@mutex.synchronize do
      @@channels.concat(channels)
    end
  end

  def self.remove(channel : Channels) : Nil
    @@mutex.synchronize do
      @@channels.delete(channel)
    end
  end

  def self.size : Int32
    @@mutex.synchronize { @@channels.size }
  end

  def self.empty? : Bool
    @@mutex.synchronize { @@channels.empty? }
  end

  def self.channels : Array(Channels)
    @@mutex.synchronize { @@channels.dup }
  end

  def self.auto_join : Array(Channels)
    @@mutex.synchronize do
      @@channels.select(&.auto_join)
    end
  end

  def self.instances : Array(Channels)
    @@mutex.synchronize do
      @@channels.select(&.instance)
    end
  end

  def self.prepare : Nil
    rlog "fetching channels from sql.", Ansi::LCYAN
    
    channels_data = Services.db.fetch_all("select * from channels")
    
    channels_data.each do |row|
      channel = Channels.new(
        name: row["name"].as(String),
        topic: row["topic"].as(String),
        read_priv: Privileges.new(row["read_priv"].as(Int32)),
        write_priv: Privileges.new(row["write_priv"].as(Int32)),
        auto_join: row["auto_join"].as(Int32) == 1,
        instance: false
      )
      
      append(channel)
    end
    
    rlog "loaded #{size} channels from database.", Ansi::LGREEN
  end
end
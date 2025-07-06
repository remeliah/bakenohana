module PlayerSession
  @@players = Hash(String, Player).new
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
        @@players.values.find { |player| player.id == id }
      elsif username
        @@players.values.find { |player| player.username == username }
      else
        nil
      end
    end
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
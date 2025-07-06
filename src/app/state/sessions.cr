module PlayerSession
  @@players = Hash(String, Player).new

  def self.add(token : String, p : Player)
    @@players[token] = p
  end

  def self.get(token : String) : Player?
    @@players[token]?
  end

  def self.get(*, token : String? = nil, id : Int32? = nil) : Player?
    if token
      @@players[token]?
    elsif id
      @@players.values.find { |player| player.id == id }
    else
      nil
    end
  end

  def self.players : Enumerable(String, Player)
    @@players
  end

  def self.remove(token : String)
    @@players.delete(token)
  end

  def self.each(&block : Player, String ->)
    @@players.each do |token, player|
      yield player, token
    end
  end

  def self.restricted : Set(Player)
    @@players.values.select(&.restricted).to_set
  end

  def self.unrestricted : Set(Player)
    @@players.values.reject(&.restricted).to_set
  end
end
module PlayerSession
  @@players = Hash(String, Player).new

  def self.add(token : String, p : Player)
    @@players[token] = p
  end

  def self.get(token : String) : Player?
    @@players[token]?
  end
end
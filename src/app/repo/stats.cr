require "db"

struct StatsRepo
  include DB::Serializable

  @[DB::Field(name: "id")]
  property id : Int32

  @[DB::Field(name: "mode")]
  property mode : Int32

  @[DB::Field(name: "tscore")]
  property tscore : Int32

  @[DB::Field(name: "rscore")]
  property rscore : Int32

  @[DB::Field(name: "pp")]
  property pp : Int32

  @[DB::Field(name: "plays")]
  property plays : Int32

  @[DB::Field(name: "playtime")]
  property playtime : Int32

  @[DB::Field(name: "acc")]
  property acc : Float64

  @[DB::Field(name: "max_combo")]
  property max_combo : Int32

  @[DB::Field(name: "total_hits")]
  property total_hits : Int32

  @[DB::Field(name: "replay_views")]
  property replay_views : Int32

  @[DB::Field(name: "xh_count")]
  property xh_count : Int32

  @[DB::Field(name: "x_count")]
  property x_count : Int32

  @[DB::Field(name: "sh_count")]
  property sh_count : Int32

  @[DB::Field(name: "s_count")]
  property s_count : Int32

  @[DB::Field(name: "a_count")]
  property a_count : Int32

  def self.create(user_id : Int32, mode : Int32) : DB::ExecResult
    Services.db.execute(
      "insert into stats (id, mode) values (?, ?)",
      user_id, mode
    )
  end

  def self.create_all_modes(user_id : Int32) : Nil
    modes = [0, 1, 2, 3, 4, 5, 6, 8]
    modes.each do |mode|
      create(user_id, mode)
    end
  end

  def self.fetch_all_for(user_id : Int32) : Array(self)
    Services.db.fetch_all(self, "select * from stats where id = ?", user_id)
  end
end
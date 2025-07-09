require "db"

struct RelationshipRepo
  include DB::Serializable

  @[DB::Field(name: "user1")]
  property user1 : Int32

  @[DB::Field(name: "user2")]
  property user2 : Int32

  @[DB::Field(name: "type")]
  property type : String

  def self.create(user1 : Int32, user2 : Int32, type : String = "friend") : DB::ExecResult
    Services.db.execute(
      "replace into relationships (user1, user2, type) values (?, ?, ?)",
      user1, user2, type
    )
  end

  def self.delete(user1 : Int32, user2 : Int32) : DB::ExecResult
    Services.db.execute(
      "delete from relationships where user1 = ? and user2 = ?",
      user1, user2
    )
  end

  def self.fetch_all_for(user1 : Int32) : Array(self)
    Services.db.fetch_all(self, "select * from relationships where user1 = ?", user1)
  end
end
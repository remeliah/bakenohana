require "db"

struct ChanRepo
  include DB::Serializable

  @[DB::Field]
  property id : Int32

  @[DB::Field]
  property name : String

  @[DB::Field(name: "topic")]
  property topic : String

  @[DB::Field(name: "read_priv")]
  property read_priv : Int32

  @[DB::Field(name: "write_priv")]
  property write_priv : Int32

  @[DB::Field(name: "auto_join")]
  property auto_join : Bool

  # TODO: add more?
  def self.fetch_all : Array(self)
    Services.db.fetch_all(self, "select * from channels")
  end
end
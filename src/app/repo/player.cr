require "db"

struct User
  include DB::Serializable

  @[DB::Field]
  property id : Int32

  @[DB::Field(name: "name")]
  property name : String

  @[DB::Field(name: "safe_name")]
  property safe_name : String

  @[DB::Field]
  property priv : Int32

  @[DB::Field(name: "pw_bcrypt")]
  property pw_bcrypt : String

  @[DB::Field]
  property country : String

  @[DB::Field(name: "silence_end")]
  property silence_end : Int64

  @[DB::Field(name: "donor_end")]
  property donor_end : Int64

  @[DB::Field(name: "creation_time")]
  property creation_time : Int64

  @[DB::Field(name: "latest_activity")]
  property latest_activity : Int64

  @[DB::Field(name: "preferred_mode")]
  property preferred_mode : Int32

  @[DB::Field(name: "play_style")]
  property play_style : Int32

  @[DB::Field(name: "userpage_content")]
  property userpage_content : String?
end
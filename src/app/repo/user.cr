require "db"

struct UserRepo # ngl playing with gulag gives me a habit of making these
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

  def self.fetch_one(id : Int32) : self?
    Services.db.fetch_one(self, "select * from users where id = ?", id)
  end

  def self.fetch_one(name : String) : self?
    Services.db.fetch_one(self, "select * from users where name = ?", name)
  end

  def self.fetch_all : Array(self)
    Services.db.fetch_all(self, "select * from users")
  end

  def self.update(id : Int32, name : String? = nil, safe_name : String? = nil, priv : Int32? = nil,
                  pw_bcrypt : String? = nil, country : String? = nil, silence_end : Int64? = nil,
                  donor_end : Int64? = nil, creation_time : Int64? = nil, latest_activity : Int64? = nil,
                  preferred_mode : Int32? = nil, play_style : Int32? = nil, userpage_content : String? = nil) : DB::ExecResult

    updates = {} of String => DB::Any
    updates["name"] = name if name
    updates["safe_name"] = safe_name if safe_name
    updates["priv"] = priv if priv
    updates["pw_bcrypt"] = pw_bcrypt if pw_bcrypt
    updates["country"] = country if country
    updates["silence_end"] = silence_end if silence_end
    updates["donor_end"] = donor_end if donor_end
    updates["creation_time"] = creation_time if creation_time
    updates["latest_activity"] = latest_activity if latest_activity
    updates["preferred_mode"] = preferred_mode if preferred_mode
    updates["play_style"] = play_style if play_style
    updates["userpage_content"] = userpage_content if userpage_content

    raise "no fields to update" if updates.empty?

    set_ = updates.keys.map { |k| "#{k} = ?" }.join(", ")
    values = updates.values.to_a
    values << id

    query = "update users set #{set_} where id = ?"
    Services.db.execute(query, values)
  end
end

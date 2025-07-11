require "db"
require "../models/login_data"

struct UserHashRepo
  include DB::Serializable

  @[DB::Field]
  property user_id : Int32

  @[DB::Field(name: "adapters_hash")]
  property adapters_hash : String

  @[DB::Field(name: "uninstall_hash")]
  property uninstall_hash : String

  @[DB::Field(name: "disk_serial_number")]
  property disk_serial_number : String

  @[DB::Field(name: "last_ip")]
  property last_ip : String

  @[DB::Field(name: "seen_count")]
  property seen_count : Int32

  def self.create(user_id : Int32, login_data : LoginData, ip : String) : DB::ExecResult
    Services.db.execute(
      " insert into users_hash (user_id, adapters_hash, uninstall_hash, disk_serial_number, last_ip)
        values (?, ?, ?, ?, ?)
        on duplicate key update seen_count = seen_count + 1 ", # yo gurt
      user_id, login_data.adapters_md5, login_data.uninstall_md5, login_data.disk_signature_md5, ip
    )
  end

  def self.fetch_hw_conflict(column : String, value : String, user_id : Int32) : DB::Any?
    Services.db.fetch_val(
      "select user_id from users_hash where #{column} = ? and user_id != ?",
      value, user_id
    )
  end

  def self.fetch_all_for(user_id : Int32) : Array(self)
    Services.db.fetch_all(self, "select * from users_hash where user_id = ?", user_id)
  end
end
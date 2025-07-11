require "../repo/user"
require "../repo/user_hash"
require "../models/login_data"

require "crypto/bcrypt"

module Auth
  def self.authenticate(username : String, untrusted_password : String) : UserRepo?
    user = UserRepo.fetch_one(username)
    return nil unless user

    parsed = Crypto::Bcrypt::Password.new(user.pw_bcrypt)
    
    verified = begin
      # it took my pc 5558.784176ms to verify the hash (wow)
      # TODO: figure it out
      parsed.verify(untrusted_password)
    rescue
      false
    end

    return nil unless verified
    user
  end

  def self.validate_adapters(user_id : Int32, login_data : LoginData, ip : String) : Bool
    return false if login_data.username.empty? || login_data.password_md5.size != 32
    return false unless login_data.adapters_str # ? already checked on parse_login
    conf_found = false

    checks = {
      "adapters_hash"     => login_data.adapters_md5,
      "uninstall_hash"    => login_data.uninstall_md5,
      "disk_serial_number"=> login_data.disk_signature_md5,
      "last_ip"           => ip
    }

    checks.each do |col, val|
      next if col == "disk_serial_number" && val == "runningunderwine"

      if UserHashRepo.has_hw_conflict?(col, val, user_id)
        conf_found = true
      end
    end

    # i should validate osu version too
    UserHashRepo.create(user_id, login_data, ip)
    !conf_found
  end
end
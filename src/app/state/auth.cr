require "./services"
require "crypto/bcrypt"

module Auth
  def self.authenticate(username : String, untrusted_password : String) : User?
    user = Services.db.fetch_one_as(User, "select * from users where name = ?", username)
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
end
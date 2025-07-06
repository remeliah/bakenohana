require "./services"

module Auth
  @@cache = {} of String => User
  @@bcrypt_cache = {} of Tuple(String, String) => Bool
  @@locks = {} of String => Mutex
  @@mutex = Mutex.new

  def self.authenticate(username : String, untrusted_password : String) : User?
    lock = @@mutex.synchronize do
      @@locks[username] ||= Mutex.new
    end

    lock.synchronize do
      if user = @@cache[username]?
        return user
      end

      user = Services.db.fetch_one_as(User, "select * from users where name = ?", username)
      return nil unless user

      key = {user.pw_bcrypt, untrusted_password}
      verified = @@bcrypt_cache[key] ||= Crypto::Bcrypt::Password.new(user.pw_bcrypt).verify(untrusted_password)
      return nil unless verified

      # in-memory cache because
      # it took my pc 5558.784176ms to verify the hash (wow)
      # TODO: figure it out
      @@cache[username] = user
      user
    end
  end
end
require "../consts/regex"

require "../repo/user"
require "../repo/stats"

require "crypto/bcrypt"

module Web
  def self.register_routes(r : Kemal::RouteHandler)
    r.add_route "POST", "/users" do |env|
      username      = env.params.body["user[username]"]?
      email         = env.params.body["user[user_email]"]?
      pw_plaintext  = env.params.body["user[password]"]?
      check         = env.params.body["check"]?.try &.to_i || 0
      forwarded_ip  = env.request.headers["X-Forwarded-For"]?
      real_ip       = env.request.headers["X-Real-IP"]?

      unless username && email && pw_plaintext
        env.response.status_code = 400
        next "missing required params"
      end

      errors = Hash(String, Array(String)).new

      unless USERNAME_REGEX.matches?(username)
        errors["username"] << "must be 2-18 characters and use only space or underscore."
      end

      if username.includes?(" ") && username.includes?("_")
        errors["username"] << "may contain ' ' or '_', but not both."
      end

      if !errors.has_key?("username") && UserRepo.fetch_one(name: username)
        errors["username"] << "username already taken."
      end

      # FUCK I FORGOT TO MAKE EMAIL ROW
      #unless EMAIL_REGEX.matches?(email)
        #errors["user_email"] << "invalid email syntax."
      #end

      if pw_plaintext.size < 4 || pw_plaintext.size > 32
        errors["password"] << "must be 4–32 characters in length."
      end

      if pw_plaintext.chars.uniq.size <= 3
        errors["password"] << "must have more than 3 unique characters."
      end

      if !errors.empty?
        env.response.status_code = 400
        joined = errors.transform_values(&.join("\n"))
        next joined.to_json
      end

      if check == 0
        pw_md5 = Digest::MD5.hexdigest(pw_plaintext)
        pw_bcrypt = Crypto::Bcrypt::Password.create(pw_md5)

        ip = real_ip || forwarded_ip || ""
        if geo = Geoloc.fetch(ip)
          country_acr = geo.country_acr.to_s
        end

        player = UserRepo.create(
          name: username,
          email: email,
          pw_bcrypt: pw_bcrypt.to_s,
          country: country_acr || "xx"
        )

        StatsRepo.create_all_modes(player.id)

        rlog "#{username} (#{player.id}) has registered!", Ansi::LCYAN
      end

      "ok"
    end
  end
end
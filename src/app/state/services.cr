require "dotenv"
require "../objects/database"

module Services
  @@mysql : Database? = nil

  def self.init
    @@mysql = Database.new(
        "mysql://#{ENV["DB_USER"]}:#{ENV["DB_PASS"]}@#{ENV["DB_HOST"]}:#{ENV["DB_PORT"]}/#{ENV["DB_NAME"]}"
    )
  end

  def self.db : Database
    @@mysql.not_nil!
  end
end

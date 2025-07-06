require "kemal"
require "dotenv"

require "./app/routes/bancho"

require "./app/state/services"

Dotenv.load
Services.init

module Bakenohana
  VERSION = "0.1.0"

  if port_str = ENV["PORT"]?
    Kemal.config.port = port_str.to_i
  end

  puts "hop on"
  Kemal.run
end

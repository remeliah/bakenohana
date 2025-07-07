require "kemal"
require "dotenv"
Dotenv.load

require "./app/routes/bancho"
require "./app/routes/avatar"

require "./app/state/services"
require "./app/state/sessions"

# TODO: move these
Services.init
ChannelSession.prepare

module Bakenohana
  VERSION = "0.1.0"

  if port_str = ENV["PORT"]?
    Kemal.config.port = port_str.to_i
  end

  puts "hop on"
  Kemal.run
end

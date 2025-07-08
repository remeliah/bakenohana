require "kemal"
require "dotenv"
Dotenv.load

require "./app/config" # load early since im not calling this everytime
require "./app/log"

require "./app/routes/bancho"
require "./app/routes/avatar"

require "./app/state/services"
require "./app/state/sessions"

require "./app/init_router"

# TODO: move these
Services.init
ChannelSession.prepare

module Bakenohana
  # "Kemal is ready to lead at" sybau
  Log.setup do |c|
    c.bind "kemal", Log::Severity::None, Log::IOBackend.new(IO::Memory.new)
  end
  Kemal.config.logging = false

  if port_str = ENV["PORT"]?
    Kemal.config.port = port_str.to_i
  end

  init_routes # this initialize middleware too!

  rlog "hop on localhost:#{port_str}", Ansi::LBLUE
  Kemal.run
end

require "./middleware"

require "./routes/bancho"
require "./routes/avatar"
require "./routes/web"

def init_routes
  # NOTE: root will be handled on frontend, maybe
  ["c", "ce", "c4", "c5", "c6"].each do |sub|
    Middleware.sub(sub) do |r|
      Cho.register_routes(r)
    end
  end

  Middleware.sub("a") { |r| Ava.register_routes(r) }
  Middleware.sub("osu") { |r| Web.register_routes(r) }

  Middleware.register_all
end
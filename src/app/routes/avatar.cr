require "file_utils"

AVATARS_PATH = Path.new(Dir.current) / ENV["AVA_PATH"]
DEFAULT_AVATAR = AVATARS_PATH / "default.jpg"

# a.ppy.sh

get "/favicon.ico" do |env|
  if File.exists?(DEFAULT_AVATAR)
    send_file env, DEFAULT_AVATAR.to_s, "image/ico"
  else
    env.response.status_code = 404
    "default avatar not found"
  end
end

get "/:user_id" do |env|
  user_id = env.params.url["user_id"]

  begin
    user_id_int = user_id.to_i
  rescue ArgumentError
    env.response.status_code = 400
    next "invalid user_id format"
  end

  ["jpg", "jpeg", "png"].each do |extension| # TODO: gifs
    avatar_path = AVATARS_PATH / "#{user_id_int}.#{extension}"
    if File.exists?(avatar_path)
      send_file env, avatar_path.to_s, _get_type(extension)
      break
    end
  end

  if File.exists?(DEFAULT_AVATAR)
    send_file env, DEFAULT_AVATAR.to_s, "image/jpeg"
  else
    env.response.status_code = 404
    "default avatar not found"
  end
end

def _get_type(extension : String) : String
  case extension.downcase
  when "jpg", "jpeg"
    "image/jpeg"
  when "png"
    "image/png"
  when "ico"
    "image/ico"
  else
    "application/octet-stream"
  end
end

Dir.mkdir_p(AVATARS_PATH) unless Dir.exists?(AVATARS_PATH)
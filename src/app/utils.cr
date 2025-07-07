def get_image_type(extension : String) : String
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
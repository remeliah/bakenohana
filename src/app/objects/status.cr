require "../consts/mods"
require "../consts/mode"

struct PlayerStatus # maybe soon i will remove this and put it on player object
  property action : UInt8 = 0
  property info_text : String = ""

  property map_md5 : String = ""
  property map_id : Int32 = 0

  property mods : Mods = Mods::NOMOD
  property mode : Gamemode = Gamemode::VN_OSU

  property latitude : Float32 = 0
  property longitude : Float32 = 0
  property country_code : Int32 = 0

  property country : String = ""

  property utc_offset : Int32 = 0
end

MODE_STR_LIST = {
  "vn!std",
  "vn!taiko",
  "vn!catch",
  "vn!mania",
  "rx!std",
  "rx!taiko",
  "rx!catch",
  "rx!mania",
  "ap!std",
  "ap!taiko",
  "ap!catch",
  "ap!mania"
}

enum Gamemode : UInt8
  VN_OSU
  VN_TAIKO
  VN_CATCH
  VN_MANIA
  RX_OSU
  RX_TAIKO
  RX_CATCH
  RX_MANIA
  AP_OSU
  AP_TAIKO
  AP_CATCH
  AP_MANIA

  def self.from_params(vn : UInt8, mods : Mods) : Gamemode
    mode = vn
    if mods.includes?(Mods::AUTOPILOT)
      mode += 8
    elsif mods.includes?(Mods::RELAX)
      mode += 4
    end
    Gamemode.new(mode)
  end

  def self.valid_gamemodes : Array(Gamemode)
    @@valid_gamemodes ||= begin
      exc = {
        Gamemode::RELAX_MANIA,
        Gamemode::AUTOPILOT_TAIKO,
        Gamemode::AUTOPILOT_CATCH,
        Gamemode::AUTOPILOT_MANIA
      }
      Gamemode.values.reject { |gm| exc.includes?(gm) }
    end
  end

  def as_vn : UInt8
    self.value % 4
  end

  def to_s : String
    MODE_STR_LIST[self.value]
  end
end
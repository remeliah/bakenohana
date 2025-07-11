@[Flags]
enum Mods : UInt32
  NOMOD       = 0
  NOFAIL      = 1 << 0
  EASY        = 1 << 1
  TOUCHSCREEN = 1 << 2
  HIDDEN      = 1 << 3
  HARDROCK    = 1 << 4
  SUDDENDEATH = 1 << 5
  DOUBLETIME  = 1 << 6
  RELAX       = 1 << 7
  HALFTIME    = 1 << 8
  NIGHTCORE   = 1 << 9
  FLASHLIGHT  = 1 << 10
  AUTOPLAY    = 1 << 11
  SPUNOUT     = 1 << 12
  AUTOPILOT   = 1 << 13
  PERFECT     = 1 << 14
  KEY4        = 1 << 15
  KEY5        = 1 << 16
  KEY6        = 1 << 17
  KEY7        = 1 << 18
  KEY8        = 1 << 19
  FADEIN      = 1 << 20
  RANDOM      = 1 << 21
  CINEMA      = 1 << 22
  TARGET      = 1 << 23
  KEY9        = 1 << 24
  KEYCOOP     = 1 << 25
  KEY1        = 1 << 26
  KEY3        = 1 << 27
  KEY2        = 1 << 28
  SCOREV2     = 1 << 29
  MIRROR      = 1 << 30

  SPEED_CHANGING         = DOUBLETIME | NIGHTCORE | HALFTIME
  GAME_CHANGING          = RELAX | AUTOPILOT
  UNRANKED               = SCOREV2 | AUTOPLAY | TARGET
end

STR_MODS = {
  NOFAIL      => "NF",
  EASY        => "EZ",
  TOUCHSCREEN => "TD",
  HIDDEN      => "HD",
  HARDROCK    => "HR",
  SUDDENDEATH => "SD",
  DOUBLETIME  => "DT",
  RELAX       => "RX",
  HALFTIME    => "HT",
  NIGHTCORE   => "NC",
  FLASHLIGHT  => "FL",
  AUTOPLAY    => "AU",
  SPUNOUT     => "SO",
  AUTOPILOT   => "AP",
  PERFECT     => "PF",
  FADEIN      => "FI",
  RANDOM      => "RN",
  CINEMA      => "CN",
  TARGET      => "TP",
  SCOREV2     => "V2",
  MIRROR      => "MR",
  KEY1        => "1K",
  KEY2        => "2K",
  KEY3        => "3K",
  KEY4        => "4K",
  KEY5        => "5K",
  KEY6        => "6K",
  KEY7        => "7K",
  KEY8        => "8K",
  KEY9        => "9K",
  KEYCOOP     => "CO"
}

MODS_STR = STR_MODS.invert

def conv_mods(mods : Mods) : String
  return "NM" if mods.value == 0

  o = String.build do |str|
    Mods.each do |mod|
      str << STR_MODS[mod] if mods.includes?(mod) && STR_MODS.has_key?(mod)
    end
  end

  if mods.includes?(NIGHTCORE)
    o = o.gsub("DT", "")
  end

  if mods.includes?(PERFECT)
    o = o.gsub("SD", "")
  end

  o
end

def conv_str(mods : String) : Mods
  return NOMOD if mods.empty? || mods == "NM"

  res = NOMOD

  mods.each_char.each_slice(2) do |p|
    if mod = MODS_STR[p.join.upcase]?
      res |= mod
    end
  end

  res
end

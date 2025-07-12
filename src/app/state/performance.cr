require "file_utils"
require "../consts/mods"
require "../consts/mode"

# https://github.com/remeliah/rosu-ffi/
@[Link(ldflags: "#{__DIR__}/../lib/native/librosu_ffi.so")]
lib LibOsuPerformance
  @[Packed]
  struct OptionU32
    t : UInt32
    is_some : UInt8
  end

  struct CalculatePerformanceResult
    pp : Float64
    stars : Float64
  end

  fun calculate_score_bytes(
    beatmap_bytes : UInt8*,
    len : UInt32,
    mode : UInt32,
    mods : UInt32,
    max_combo : UInt32,
    accuracy : Float64,
    miss_count : UInt32,
    passed_objects : OptionU32,
    lazer : UInt8
  ) : CalculatePerformanceResult
end

class OsuPerformanceCalculator
  struct PerformanceResult
    getter pp : Float64
    getter stars : Float64

    def initialize(@pp : Float64, @stars : Float64)
    end

    def to_s(io) : String
      io << "pp: #{@pp.round(2)}, stars: #{@stars.round(2)}"
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "pp", @pp
        json.field "stars", @stars
      end
    end
  end

  def self.calculate_score(
    beatmap_bytes : Bytes,
    mode : Gamemode = Gamemode::VN_OSU,
    mods : Mods = Mods::NOMOD,
    max_combo : UInt32 = 0_u32,
    accuracy : Float64 = 100.0,
    miss_count : UInt32 = 0_u32
  ) : PerformanceResult
    raise "empty beatmap data" if beatmap_bytes.empty?
    raise "accuracy must be between 0 and 100" unless (0.0..100.0).includes?(accuracy)

    begin
      result = LibOsuPerformance.calculate_score_bytes(
        beatmap_bytes.to_unsafe,
        beatmap_bytes.size.to_u32,
        mode.value.to_u32,
        mods,
        max_combo,
        accuracy,
        miss_count,
        passed_objects = OptionU32.new(0_u32, 0_u8), # not used
        0_u8                                         # not used
      )

      PerformanceResult.new(result.pp, result.stars)
    rescue ex
      raise "failed to calculate performance: #{ex.message}"
    end
  end
end
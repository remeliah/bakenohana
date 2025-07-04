class BanchoPacket
  getter id : UInt16
  getter body : Bytes

  def initialize(@id : UInt16, @body : Bytes, @handler : Proc(Player, Bytes, Nil))
  end

  def handle(player : Player)
    @handler.call(player, @body)
  end
end

class BanchoPacketReader
  include Enumerable(BanchoPacket)

  @data : Bytes
  @pos : Int32 = 0
  @packet_map : Hash(UInt16, Proc(Player, Bytes, Nil))
  @curr_len : Int32 = 0

  def initialize(@data : Bytes, @packet_map : Hash(UInt16, Proc(Player, Bytes, Nil)))
  end

  def each
    while @pos + 7 <= @data.size
      # packet_id (2 bytes) + pad (1 byte) + length (4 bytes)
      id = read_u16_direct
      skip_bytes(1)

      @curr_len = read_u32_direct.to_i

      break if @pos + @curr_len > @data.size

      if handler = @packet_map[id]?
        body = read_bytes(@curr_len)
        yield BanchoPacket.new(id, body, handler)
      else

        skip_bytes(@curr_len)
      end
    end
  end

  def read_bytes(n : Int32) : Bytes
    raise IndexError.new("not enough data") if @pos + n > @data.size
    buf = @data[@pos, n]
    @pos += n
    buf
  end

  def skip_bytes(n : Int32)
    raise IndexError.new("not enough data") if @pos + n > @data.size
    @pos += n
  end

  private def read_u16_direct : UInt16
    raise IndexError.new("not enough data") if @pos + 2 > @data.size
    val = @data[@pos].to_u16 | (@data[@pos + 1].to_u16 << 8)
    @pos += 2
    val
  end

  private def read_u32_direct : UInt32
    raise IndexError.new("not enough data") if @pos + 4 > @data.size
    val = @data[@pos].to_u32 | 
          (@data[@pos + 1].to_u32 << 8) |
          (@data[@pos + 2].to_u32 << 16) |
          (@data[@pos + 3].to_u32 << 24)
    @pos += 4
    val
  end

  def read_i8 : Int8
    raise IndexError.new("not enough data") if @pos + 1 > @data.size
    val = @data[@pos]
    @pos += 1
    val > 127 ? (val - 256).to_i8 : val.to_i8
  end

  def read_u8 : UInt8
    raise IndexError.new("not enough data") if @pos + 1 > @data.size
    val = @data[@pos]
    @pos += 1
    val
  end

  def read_i16 : Int16
    raise IndexError.new("not enough data") if @pos + 2 > @data.size
    val = @data[@pos].to_i16 | (@data[@pos + 1].to_i16 << 8)
    @pos += 2

    val > 32767 ? (val - 65536).to_i16 : val
  end

  def read_u16 : UInt16
    raise IndexError.new("not enough data") if @pos + 2 > @data.size
    val = @data[@pos].to_u16 | (@data[@pos + 1].to_u16 << 8)
    @pos += 2
    val
  end

  def read_i32 : Int32
    raise IndexError.new("not enough data") if @pos + 4 > @data.size
    val = @data[@pos].to_i32 | 
          (@data[@pos + 1].to_i32 << 8) |
          (@data[@pos + 2].to_i32 << 16) |
          (@data[@pos + 3].to_i32 << 24)
    @pos += 4
    val
  end

  def read_u32 : UInt32
    raise IndexError.new("not enough data") if @pos + 4 > @data.size
    val = @data[@pos].to_u32 | 
          (@data[@pos + 1].to_u32 << 8) |
          (@data[@pos + 2].to_u32 << 16) |
          (@data[@pos + 3].to_u32 << 24)
    @pos += 4
    val
  end

  def read_i64 : Int64
    raise IndexError.new("not enough data") if @pos + 8 > @data.size
    val = @data[@pos].to_i64 | 
          (@data[@pos + 1].to_i64 << 8) |
          (@data[@pos + 2].to_i64 << 16) |
          (@data[@pos + 3].to_i64 << 24) |
          (@data[@pos + 4].to_i64 << 32) |
          (@data[@pos + 5].to_i64 << 40) |
          (@data[@pos + 6].to_i64 << 48) |
          (@data[@pos + 7].to_i64 << 56)
    @pos += 8
    val
  end

  def read_u64 : UInt64
    raise IndexError.new("not enough data") if @pos + 8 > @data.size
    val = @data[@pos].to_u64 | 
          (@data[@pos + 1].to_u64 << 8) |
          (@data[@pos + 2].to_u64 << 16) |
          (@data[@pos + 3].to_u64 << 24) |
          (@data[@pos + 4].to_u64 << 32) |
          (@data[@pos + 5].to_u64 << 40) |
          (@data[@pos + 6].to_u64 << 48) |
          (@data[@pos + 7].to_u64 << 56)
    @pos += 8
    val
  end

  def read_f32 : Float32
    raise IndexError.new("not enough data") if @pos + 4 > @data.size

    val = IO::Memory.new(@data[@pos, 4]).read_bytes(Float32, IO::ByteFormat::LittleEndian)
    @pos += 4
    val
  end

  def read_f64 : Float64
    raise IndexError.new("not enough data") if @pos + 8 > @data.size

    val = IO::Memory.new(@data[@pos, 8]).read_bytes(Float64, IO::ByteFormat::LittleEndian)
    @pos += 8
    val
  end

  def read_i32_list_i16l : Array(Int32)
    len = read_u16.to_i
    arr = Array(Int32).new(len)
    len.times { arr << read_i32 }
    arr
  end

  def read_i32_list_i32l : Array(Int32)
    len = read_u32.to_i
    arr = Array(Int32).new(len)
    len.times { arr << read_i32 }
    arr
  end

  def read_string : String
    exists = read_u8 == 0x0B
    return "" unless exists

    len = 0
    shift = 0

    loop do
      byte = read_u8
      len |= (byte & 0x7F) << shift
      break unless (byte & 0x80) != 0
      shift += 7
    end

    str_bytes = read_bytes(len)
    String.new(str_bytes)
  end

  def read_raw : Bytes
    read_bytes(@curr_len)
  end

  def reset
    @pos = 0
    @curr_len = 0
  end

  def position
    @pos
  end

  def has_more?
    @pos < @data.size
  end
end
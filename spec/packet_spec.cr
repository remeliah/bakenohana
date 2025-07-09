require "spec"
require "../src/app/packets/packets"

alias OsuType = Packets::OsuType
alias ServerPacket = Packets::ServerPacket

describe Packets do
  it "writes I8" do
    value = -5_i8
    bytes = Packets.write(ServerPacket::USER_ID, {value, OsuType::I8})
    bytes[-1].should eq value.unsafe_as(UInt8)
  end

  it "writes U8" do
    value = 250_u8
    bytes = Packets.write(ServerPacket::PONG, {value, OsuType::U8})
    bytes[-1].should eq value
  end

  it "writes I16" do
    value = -1234_i16
    bytes = Packets.write(ServerPacket::USER_STATS, {value, OsuType::I16})
    expected = IO::Memory.new.tap(&.write_bytes(value, IO::ByteFormat::LittleEndian)).to_slice
    bytes[-2..].should eq expected
  end

  it "writes U16" do
    value = 65500_u16
    bytes = Packets.write(ServerPacket::USER_PRESENCE, {value, OsuType::U16})
    expected = IO::Memory.new.tap(&.write_bytes(value, IO::ByteFormat::LittleEndian)).to_slice
    bytes[-2..].should eq expected
  end

  it "writes I32" do
    value = -123456_i32
    bytes = Packets.write(ServerPacket::USER_LOGOUT, {value, OsuType::I32})
    expected = IO::Memory.new.tap(&.write_bytes(value, IO::ByteFormat::LittleEndian)).to_slice
    bytes[-4..].should eq expected
  end

  it "writes U32" do
    value = 123456_u32
    bytes = Packets.write(ServerPacket::NOTIFICATION, {value, OsuType::U32})
    expected = IO::Memory.new.tap(&.write_bytes(value, IO::ByteFormat::LittleEndian)).to_slice
    bytes[-4..].should eq expected
  end

  it "writes I64" do
    value = -123456789_i64
    bytes = Packets.write(ServerPacket::PRIVILEGES, {value, OsuType::I64})
    expected = IO::Memory.new.tap(&.write_bytes(value, IO::ByteFormat::LittleEndian)).to_slice
    bytes[-8..].should eq expected
  end

  it "writes U64" do
    value = 123456789_u64
    bytes = Packets.write(ServerPacket::FRIENDS_LIST, {value, OsuType::U64})
    expected = IO::Memory.new.tap(&.write_bytes(value, IO::ByteFormat::LittleEndian)).to_slice
    bytes[-8..].should eq expected
  end

  it "writes F32" do
    value = 3.14_f32
    bytes = Packets.write(ServerPacket::RESTART, {value, OsuType::F32})
    expected = IO::Memory.new.tap(&.write_bytes(value, IO::ByteFormat::LittleEndian)).to_slice
    bytes[-4..].should eq expected
  end

  it "writes F64" do
    value = 3.1415926535_f64
    bytes = Packets.write(ServerPacket::ACCOUNT_RESTRICTED, {value, OsuType::F64})
    expected = IO::Memory.new.tap(&.write_bytes(value, IO::ByteFormat::LittleEndian)).to_slice
    bytes[-8..].should eq expected
  end

  it "writes String" do
    str = "osu!"
    bytes = Packets.write(ServerPacket::PROTOCOL_VERSION, {str, OsuType::String})

    expected = IO::Memory.new
    expected.write_byte 0x00
    expected.write_byte 0x0b
    expected.write_byte str.bytesize.to_u8
    expected.write str.to_slice

    bytes[6..].should eq expected.to_slice
  end

  it "writes I32List" do
    list = [1, 2, 3]
    bytes = Packets.write(ServerPacket::CHANNEL_INFO_END, {list, OsuType::I32List})

    expected = IO::Memory.new
    expected.write_byte 0x00
    expected.write_bytes list.size.to_u16, IO::ByteFormat::LittleEndian
    list.each { |i| expected.write_bytes i, IO::ByteFormat::LittleEndian }

    bytes[6..].should eq expected.to_slice
  end

  it "writes Raw bytes" do
    raw = Bytes[0xDE, 0xAD, 0xBE, 0xEF]
    bytes = Packets.write(ServerPacket::USER_ID, {raw, OsuType::Raw})
    bytes[-4..].should eq raw
  end

  it "writes Message tuple" do
    msg = {"sender", "target", "content", 123}
    bytes = Packets.write(ServerPacket::SEND_MESSAGE, {msg, OsuType::Message})

    expected = IO::Memory.new
    expected.write_byte 0x00
    {"sender", "target", "content"}.each do |s|
      expected.write_byte 0x0b
      expected.write_byte s.bytesize.to_u8
      expected.write s.to_slice
    end
    expected.write_bytes 123_i32, IO::ByteFormat::LittleEndian

    bytes[6..].should eq expected.to_slice
  end

  # methods

  it "writes spectator_cant_spectate" do
    bytes = Packets.spectator_cant_spectate(0)

    expected = IO::Memory.new

    expected.write_byte 0x16
    expected.write_byte 0x00
    expected.write_byte 0x00

    expected.write_bytes 4_u32, IO::ByteFormat::LittleEndian

    expected.write_bytes 0_i32, IO::ByteFormat::LittleEndian

    bytes.should eq expected.to_slice
  end

  it "writes channel_kick" do
    bytes = Packets.channel_kick("#spectator")

    expected = IO::Memory.new
    expected.write_byte 0x00
    expected.write_byte 0x0b
    expected.write_byte "#spectator".bytesize.to_u8
    expected.write "#spectator".to_slice

    bytes[6..].should eq expected.to_slice
  end
end
require "../objects/player"
require "./packets"

require "../models/message"
require "../models/channel"

enum ClientPackets : UInt16 # TODO: add more
  ACTION = 0
  SEND_PUBLIC_MESSAGE = 1
  LOGOUT = 2
  PONG = 4
  START_SPECTATING = 16
  STOP_SPECTATING = 17
  SPECTATE_FRAMES = 18
  ERROR_REPORT = 20
  CANT_SPECTATE = 21
  SEND_PRIVATE_MESSAGE = 25
  CHANNEL_JOIN = 63
  FRIEND_ADD = 73
  FRIEND_REMOVE = 74
  USER_STATS = 85
  USER_PRESENCE_REQUEST = 97
  USER_PRESENCE_REQUEST_ALL = 98
end

abstract class BasePacket
  def initialize(@reader : BanchoPacketReader)
  end

  abstract def handle(p : Player)
end

# https://github.com/osuAkatsuki/bancho.py/blob/74290910d3ce6e0284453ad9f913ede6a8555fa2/app/packets.py#L303
alias PacketMap = Hash(UInt16, BasePacket.class)

macro register(packet_id, packet_class) # TODO: handle for restricted?
  PACKET_MAP[{{packet_id}}.to_u16] = {{packet_class}}
end

PACKET_MAP = PacketMap.new

class BanchoPacketReader
  include Iterator(BasePacket)

  @body_view : Bytes
  @packet_map : PacketMap
  @current_len : Int32 = 0

  def initialize(body_view : Bytes, @packet_map : PacketMap)
    @body_view = body_view
  end

  def next
    while @body_view.size >= 7
      p_type, p_len = read_header
      
      if packet_class = @packet_map[p_type]?
        @current_len = p_len
        return packet_class.new(self)
      else
        # bye
        if p_len != 0 && p_len <= @body_view.size
          @body_view = @body_view[p_len..]
        else
          break
        end
      end
    end
    stop
  end

  private def read_header : {UInt16, Int32}
    raise IndexError.new("not enough data for header") if @body_view.size < 7

    packet_id = @body_view[0].to_u16 | (@body_view[1].to_u16 << 8)

    packet_len = @body_view[3].to_u32 | 
                (@body_view[4].to_u32 << 8) |
                (@body_view[5].to_u32 << 16) |
                (@body_view[6].to_u32 << 24)

    @body_view = @body_view[7..]
    {packet_id, packet_len.to_i}
  end

  def read_raw : Bytes
    raise IndexError.new("not enough data") if @current_len > @body_view.size
    val = @body_view[0, @current_len]
    @body_view = @body_view[@current_len..]
    val
  end

  def read_i8 : Int8
    raise IndexError.new("not enough data") if @body_view.size < 1
    val = @body_view[0]
    @body_view = @body_view[1..]
    val > 127 ? (val - 256).to_i8 : val.to_i8
  end

  def read_u8 : UInt8
    raise IndexError.new("not enough data") if @body_view.size < 1
    val = @body_view[0]
    @body_view = @body_view[1..]
    val
  end

  def read_i16 : Int16
    raise IndexError.new("not enough data") if @body_view.size < 2
    val = @body_view[0].to_i16 | (@body_view[1].to_i16 << 8)
    @body_view = @body_view[2..]
    val > 32767 ? (val - 65536).to_i16 : val
  end

  def read_u16 : UInt16
    raise IndexError.new("not enough data") if @body_view.size < 2
    val = @body_view[0].to_u16 | (@body_view[1].to_u16 << 8)
    @body_view = @body_view[2..]
    val
  end

  def read_i32 : Int32
    raise IndexError.new("not enough data") if @body_view.size < 4
    val = @body_view[0].to_i32 | 
          (@body_view[1].to_i32 << 8) |
          (@body_view[2].to_i32 << 16) |
          (@body_view[3].to_i32 << 24)
    @body_view = @body_view[4..]
    val
  end

  def read_u32 : UInt32
    raise IndexError.new("not enough data") if @body_view.size < 4
    val = @body_view[0].to_u32 | 
          (@body_view[1].to_u32 << 8) |
          (@body_view[2].to_u32 << 16) |
          (@body_view[3].to_u32 << 24)
    @body_view = @body_view[4..]
    val
  end

  def read_i64 : Int64
    raise IndexError.new("not enough data") if @body_view.size < 8
    val = @body_view[0].to_i64 | 
          (@body_view[1].to_i64 << 8) |
          (@body_view[2].to_i64 << 16) |
          (@body_view[3].to_i64 << 24) |
          (@body_view[4].to_i64 << 32) |
          (@body_view[5].to_i64 << 40) |
          (@body_view[6].to_i64 << 48) |
          (@body_view[7].to_i64 << 56)
    @body_view = @body_view[8..]
    val
  end

  def read_u64 : UInt64
    raise IndexError.new("not enough data") if @body_view.size < 8
    val = @body_view[0].to_u64 | 
          (@body_view[1].to_u64 << 8) |
          (@body_view[2].to_u64 << 16) |
          (@body_view[3].to_u64 << 24) |
          (@body_view[4].to_u64 << 32) |
          (@body_view[5].to_u64 << 40) |
          (@body_view[6].to_u64 << 48) |
          (@body_view[7].to_u64 << 56)
    @body_view = @body_view[8..]
    val
  end

  def read_f32 : Float32
    raise IndexError.new("not enough data") if @body_view.size < 4
    val = IO::Memory.new(@body_view[0, 4]).read_bytes(Float32, IO::ByteFormat::LittleEndian)
    @body_view = @body_view[4..]
    val
  end

  def read_f64 : Float64
    raise IndexError.new("not enough data") if @body_view.size < 8
    val = IO::Memory.new(@body_view[0, 8]).read_bytes(Float64, IO::ByteFormat::LittleEndian)
    @body_view = @body_view[8..]
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

    str_bytes = @body_view[0, len]
    @body_view = @body_view[len..]
    String.new(str_bytes)
  end

  # TODO: handle osu's

  def read_message : Message
    Message.new(
      read_string(), # sender
      read_string(), # text
      read_string(), # recipient
      read_i32()     # sender_id
    )
  end

  def read_channel : Chan
    Chan.new(
      read_string(), # name
      read_string(), # topic
      read_i32()     # players
    )
  end
end

# reader packet handler 

class PongPacket < BasePacket
  def handle(p : Player)
    # nah
  end
end

class UserStatsRequestPacket < BasePacket
  getter user_ids : Array(Int32)

  def initialize(reader : BanchoPacketReader)
    super(reader)
    @user_ids = reader.read_i32_list_i16l
  end

  def handle(p : Player)
    unrestricted_ids = PlayerSession.unrestricted.map(&.id).to_set
    is_online = ->(id : Int32) { unrestricted_ids.includes?(id) && id != p.id }

    @user_ids.select(&is_online).each do |online_id|
      target = PlayerSession.get(id: online_id)
      next unless target

      if target == PlayerSession.bot
        packet = Packets.bot_stats(target)
      else
        packet = Packets.user_stats(target)
      end

      p.enqueue(packet)
    end
  end
end

class LogoutPacket < BasePacket
  def handle(p : Player)
    if Time.utc.to_unix - p.login_time.to_unix < 1
      return
    end

    p.logout
  end
end

#class ReceiveUpdatesPacket < BasePacket
#  def handle(p : Player)
#    if Time.utc.to_unix_f - p.login_time.to_unix_f < 1.0
#      return
#    end
#
#    p.enqueue(Packets.logout(p.id))
#  end
#end

class UserPresenceRequestPacket < BasePacket
  getter user_ids : Array(Int32)

  def initialize(reader : BanchoPacketReader)
    super(reader)
    @user_ids = reader.read_i32_list_i16l
  end

  def handle(p : Player)
    @user_ids.each do |id|
      target = PlayerSession.get(id: id)
      next unless target

      if target == PlayerSession.bot
        packet = Packets.user_presence(target)
      else
        packet = Packets.user_presence(target)
      end

      p.enqueue(packet)
    end
  end
end

class SendMessagePublicPacket < BasePacket
  getter msg : Message

  def initialize(reader : BanchoPacketReader)
    super(reader)
    @msg = reader.read_message
  end

  def handle(p : Player)
    msg_text = @msg.text.strip
    return if msg_text.empty?

    recipient = @msg.recipient

    if recipient == "#spectator"
      spectated_id = p.spectating.try(&.id) || p.id
      recp = "#spec_#{spectated_id}"
      t_chan = ChannelSession[recp]

      unless t_chan
        rlog "#{p.username} wrote to non-existent spectate channel?", Ansi::LYELLOW
        return
      end
    else
      t_chan = ChannelSession[recipient]

      unless t_chan
        rlog "#{p.username} wrote to non-existent #{recipient}.", Ansi::LYELLOW
        return
      end
    end

    unless t_chan.can_write?(p.priv)
      rlog "#{p.username} wrote to #{recipient} with insufficient privileges.", Ansi::LYELLOW
      return
    end

    if msg_text.size > 2000
      msg_text = "#{msg_text[0, 2000]}... (truncated)"
      p.enqueue(Packets.notification(
        "Your message was truncated\n(exceeded 2000 characters)."
      ))
    end

    t_chan.send_msg(msg_text, sender: p)
  end
end

class SendMessagePrivatePacket < BasePacket
  getter msg : Message

  def initialize(reader : BanchoPacketReader)
    super(reader)
    @msg = reader.read_message
  end

  def handle(p : Player)
    msg_text = @msg.text.strip
    return if msg_text.empty?

    recipient = @msg.recipient

    t_name = PlayerSession.get(username: recipient)

    unless t_name
      rlog "#{p.username} wrote to non-existent #{recipient}.", Ansi::LYELLOW
      return
    end

    if msg_text.size > 2000
      msg_text = "#{msg_text[0, 2000]}... (truncated)"
      p.enqueue(Packets.notification(
        "Your message was truncated\n(exceeded 2000 characters)."
      ))
    end

    t_name.send_msg(msg_text, sender: p)
  end
end

class JoinChannelPacket < BasePacket
  getter name : String

  def initialize(reader : BanchoPacketReader)
    super(reader)
    @name = reader.read_string
  end

  def handle(p : Player)
    if ["#highlight", "#userlog"].includes?(name)
      return
    end

    channel = ChannelSession[name]
    if channel.nil? || !p.join_channel(channel)
      rlog "#{p.username} failed to join #{name}.", Ansi::LYELLOW
      return
    end
  end
end

class RemoveFriendPacket < BasePacket
  getter id : Int32

  def initialize(reader : BanchoPacketReader)
    super(reader)
    @id = reader.read_i32
  end

  def handle(p : Player)
    target = PlayerSession.get(id: id)

    unless target
      rlog "#{p.username} tries to remove offline player: (#{id})", Ansi::LYELLOW
      return
    end

    p.remove_friend(target)
  end
end

class AddFriendPacket < BasePacket
  getter id : Int32

  def initialize(reader : BanchoPacketReader)
    super(reader)
    @id = reader.read_i32
  end

  def handle(p : Player)
    target = PlayerSession.get(id: id)

    unless target # should i check for adding themself? rofl
      rlog "#{p.username} tries to add offline player: (#{id})", Ansi::LYELLOW
      return
    end

    p.add_friend(target)
  end
end

class StartSpectatingPacket < BasePacket
  getter id : Int32

  def initialize(reader : BanchoPacketReader)
    super(reader)
    @id = reader.read_i32
  end

  def handle(p : Player) : Nil
    target = PlayerSession.get(id: id)
    unless target
      rlog "#{p.username} tried to spectate non-existent id #{id}", Ansi::LYELLOW
      return
    end

    if host = p.spectating
      if host == target
        target.enqueue(Packets.spectator_joined(p.id))
        f_joined = Packets.f_spectator_joined(p.id)

        target.spectators.each do |spec|
          next if spec == p
          spec.enqueue(f_joined)
        end

        return
      end

      host.remove_spectator(p)
    end

    target.add_spectator(p)
  end
end

class StopSpectatingPacket < BasePacket
  def handle(p : Player)
    p.spectating.try &.remove_spectator(p)
  end
end

class SpectateFramesPacket < BasePacket
  @frames : Bytes

  def initialize(reader : BanchoPacketReader)
    super(reader)
    @frames = reader.read_raw
  end

  def handle(p : Player) : Nil 
    # NOTE: this might be really slow, i might wanna optimize this a little bit
    frames_packet = Packets.spectator_frames(@frames)

    p.spectators.each do |spec|
      spec.enqueue(frames_packet)
    end
  end
end

class CantSpectatePacket < BasePacket
  def handle(p : Player) : Nil
    host = p.spectating
    unless host
      rlog "#{p.username} sent can't spectate while not spectating?", Ansi::LRED
      return
    end

    data = Packets.spectator_cant_spectate(p.id)
    host.enqueue(data)

    host.spectators.each do |t|
      t.enqueue(data)
    end
  end
end

class ChangeActionPacket < BasePacket
  getter action : UInt8
  getter info_text : String
  getter map_md5 : String
  getter mods : UInt32
  getter mode : UInt8
  getter map_id : Int32

  def initialize(reader : BanchoPacketReader)
    super(reader)
  
    @action = reader.read_u8()
    @info_text = reader.read_string()
    @map_md5 = reader.read_string()

    @mods = reader.read_u32()
    @mode = reader.read_u8()

    @map_id = reader.read_i32()
  end

  def handle(p : Player) : Nil
    p.status.action = @action
    p.status.info_text = @info_text
    p.status.map_md5 = @map_md5
    p.status.mods = Mods.new(@mods)
    p.status.mode = @mode
    p.status.map_id = @map_id

    unless p.restricted
      p.enqueue(Packets.user_stats(p))
    end
  end
end

# register them client packets

register(ClientPackets::LOGOUT, LogoutPacket)
register(ClientPackets::PONG, PongPacket)

register(ClientPackets::USER_STATS, UserStatsRequestPacket)
register(ClientPackets::USER_PRESENCE_REQUEST, UserPresenceRequestPacket)
register(ClientPackets::ACTION, ChangeActionPacket)

register(ClientPackets::CHANNEL_JOIN, JoinChannelPacket)
register(ClientPackets::SEND_PUBLIC_MESSAGE, SendMessagePublicPacket)
register(ClientPackets::SEND_PRIVATE_MESSAGE, SendMessagePrivatePacket)

register(ClientPackets::FRIEND_ADD, AddFriendPacket)
register(ClientPackets::FRIEND_REMOVE, RemoveFriendPacket)

register(ClientPackets::START_SPECTATING, StartSpectatingPacket)
register(ClientPackets::STOP_SPECTATING, StopSpectatingPacket)
register(ClientPackets::SPECTATE_FRAMES, SpectateFramesPacket)
register(ClientPackets::CANT_SPECTATE, CantSpectatePacket)
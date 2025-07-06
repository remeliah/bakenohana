require "./stats"
require "./status"
require "../consts/priv"

class Player
  getter token : String
  getter username : String
  getter ip : String
  getter login_time : Time

  property id : Int32
  property restricted = false
  property last_recv_time : Time = Time.utc

  property stats : PlayerStats = PlayerStats.new
  property status : PlayerStatus = PlayerStatus.new

  property priv : Privileges

  @queue = IO::Memory.new

  def initialize(
    @username : String, 
    @token : String,
    @ip : String,
    @login_time : Time,
    @priv : Privileges
  )
    @id = 3_i32 # TODO: lol
    @priv = priv
  end

  def enqueue(data : Bytes)
    @queue.write data
  end

  def dequeue : Bytes
    buf = @queue.to_slice
    @queue = IO::Memory.new
    buf
  end

  def client_priv : ClientPrivileges # TODO: cache?
    ret = ClientPrivileges::None
    ret |= ClientPrivileges::PLAYER     if @priv & Privileges::UNRESTRICTED != 0
    ret |= ClientPrivileges::SUPPORTER  if @priv & Privileges::SUPPORTER != 0
    ret |= ClientPrivileges::MODERATOR  if @priv & Privileges::MODERATOR != 0
    ret |= ClientPrivileges::DEVELOPER  if @priv & Privileges::ADMINISTRATOR != 0
    ret |= ClientPrivileges::OWNER      if @priv & Privileges::DEVELOPER != 0
    ret
  end

  def restricted : Bool
    !@priv.includes?(Privileges::UNRESTRICTED)
  end
end
require "./stats"
require "./status"
require "../consts/priv"

class Player
  getter token : String
  getter username : String
  getter ip : String
  getter login_time : Time
  getter id : Int32
  
  @last_recv_time : Time = Time.utc
  @last_recv_mut = Mutex.new

  property stats : PlayerStats = PlayerStats.new
  property status : PlayerStatus = PlayerStatus.new

  property priv : Privileges

  @friends = Set(Int32).new
  @friends_mut = Mutex.new

  @queue = IO::Memory.new
  @queue_mut = Mutex.new

  def initialize(
    @id : Int32,
    @username : String, 
    @token : String,
    @ip : String,
    @login_time : Time,
    @priv : Privileges
  )
    @priv = priv
  end

  def enqueue(data : Bytes)
    @queue_mut.synchronize do
      @queue.write data
    end
  end

  def dequeue : Bytes
    @queue_mut.synchronize do
      buf = @queue.to_slice
      @queue = IO::Memory.new
      buf
    end
  end

  def last_recv_time
    @last_recv_mut.synchronize { @last_recv_time }
  end

  def last_recv_time=(time : Time)
    @last_recv_mut.synchronize { @last_recv_time = time }
  end

  def friends : Set(Int32)
    @friends_mut.synchronize { @friends.dup }
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

  def add_friend(user_id : Int32)
    @friends_mut.synchronize { @friends.add(user_id) }
  end

  def get_relationship : Nil
    # TODO: actually get relationship lul
    add_friend(3)
  end

  def logout
    PlayerSession.remove(@token)

    logout_packet = Packets.logout(@id)
    PlayerSession.each do |other_player, _|
      next if other_player.token == @token
      other_player.enqueue(logout_packet)
    end

    @queue_mut.synchronize do
      @queue = IO::Memory.new
    end
    
    puts "player #{@username} (#{@id}) logged out"
  end
end
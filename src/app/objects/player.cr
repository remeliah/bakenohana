require "./stats"
require "./status"

class Player
  getter token : String
  getter username : String
  getter ip : String

  property id : Int32
  property restricted = false
  property last_recv_time : Time = Time.utc

  property stats : PlayerStats = PlayerStats.new
  property status : PlayerStatus = PlayerStatus.new


  @queue = IO::Memory.new

  def initialize(@username : String, @token : String, @ip : String)
    @id = 3_i32 # TODO: lol
  end

  def enqueue(data : Bytes)
    puts "enqueuing packet of size #{data.size}"
    @queue.write data
  end

  def dequeue : Bytes
    buf = @queue.to_slice
    @queue = IO::Memory.new
    buf
  end
end
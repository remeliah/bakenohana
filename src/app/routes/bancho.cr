require "kemal"
require "../objects/player"
require "../state/sessions"
require "../packets/packets"
require "../packets/reader"
require "../models/login_data"
require "../consts/priv"

def parse_login(body : Bytes) : LoginData
  str = String.new(body)
  lines = str.split('\n', remove_empty: true)

  puts lines

  raise "login: not 3 lines" unless lines.size == 3

  username = lines[0]
  password_md5 = lines[1]
  meta = lines[2].split('|')

  raise "login: meta not 5+" unless meta.size >= 5

  osu_version    = meta[0]
  utc_offset     = meta[1].to_i
  display_city   = meta[2] == "1"
  adapters_str   = meta[3]
  pm_private     = meta[4] == "1"

  hwid_parts = adapters_str.split(':', remove_empty: true) # TODO: dont remove_empty

  raise "login: bad adapters" unless hwid_parts.size >= 4

  LoginData.new(
    username: username,
    password_md5: password_md5,
    osu_version: osu_version,
    utc_offset: utc_offset,
    display_city: display_city,
    adapters_str: adapters_str,
    adapters_md5: hwid_parts[1],
    uninstall_md5: hwid_parts[2],
    disk_signature_md5: hwid_parts[3],
    osu_path_md5: hwid_parts[0],
    pm_private: pm_private
  )
end

post "/" do |env|
  ip = env.request.remote_address.to_s
  token = env.request.headers["osu-token"]?

  if token.nil?
    begin
      body_content = env.request.body
      if body_content.nil?
        raise "empty body"
      end

      body_bytes = body_content.gets_to_end.to_slice
      login_data = parse_login(body_bytes)

      # TODO: proper validation
      if login_data.username.empty? || login_data.password_md5.size != 32
        env.response.headers["cho-token"] = "no"
        res = Packets.notification("invalid login") + Packets.login_reply(-1)
        env.response.content_length = res.bytesize

        env.response.write(res)
        next
      end

      if login_data.username == "loopen"
        env.response.headers["cho-token"] = "no"
        res = Packets.notification("kill yourself") + Packets.login_reply(-1)
        env.response.content_length = res.bytesize

        env.response.write(res)
        next
      end

      osu_token = Random::Secure.hex(16)
      login_time = Time.utc
      
      # TODO: fetch from db
      priv = Privileges::UNRESTRICTED | 
             Privileges::VERIFIED | 
             Privileges::SUPPORTER

      player = Player.new(
        login_data.username, 
        osu_token, 
        ip,
        login_time,
        priv
      )
      PlayerSession.add(osu_token, player)

      io = IO::Memory.new
      io.write Packets.login_reply(player.id)
      io.write Packets.protocol_version(19) # TODO: ?????

      io.write Packets.bancho_privileges(
        (player.client_priv | ClientPrivileges::SUPPORTER).value
      )

      io.write Packets.notification("yo #{player.username}")

      user_data = (
        Packets.user_presence(player) + Packets.user_stats(player)
      )
      io.write user_data

      if !player.restricted # TODO: handle restricted
        PlayerSession.each do |p|
          # enqueue us to them
          p.enqueue(user_data)

          # enqueue them to us
          unless p.restricted
            io.write Packets.user_presence(p)
            io.write Packets.user_stats(p)
          end
        end
      end

      io.write Packets.channel_info_end()
      
      packets = io.to_slice

      puts "sending login packets (#{packets.size} bytes)"
      puts "response hex: #{packets.hexstring}"

      env.response.headers["cho-token"] = osu_token
      env.response.content_length = packets.bytesize
      env.response.status_code = 200

      puts env.response.headers

      env.response.write(packets)
      next

    rescue ex 
      puts "[login err] #{ex.message}"
      puts ex.backtrace.join("\n")
      
      error_response = Packets.notification("bad login packet") + Packets.restart_server(0)
      
      env.response.headers["cho-token"] = "invalid"
      env.response.content_length = error_response.bytesize
      env.response.status_code = 500

      env.response.write(error_response)
      next
    end
  end

  player = PlayerSession.get(token)
  if player.nil?
    env.response.write(
      Packets.notification("server restart") + Packets.restart_server(0)
    )
    next
  end

  body_content = env.request.body
  if body_content.nil?
    next
  end
  
  body = body_content.gets_to_end.to_slice

  BanchoPacketReader.new(body, PACKET_MAP).each do |packet|
    packet.handle(player)
  end

  player.last_recv_time = Time.utc

  env.response.write(player.dequeue)
end

get "/" do |env|
  "ayoooo susss"
end
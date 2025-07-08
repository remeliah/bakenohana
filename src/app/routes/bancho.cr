require "kemal"

require "../objects/player"

require "../state/sessions"
require "../state/auth"

require "../packets/packets"
require "../packets/reader"

require "../models/login_data"

require "../consts/priv"
require "../consts/login_response"

require "../repo/player"

def parse_login(body : Bytes) : LoginData
  str = String.new(body)
  lines = str.split('\n', remove_empty: true)

  rlog lines

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

# c.ppy.sh

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
        env.response.write(
          Packets.notification("invalid login") + 
          Packets.login_reply(LoginResponse::AUTH_FAILED)
        )
        next
      end

      if login_data.username == "loopen"
        env.response.headers["cho-token"] = "no"
        env.response.write(
          Packets.notification("kill yourself") + 
          Packets.login_reply(LoginResponse::BANNED)
        )
        next
      end

      login_time = Time.utc

      if player = PlayerSession.get(username: login_data.username)
        if (login_time.to_unix - player.last_recv_time.to_unix) < 10
          env.response.headers["cho-token"] = "no"
          env.response.write(
            Packets.notification("user already logged in!") +
            Packets.login_reply(LoginResponse::AUTH_FAILED)
          )
          next
        else
          player.logout
        end
      end

      user_info = Auth.authenticate(
        login_data.username,
        login_data.password_md5
      )

      unless user_info
        env.response.headers["cho-token"] = "no"
        env.response.write(
          Packets.login_reply(LoginResponse::AUTH_FAILED)
        )
        next
      end

      osu_token = Random::Secure.hex(16)
      player = Player.new( # TODO: add more 
        user_info.id,
        user_info.name,
        osu_token, 
        ip,
        login_time,
        Privileges.new(user_info.priv)
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
            if p == PlayerSession.bot
              io.write Packets.bot_presence(p)
              io.write Packets.bot_stats(p)
            else
              io.write Packets.user_presence(p)
              io.write Packets.user_stats(p)
            end
          end
        end
      end

      ChannelSession.each do |c|
        next if !c.auto_join || 
                !c.can_read?(player.priv) || 
                c.r_name == "#lobby"

        chan_info_packet = Packets.channel_info(c.name, c.topic, c.player_count)

        io.write chan_info_packet

        PlayerSession.each do |o, _|
          if c.can_read?(o.priv)
            o.enqueue(chan_info_packet)
          end
        end
      end

      io.write Packets.channel_info_end()
  
      player.get_relationship
      io.write Packets.friends_list(player.friends)

      packets = io.to_slice

      #puts "sending login packets (#{packets.size} bytes)"
      #puts "response hex: #{packets.hexstring}"

      env.response.headers["cho-token"] = osu_token
      env.response.status_code = 200

      #puts env.response.headers

      env.response.write(packets)
      next

    rescue ex 
      rlog "[login err] #{ex.message}", Ansi::LRED
      rlog ex.backtrace.join("\n"), Ansi::LRED
      
      env.response.headers["cho-token"] = "invalid"
      env.response.status_code = 500

      env.response.write(
        Packets.notification("bad login packet") + 
        Packets.login_reply(LoginResponse::ERROR_OCCUR)
      )
      next
    end
  end

  player = PlayerSession.get(token)
  if player.nil?
    env.response.write(
      Packets.notification("server restarted") + Packets.restart_server(0)
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
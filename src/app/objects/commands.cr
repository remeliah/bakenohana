macro arg(name, type, required = true, default = nil)
end

macro command(name, description, *args, &block)
  arg_names = [] of String
  arg_types = [] of String
  arg_required = [] of Bool
  arg_defaults = [] of String

  # NOTE: kinda cursed lelw
  # https://crystal-lang.org/reference/1.16/syntax_and_semantics/macros/index.html
  {% for arg in args %}
    {% if arg.is_a?(Call) && arg.name == "arg" %}
      arg_names << {{arg.args[0]}}
      arg_types << {{arg.args[1].stringify}}
      arg_required << {{arg.args[2] || true}}
      arg_defaults << {{arg.args[3] ? arg.args[3].stringify : "nil"}}
    {% end %}
  {% end %}

  # TODO: check for priv
  @@commands[{{name}}] = {
    {{description}},
    arg_names,
    ->(player : Player, parsed_args : Hash(String, String)) { {{block.body}} }
  }
end

macro register_commands
  command "help", "show available commands" do
    help_text = ["available bot commands:"]
    @@commands.each do |cmd, (desc, args, _)|
      usage = args.empty? ? cmd : "#{cmd} #{args.map { |a| "<#{a}>" }.join(" ")}"
      help_text << "#{Config.boat_prefix}#{usage} - #{desc}"
    end
    player.send_msg(help_text.join('\n'), PlayerSession.bot)
  end

  command "ping", "pong" do
    player.send_msg("pong!", PlayerSession.bot)
  end

  command "time", "show current server time" do
    current_time = Time.local.to_s("%Y-%m-%d %H:%M:%S")
    player.send_msg("current server time: #{current_time}", PlayerSession.bot)
  end

  command "roll", "roll a dice",
    arg("min", "int", false, "0"),
    arg("max", "int", false, "100") do

    # this is why i hate arg parsing
    # TODO: make a method that handles these cases
    if parsed_args.size == 1 && parsed_args["min"]? && !parsed_args["max"]?
      max = parsed_args["min"]?.try(&.to_i) || 100
      min = 0
    else
      min = parsed_args["min"]?.try(&.to_i) || 0
      max = parsed_args["max"]?.try(&.to_i) || 100
    end
    
    if min >= max
      return player.send_msg("min must be less than max!", PlayerSession.bot)
    end
    
    num = Random.rand(min..max)
    range_text = (min == 0 && max == 100) ? "" : " (#{min}-#{max})"
    player.send_msg("#{player.username} rolled #{num}!#{range_text}", PlayerSession.bot)
  end

  command "sex", "sex." do
    player.send_msg(
      "When bro starts whining and begging me to go faster " \
      "so I have to slowly grind against his special spot with " \
      "my tip and that causes bro " \
      "to start sniffing with pleading tears in his pretty eyes, " \
      "I wrap my arms around bro’s waist and hush him softly as I whisper in his ear, " \
      "“shh.. it’s okay, bro…” To make sure he’s comfortable, I asked what his color is and he reply’s " \
      "with a trembling, “y-yellow..” So I make sure to cover bro in kisses then once he stops crying he asks, " \
      "“I’m okay now… Can you start moving?” I smile then press another kiss to his lips, " \
      "I begin to pick up the pace again. All while bro is thanking me and after we’re done I " \
      "clean the mess with a wipe and carry him to a warm bath and take care of him. Then when we’re in bed, " \
      "while we’re cuddling he tickles me and I giggle and " \
      "then we fall asleep in each other’s arms, lovesick and kind.",
      PlayerSession.bot
    )
  end
end

class CommandHandler
  @@commands = {} of String => {String, Array(String), Proc(Player, Hash(String, String), Nil)}
  
  register_commands

  def self.handle_command(player : Player, command_text : String)
    parts = command_text[Config.boat_prefix.size..-1].strip.split(' ')
    
    cmd_name = parts[0].downcase
    raw_args = parts[1..-1]? || [] of String

    if cmd_info = @@commands[cmd_name]?
      description, arg_names, handler = cmd_info
      
      parsed_args = {} of String => String
      
      arg_names.each_with_index do |arg_name, i|
        if i < raw_args.size
          parsed_args[arg_name] = raw_args[i]
        end
      end
      
      handler.call(player, parsed_args)
    else
      player.send_msg(
        "unknown command: #{cmd_name}\n" +
        "type '#{Config.boat_prefix}help' for available commands.",
        PlayerSession.bot
      )
    end
  end
end
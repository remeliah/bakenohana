require "time"

enum Ansi : Int32
  BLACK    = 30; RED      = 31; GREEN   = 32; YELLOW  = 33
  BLUE     = 34; MAGENTA  = 35; CYAN    = 36; WHITE   = 37
  GRAY     = 90; LRED     = 91; LGREEN  = 92; LYELLOW = 93
  LBLUE    = 94; LMAGENTA = 95; LCYAN   = 96; LWHITE  = 97
  RESET    = 0

  def to_s : String
    "\e[#{value}m"
  end
end

private LEVEL_MAP = {
  Ansi::LYELLOW => "WARN",
  Ansi::LRED    => "ERROR",
} of Ansi => String

def rlog(msg : Object, st_c : Ansi? = nil) : Nil
  return unless Config.debug

  level = LEVEL_MAP[st_c]? || "INFO"
  timestamp = Time.utc.to_s("%Y-%m-%dT%H:%M:%S.%6N")

  STDOUT << (st_c || Ansi::RESET).to_s 
  STDOUT << timestamp << "Z   " # so it looks like kemal's logging lul
  STDOUT << level << " - server: " << msg.to_s
  STDOUT << Ansi::RESET.to_s
  STDOUT << '\n'
end
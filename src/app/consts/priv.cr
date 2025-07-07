@[Flags]
enum Privileges : Int32 # TODO: add more
  UNRESTRICTED    = 1 << 0
  VERIFIED        = 1 << 1
  WHITELISTED     = 1 << 2

  SUPPORTER       = 1 << 4

  NOMINATOR       = 1 << 5
  MODERATOR       = 1 << 6
  ADMINISTRATOR   = 1 << 7

  PEPPY           = 1 << 8
  DEVELOPER       = 1 << 9

  BOAT            = UNRESTRICTED | MODERATOR | ADMINISTRATOR | DEVELOPER
end

@[Flags]
enum ClientPrivileges : Int32 # TODO: add more
  PLAYER        = 1 << 0

  MODERATOR     = 1 << 1
  SUPPORTER     = 1 << 2

  PEPPY         = 1 << 3
  DEVELOPER     = 1 << 4
end
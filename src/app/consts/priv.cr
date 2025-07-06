@[Flags]
enum Privileges : Int32 # TODO: add more
  UNRESTRICTED    = 1 << 0
  VERIFIED        = 1 << 1
  WHITELISTED     = 1 << 2

  SUPPORTER       = 1 << 4

  NOMINATOR       = 1 << 11
  MODERATOR       = 1 << 12
  ADMINISTRATOR   = 1 << 13
  DEVELOPER       = 1 << 14
end

@[Flags]
enum ClientPrivileges : Int32 # TODO: add more
  PLAYER        = 1 << 0

  MODERATOR     = 1 << 1
  SUPPORTER     = 1 << 2

  OWNER         = 1 << 3
  DEVELOPER     = 1 << 4
end
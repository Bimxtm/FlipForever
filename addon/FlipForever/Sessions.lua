-- Play sessions, for the app's gold per hour (switch gold_per_hour in the app): when each character
-- logged in and out and its gold at both ends. Kept per realm, the newest 300; very short ones are skipped.
local FF = FlipForever
local S = {}
FF.Sessions = S
S.MAX = 300
S.MIN = 120 -- seconds; a quick relog is not a session

function S:Start(now)
  self.start = now or time()
  self.money = GetMoney and GetMoney() or 0
end

function S:Stop(now)
  if not self.start then return nil end
  now = now or time()
  local name = UnitName and UnitName("player")
  local start = self.start
  self.start = nil
  if not name or now - start < self.MIN then return nil end
  local r = FF:DB()
  r.sessions = r.sessions or {}
  local s = { c = name, s = start, e = now, m0 = self.money or 0, m1 = GetMoney and GetMoney() or self.money or 0 }
  table.insert(r.sessions, s)
  while #r.sessions > self.MAX do table.remove(r.sessions, 1) end
  return s
end

FF:On("PLAYER_LOGIN", function() S:Start() end)
FF:On("PLAYER_LOGOUT", function() pcall(S.Stop, S) end)

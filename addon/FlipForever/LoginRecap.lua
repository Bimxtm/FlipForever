-- Login recap (switch loginRecap): when you log in, one chat line about this character's auctions
-- that ended while you were away (sold or expired, the mail tells which) and whether mail waits.
-- Built from FlipForever's own post log; the logout time is kept per character.
local FF = FlipForever
local R = {}
FF.LoginRecap = R

local HOURS = { [1] = 12, [2] = 24, [3] = 48 }
local MIN_AWAY = 15 * 60 -- shorter breaks (a reload, a quick relog) get no recap

function R:Enabled() return FlipForeverDB ~= nil and FlipForeverDB.settings.loginRecap ~= false end

local function charRecord()
  local name = UnitName and UnitName("player")
  if not name then return nil end
  local chars = FF:DB().chars
  chars[name] = chars[name] or {}
  return chars[name], name
end

-- auctions this character posted that ended between `since` and `now`, minus those the log
-- already shows as sold or expired before `since`. Returns count, value at the posted price.
function R:Ended(name, since, now)
  local log = FF:DB().log or {}
  local settled = {} -- id -> times of sold/expired lines logged while you played
  for _, e in ipairs(log) do
    if e.char == name and (e.e == "sold" or e.e == "expired") and e.id and (e.t or 0) <= since then
      settled[e.id] = settled[e.id] or {}
      table.insert(settled[e.id], e.t or 0)
    end
  end
  local n, value = 0, 0
  for _, e in ipairs(log) do
    if e.char == name and e.e == "post" and e.t and e.t < since then
      local ends = e.t + (HOURS[e.dur or 2] or 24) * 3600
      local list, hit = e.id and settled[e.id], nil
      for i, t in ipairs(list or {}) do
        if t >= e.t then hit = i break end
      end
      if hit then
        table.remove(list, hit) -- already sold or expired while you played
      elseif ends > since and ends <= now then
        n = n + 1
        value = value + (e.p or 0) * (e.q or 1)
      end
    end
  end
  return n, value
end

local function away(secs)
  local h = math.floor(secs / 3600)
  if h >= 48 then return FF:T("%d days"):format(math.floor(h / 24)) end
  if h >= 1 then return FF:T("%d h"):format(h) end
  return FF:T("%d min"):format(math.floor(secs / 60))
end

-- the recap line (nil when there is nothing worth saying)
function R:Line(now)
  if not self:Enabled() then return nil end
  local c, name = charRecord()
  if not (c and c.logout) then return nil end
  now = now or time()
  local gone = now - c.logout
  if gone < MIN_AWAY then return nil end
  local n, value = self:Ended(name, c.logout, now)
  local mail = HasNewMail and HasNewMail() and true or false
  if n == 0 and not mail then return nil end
  local parts = {}
  if n > 0 then
    parts[#parts + 1] = FF:T("%d of your auctions ended (up to %s if all sold)"):format(n, FF:Money(value))
  end
  if mail then parts[#parts + 1] = FF:T("new mail is waiting") end
  return FF:T("While you were away (%s): %s."):format(away(gone), table.concat(parts, FF:T(", ")))
end

FF:On("PLAYER_LOGIN", function()
  if not R:Enabled() then return end
  local function show()
    local ok, line = pcall(R.Line, R)
    if ok and line then FF:Print(line) end
  end
  if C_Timer and C_Timer.After then C_Timer.After(6, show) else show() end
end)

FF:On("PLAYER_LOGOUT", function()
  local c = charRecord()
  if c then c.logout = time() end
end)

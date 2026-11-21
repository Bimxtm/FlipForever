-- Leveling: XP per hour this session, time to the next level and rested XP, shown on the Overview.
-- Setting: levelInfo (on by default).
local FF = FlipForever
local LV = {}
FF.Leveling = LV

LV.MAX_LEVEL = 60

function LV:Enabled() return FlipForeverDB.settings.levelInfo ~= false end

local function now() return GetTime and GetTime() or 0 end
local function xp() return tonumber(UnitXP and UnitXP("player")) or 0 end
local function xpMax() return tonumber(UnitXPMax and UnitXPMax("player")) or 0 end
local function level() return tonumber(UnitLevel and UnitLevel("player")) or 1 end

function LV:Start()
  self.started, self.gained = now(), 0
  self.lastXP, self.lastMax, self.lastLevel = xp(), xpMax(), level()
end

-- add what you earned since the last update (a level-up adds the rest of the old level)
function LV:Update()
  if not self.started then self:Start() return end
  local cur, max, lvl = xp(), xpMax(), level()
  if lvl == self.lastLevel then
    if cur > self.lastXP then self.gained = self.gained + (cur - self.lastXP) end
  elseif lvl > self.lastLevel then
    self.gained = self.gained + math.max(0, self.lastMax - self.lastXP) + cur
  end
  self.lastXP, self.lastMax, self.lastLevel = cur, max, lvl
end

-- XP per hour this session (nil for the first minute, when the number would mean little)
function LV:PerHour()
  if not self.started then return nil end
  local secs = now() - self.started
  if secs < 60 or (self.gained or 0) <= 0 then return nil end
  return self.gained / secs * 3600
end

local function duration(secs)
  secs = math.floor(secs + 0.5)
  local h, m = math.floor(secs / 3600), math.floor((secs % 3600) / 60)
  if h > 0 then return FF:T("%d h %d min"):format(h, m) end
  return FF:T("%d min"):format(math.max(1, m))
end

local function thousands(n)
  local s = tostring(math.floor(n + 0.5))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

-- the Overview line; "" at the level cap or when switched off
function LV:Line()
  if not self:Enabled() then return "" end
  local lvl = level()
  if lvl >= self.MAX_LEVEL then return "" end
  local parts = {}
  local rate = self:PerHour()
  if rate then
    parts[#parts + 1] = FF:T("%s XP/hour"):format(thousands(rate))
    local left = xpMax() - xp()
    if left > 0 then parts[#parts + 1] = FF:T("level %d in %s"):format(lvl + 1, duration(left / rate * 3600)) end
  else
    parts[#parts + 1] = FF:T("XP per hour shows after your first kills or quests")
  end
  local rested = tonumber(GetXPExhaustion and GetXPExhaustion()) or 0
  if rested > 0 then parts[#parts + 1] = FF:T("rested %s XP"):format(thousands(rested)) end
  return FF:T("Leveling: ") .. table.concat(parts, "  ·  ")
end

FF:On("PLAYER_LOGIN", function() LV:Start() end)
FF:On("PLAYER_XP_UPDATE", function() LV:Update() end)
FF:On("PLAYER_LEVEL_UP", function() C_Timer.After(0.5, function() LV:Update() end) end)

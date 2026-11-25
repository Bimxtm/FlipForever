-- Enemy player alert (switch enemyAlert): on PvP realms, while gathering or questing in the open
-- world, a sound and one chat line when a player of the other faction who can attack you shows up
-- on a nameplate, or targets you. Read only from nameplates and target events; nothing is automated.
-- Quiet in dungeons, raids and battlegrounds. One line per player and minute, one sound per 10 s.
local FF = FlipForever
local A = {}
FF.EnemyAlert = A

local SAME_PLAYER = 60 -- seconds before the same player is named again
local SOUND_GAP = 10   -- seconds between two sounds

local seen, lastSound = {}, -1e9

function A:Enabled() return FlipForeverDB.settings.enemyAlert ~= false end

local function now() return (GetTime and GetTime()) or time() end

local function inInstance()
  if not IsInInstance then return false end
  local ok, inside = pcall(IsInInstance)
  return ok and inside and true or false
end

-- is this unit an enemy player who can attack you right now?
function A:IsThreat(unit)
  if not (unit and UnitExists and UnitExists(unit)) then return false end
  if not (UnitIsPlayer and UnitIsPlayer(unit)) then return false end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return false end
  if not (UnitCanAttack and UnitCanAttack(unit, "player")) then return false end
  if UnitIsEnemy and not UnitIsEnemy("player", unit) then return false end
  return true
end

local function describe(unit)
  local name = UnitName(unit) or "?"
  local lvl = UnitLevel and UnitLevel(unit) or 0
  local class = UnitClass and select(1, UnitClass(unit)) or nil
  local lv = (lvl and lvl > 0) and tostring(lvl) or "??"
  return name, class and (FF:T("level %s %s"):format(lv, class)) or (FF:T("level %s"):format(lv))
end

-- unit = a unit token, targeting = true when that player has you as target.
-- Returns the chat line it printed (nil when it stayed quiet).
function A:Check(unit, targeting)
  if not self:Enabled() or inInstance() or not self:IsThreat(unit) then return nil end
  local name, what = describe(unit)
  local key = name .. (targeting and "|t" or "|n")
  local t = now()
  if seen[key] and t - seen[key] < SAME_PLAYER then return nil end
  seen[key] = t
  if targeting then seen[name .. "|n"] = t end -- no extra "nearby" line right after
  local line
  if targeting then
    line = FF:T("Enemy player %s (%s) is targeting you!"):format(name, what)
  else
    line = FF:T("Enemy player nearby: %s (%s)."):format(name, what)
  end
  FF:Loud("|cffff4040" .. line .. "|r")
  pcall(self.RecordSpot, self)
  if t - lastSound >= SOUND_GAP and PlaySound then
    lastSound = t
    local kit = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959
    pcall(PlaySound, kit, "Master")
  end
  return line
end

function A:Reset() seen, lastSound = {}, -1e9 end

-- Where alerts went off (risky gathering spots): { map, x, y, t } of your own position, newest last.
-- Kept for this session only; the gathering loop skips spots near them for 10 minutes.
A.spots = {}

function A:RecordSpot(t)
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
  if not (ok and map) then return nil end
  local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not (okP and pos) then return nil end
  local x, y = pos.GetXY and pos:GetXY()
  if not x then x, y = pos.x, pos.y end
  if not (x and y) or (x == 0 and y == 0) then return nil end
  local s = { map = map, x = x, y = y, t = t or time() }
  self.spots[#self.spots + 1] = s
  while #self.spots > 20 do table.remove(self.spots, 1) end
  return s
end

local function targetsMe(unit)
  return UnitIsUnit and UnitExists and UnitExists(unit .. "target") and UnitIsUnit(unit .. "target", "player")
end

FF:On("NAME_PLATE_UNIT_ADDED", function(unit)
  if not A:Enabled() then return end
  pcall(function() A:Check(unit, targetsMe(unit)) end)
end)
FF:On("UNIT_TARGET", function(unit)
  if not (A:Enabled() and type(unit) == "string") then return end
  if unit:find("^nameplate") or unit == "target" or unit == "mouseover" then
    pcall(function() if targetsMe(unit) then A:Check(unit, true) end end)
  end
end)
FF:On("PLAYER_TARGET_CHANGED", function()
  if not A:Enabled() then return end
  pcall(function() A:Check("target", targetsMe("target")) end)
end)

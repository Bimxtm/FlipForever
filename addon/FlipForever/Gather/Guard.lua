-- FlipForever Gathering: the old stand-alone Ore Farmer addon and this module are the
-- same code. If Ore Farmer is still switched on for this character, let it run and
-- keep this module quiet, so nothing is recorded or drawn twice.
local _, ns = ...
FlipForever.gatherNS = ns

local function oreFarmerEnabled()
  -- the AddOns list for this character: Ore Farmer only counts when it will actually load here
  -- (the enable state below can also count Ore Farmer switched on for another character)
  local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
  if info then
    local ok, name, _, _, loadable, reason = pcall(info, "OreFarmer")
    if not ok or not name or reason == "MISSING" then return false end
    if loadable ~= nil then return loadable and true or false end
  end
  local me = UnitName and UnitName("player")
  local getState = (C_AddOns and C_AddOns.GetAddOnEnableState) or GetAddOnEnableState
  if not getState then return false end
  local ok, state = pcall(getState, "OreFarmer", me)
  if ok and type(state) == "number" then return state > 0 end
  ok, state = pcall(getState, me, "OreFarmer") -- older argument order
  return ok and type(state) == "number" and state > 0
end

ns.OreFarmerOn = oreFarmerEnabled
ns.skipGather = oreFarmerEnabled()

-- why Gathering can't open right now, in plain words (nil when it can)
function FlipForever:GatherOffReason()
  local g = self.gatherNS
  if not g then return self:T("Gathering didn't load.") end
  if g.skipGather then return self:T("Gathering is off: the old Ore Farmer addon is still on for this character. Turn it off in the AddOns list.") end
  if g.disabled then return self:T("Gathering is off: this game client gives addons no map positions.") end
  if not g.db then return self:T("Gathering hasn't started yet - try again in a moment or after /reload.") end
  return nil
end
if ns.skipGather then
  C_Timer.After(5, function()
    print("|cff33ff99FlipForever|r: Gathering is built in now - the old Ore Farmer addon is still on, so FlipForever's copy stays off. Turn Ore Farmer off in the AddOns list to use the built-in one.")
  end)
end

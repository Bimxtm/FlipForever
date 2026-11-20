-- FlipForever Gathering: the old stand-alone Ore Farmer addon and this module are the
-- same code. If Ore Farmer is still switched on for this character, let it run and
-- keep this module quiet, so nothing is recorded or drawn twice.
local _, ns = ...
FlipForever.gatherNS = ns

local function oreFarmerEnabled()
  local me = UnitName and UnitName("player")
  local getState = (C_AddOns and C_AddOns.GetAddOnEnableState) or GetAddOnEnableState
  if not getState then return false end
  local ok, state = pcall(getState, "OreFarmer", me)
  if ok and type(state) == "number" then return state > 0 end
  ok, state = pcall(getState, me, "OreFarmer") -- older argument order
  return ok and type(state) == "number" and state > 0
end

ns.skipGather = oreFarmerEnabled()
if ns.skipGather then
  C_Timer.After(5, function()
    print("|cff33ff99FlipForever|r: Gathering is built in now - the old Ore Farmer addon is still on, so FlipForever's copy stays off. Turn Ore Farmer off in the AddOns list to use the built-in one.")
  end)
end

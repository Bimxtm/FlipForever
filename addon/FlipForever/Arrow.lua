-- FlipForever waypoint arrow: one arrow on screen that points the way, with the distance.
-- It points at (first that applies):
--   1. a point you set yourself:  /ffway 45.2 60.8  (clear with /ffway)
--   2. the pin you placed on the world map (if this client has map pins)
--   3. the next stop on your Gathering loop
-- Only targets on the map you're on can be shown; the arrow hides otherwise.
local FF = FlipForever
local A = {}
FF.Arrow = A

local atan2, sqrt, floor = math.atan2 or function(y, x) return math.atan(y, x) end, math.sqrt, math.floor

function A:Enabled() return FlipForeverDB.settings.arrow ~= false end

-- where am I: map, x, y (0-1), or nil
local function playerPos()
  local ns = FF.gatherNS
  if ns and ns.PlayerPos then
    local ok, mapID, x, y = pcall(ns.PlayerPos)
    if ok and mapID then return mapID, x, y end
  end
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local mapID = C_Map.GetBestMapForUnit("player")
  local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  return mapID, x, y
end

-- size of a map in yards (width, height)
local function mapSize(mapID)
  local ns = FF.gatherNS
  if ns and ns.MapSize then
    local ok, w, h = pcall(ns.MapSize, mapID)
    if ok and w and h then return w, h end
  end
  if C_Map and C_Map.GetMapWorldSize then
    local w, h = C_Map.GetMapWorldSize(mapID)
    if w and w > 0 then return w, h end
  end
  return nil
end

-- the current target: { mapID, x, y, label } or nil
function A:Target()
  if self.manual then return self.manual end
  if C_Map and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() and C_Map.GetUserWaypoint then
    local wp = C_Map.GetUserWaypoint()
    if wp and wp.uiMapID and wp.position then
      local x, y = wp.position:GetXY()
      return { mapID = wp.uiMapID, x = x, y = y, label = FF:T("Map pin") }
    end
  end
  local ns = FF.gatherNS
  if ns and ns.GetNextStop and not ns.skipGather then
    local ok, p, r = pcall(ns.GetNextStop)
    if ok and p and r then
      local def = ns.OreByKey and ns.MainType and ns.OreByKey[ns.MainType(p.node)]
      return { mapID = r.mapID, x = p.x, y = p.y, label = def and def.label or FF:T("Next gathering stop") }
    end
  end
  return nil
end

-- direction and distance from the player: rotation (radians, for the arrow texture), yards
function A:Compute(target, mapID, px, py, facing)
  if not (target and mapID and target.mapID == mapID) then return nil end
  local w, h = mapSize(mapID)
  if not w then return nil end
  local dx, dy = (target.x - px) * w, -(target.y - py) * h        -- east, north in yards
  local dist = sqrt(dx * dx + dy * dy)
  local bearing = atan2(-dx, dy)                                  -- counter-clockwise from north
  return bearing - (facing or 0), dist
end

-- Frame -------------------------------------------------------------------------------------------
local frame
local function build()
  local f = CreateFrame("Frame", "FlipForeverArrow", UIParent)
  f:SetSize(64, 84)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    FlipForeverDB.settings.arrowPos = { point, relPoint, x, y }
  end)
  local pos = FlipForeverDB.settings.arrowPos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("TOP", 0, -260) end
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetTexture("Interface\\Minimap\\MinimapArrow")
  f.tex:SetSize(56, 56)
  f.tex:SetPoint("TOP")
  f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.label:SetPoint("TOP", f.tex, "BOTTOM", 0, 2)
  f.dist = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.dist:SetPoint("TOP", f.label, "BOTTOM", 0, -1)
  local since = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    since = since + (elapsed or 0)
    if since < 0.05 then return end
    since = 0
    A:Update()
  end)
  f:Hide()
  return f
end

function A:Update()
  if not frame then return end
  local target = self:Target()
  local mapID, px, py = playerPos()
  local facing = GetPlayerFacing and GetPlayerFacing()
  local rot, dist = self:Compute(target, mapID, px, py, facing)
  if not rot then
    frame.tex:SetAlpha(0.25)
    frame.label:SetText(target and target.label or "")
    frame.dist:SetText(target and FF:T("on another map") or "")
    return
  end
  frame.tex:SetAlpha(1)
  frame.tex:SetRotation(rot)
  frame.label:SetText(target.label or "")
  if self.manual and dist < 5 then
    FF:Print(FF:T("You've arrived."))
    self.manual = nil
  end
  frame.dist:SetText(("%d yd"):format(floor(dist + 0.5)))
  -- green when you're heading the right way
  local off = math.abs(((rot + math.pi) % (2 * math.pi)) - math.pi)
  if off < 0.35 then frame.tex:SetVertexColor(0.3, 1, 0.5) else frame.tex:SetVertexColor(1, 0.82, 0) end
end

-- show only when it has something to point at
function A:Refresh()
  if not self:Enabled() then if frame then frame:Hide() end return end
  frame = frame or build()
  if self:Target() then frame:Show() else frame:Hide() end
end

A.PlayerPos = playerPos

-- point at a map position (e.g. a quest giver from the Advisor); x, y are 0-1
function A:SetTarget(mapID, x, y, label)
  self.manual = { mapID = mapID, x = x, y = y, label = label or "" }
  FF:Print(("%s %s"):format(FF:T("Arrow points to"), label or ""))
  self:Refresh()
end

function A:SetManual(x, y)
  local mapID = playerPos()
  if not (x and y and mapID) then
    self.manual = nil
    FF:Print(FF:T("Waypoint cleared."))
  else
    self.manual = { mapID = mapID, x = x / 100, y = y / 100, label = ("%.1f, %.1f"):format(x, y) }
    FF:Print(("%s %.1f, %.1f"):format(FF:T("Arrow points to"), x, y))
  end
  self:Refresh()
end

SLASH_FLIPFOREVERWAY1 = "/ffway"
SlashCmdList.FLIPFOREVERWAY = function(msg)
  local x, y = (msg or ""):match("([%d%.]+)[%s,]+([%d%.]+)")
  A:SetManual(tonumber(x), tonumber(y))
end

-- look for something to point at every few seconds (new loop, new map pin, new zone)
FF:On("PLAYER_LOGIN", function()
  if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(2, function() A:Refresh() end) end
end)
FF:On("ZONE_CHANGED_NEW_AREA", function() A:Refresh() end)

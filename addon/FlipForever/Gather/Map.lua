-- FlipForever Gathering module (was the separate Ore Farmer addon).
if select(2, ...).skipGather then return end
-- Ore Farmer: pins and route on the world map and minimap.
--
-- Spots are saved on the zone map you were in. The world map may show another
-- map (a continent, or MapUtils' one-big-map view), so every spot is projected
-- onto whatever map is on screen with C_Map.GetMapRectOnMap.
local _, ns = ...

local GetTime = GetTime
local sqrt, max, abs = math.sqrt, math.max, math.abs
local plain = function(v) return ns.Plain(v) end

local function resColor(key)
  local def = ns.OreByKey[key]
  return def and def.color or { 1, 1, 1 }
end

local function makePin(parent)
  local pin = CreateFrame("Frame", nil, parent)
  pin.border = pin:CreateTexture(nil, "ARTWORK")
  pin.border:SetAllPoints()
  pin.border:SetColorTexture(0, 0, 0, 0.9)
  pin.fill = pin:CreateTexture(nil, "OVERLAY")
  pin.fill:SetPoint("TOPLEFT", 1, -1)
  pin.fill:SetPoint("BOTTOMRIGHT", -1, 1)
  pin:EnableMouse(true)
  pin:SetScript("OnEnter", function(self) ns.ShowNodeTooltip(self) end)
  pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return pin
end

local function paintPin(pin, node, isNext)
  local c = resColor(ns.MainType(node))
  pin.fill:SetColorTexture(c[1], c[2], c[3], 1)
  if isNext then pin.border:SetColorTexture(1, 1, 1, 1) else pin.border:SetColorTexture(0, 0, 0, 0.9) end
  pin.node = node
end

function ns.ShowNodeTooltip(pin)
  local node = pin.node
  if not node then return end
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  local total = 0
  for _, c in pairs(node.t) do total = total + c end
  GameTooltip:AddLine(node.ext and "Spot from GatherLite" or "Your gathering spot")
  for k, c in pairs(node.t) do
    local def = ns.OreByKey[k]
    local col = resColor(k)
    local note = ns.CanGather(k) and "" or "  (skill too low)"
    GameTooltip:AddLine(string.format("%s: %d%%%s", def and def.label or k, math.floor(c / total * 100 + 0.5), note),
      col[1], col[2], col[3])
  end
  local value = ns.NodeValue(node, ns.OreValue, ns.CanGather, ns.IsEnabled)
  GameTooltip:AddLine("Worth about " .. ns.FormatMoney(value) .. " per visit", 1, 1, 1)
  GameTooltip:AddLine(string.format("Gathered %d time(s), seen %d time(s)", node.mined or 0, node.n or 0), 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

local function isShown(node)
  for k in pairs(node.t) do
    if ns.IsEnabled(k) then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Projection between maps
---------------------------------------------------------------------------
local rectCache = {}
-- Where does map `from` sit on map `to`? Returns left, right, top, bottom (0..1) or nil.
local function rectOnMap(from, to)
  if from == to then return 0, 1, 0, 1 end
  local key = from * 1000000 + to
  local r = rectCache[key]
  if r == nil then
    r = false
    if C_Map.GetMapRectOnMap then
      local ok, l, rt, t, b = pcall(C_Map.GetMapRectOnMap, from, to)
      l, rt, t, b = plain(l), plain(rt), plain(t), plain(b)
      if ok and l and rt and t and b and rt > l and b > t then r = { l, rt, t, b } end
    end
    rectCache[key] = r
  end
  if not r then return nil end
  return r[1], r[2], r[3], r[4]
end
ns.RectOnMap = rectOnMap

---------------------------------------------------------------------------
-- World map
---------------------------------------------------------------------------
local canvas, overlay
local mapPins, mapLines = {}, {}
local mapDirty = true

function ns.RequestMapRefresh() mapDirty = true end

local function canvasScale()
  local s = WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale()
  s = plain(s)
  return (s and s > 0) and s or 1
end

local function refreshWorldMap()
  for _, p in ipairs(mapPins) do p:Hide() end
  for _, l in ipairs(mapLines) do l:Hide() end
  if not ns.db.showMap or not WorldMapFrame:IsShown() then return end
  local shownID = plain(WorldMapFrame:GetMapID())
  if not shownID then return end

  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local scale = canvasScale()
  local size = 11 / scale
  local nextP = ns.GetNextStop()
  local i, li = 0, 0
  -- With GatherLite, it draws the spots; we only add the route and next stop.
  local drawAll = not (ns.UsingGatherLite and ns.UsingGatherLite()) or ns.db.pinsWithGatherLite

  local zones = {}
  for zoneID, nodes in pairs(ns.db.nodes) do
    if #nodes > 0 then zones[zoneID] = true end
  end
  zones[shownID] = true
  local playerMap = ns.PlayerPos()
  if playerMap then zones[playerMap] = true end

  for zoneID in pairs(zones) do
    local nodes = ns.ZoneSpots(zoneID)
    if #nodes > 0 then
      local l, r, t, b = rectOnMap(zoneID, shownID)
      if l then
        local zoomedOut = zoneID ~= shownID
        for _, node in ipairs(nodes) do
          local isNextNode = nextP and nextP.node == node
          if (drawAll and isShown(node)) or isNextNode then
            i = i + 1
            local pin = mapPins[i]
            if not pin then
              pin = makePin(overlay)
              mapPins[i] = pin
            end
            local isNext = nextP and nextP.node == node
            local s = isNext and size * 1.5 or (zoomedOut and size * 0.7 or size)
            pin:SetSize(s, s)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", (l + node.x * (r - l)) * w, -(t + node.y * (b - t)) * h)
            paintPin(pin, node, isNext)
            pin:Show()
          end
        end

        if ns.db.showRoute then
          local route = ns.GetRoute(zoneID)
          local n = #route.order
          if n >= 2 then
            for k = 1, n do
              local a, c = route.pts[route.order[k]], route.pts[route.order[k % n + 1]]
              li = li + 1
              local line = mapLines[li]
              if not line then
                line = overlay:CreateLine(nil, "ARTWORK")
                mapLines[li] = line
              end
              line:SetColorTexture(1, 0.85, 0.2, 0.75)
              line:SetThickness((zoomedOut and 1.5 or 2.5) / scale)
              line:SetStartPoint("TOPLEFT", canvas, (l + a.x * (r - l)) * w, -(t + a.y * (b - t)) * h)
              line:SetEndPoint("TOPLEFT", canvas, (l + c.x * (r - l)) * w, -(t + c.y * (b - t)) * h)
              line:Show()
            end
          end
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Minimap
---------------------------------------------------------------------------
local mmPins = {}

local function minimapGeometry()
  local radius
  if C_Minimap and C_Minimap.GetViewRadius then
    radius = plain(C_Minimap.GetViewRadius())
  end
  if not radius or radius <= 0 then
    local indoors = IsIndoors and plain(IsIndoors()) or false
    radius = ns.MinimapRadius(plain(Minimap:GetZoom()) or 0, indoors)
  end
  local half = Minimap:GetWidth() / 2
  local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
  local rotate = getCVar and getCVar("rotateMinimap") == "1"
  local facing = rotate and GetPlayerFacing and plain(GetPlayerFacing()) or 0
  local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
  return radius, half, rotate, facing or 0, square
end

local function refreshMinimap()
  local used = 0
  local mapID, px, py = ns.PlayerPos()
  if mapID and ns.db.showMinimap then
    local W, H = ns.MapSize(mapID)
    local radius, half, rotate, facing, square = minimapGeometry()
    local toPx = half / radius
    local edge = half - 5
    local nextP = ns.GetNextStop()
    local drawAll = not (ns.UsingGatherLite and ns.UsingGatherLite()) or ns.db.pinsWithGatherLite
    for _, node in ipairs(ns.ZoneSpots(mapID)) do
      local isNext = nextP and nextP.node == node
      if (drawAll and isShown(node)) or isNext then
        local dx, dy = (node.x - px) * W, -(node.y - py) * H
        if rotate then dx, dy = ns.Rotate(dx, dy, facing) end
        local ox, oy = dx * toPx, dy * toPx
        local outside
        if square then
          outside = max(abs(ox), abs(oy)) > edge
        else
          outside = sqrt(ox * ox + oy * oy) > edge
        end
        if not outside or isNext then
          if outside then -- keep the next stop on the edge, pointing the way
            local f = square and edge / max(abs(ox), abs(oy)) or edge / sqrt(ox * ox + oy * oy)
            ox, oy = ox * f, oy * f
          end
          used = used + 1
          local pin = mmPins[used]
          if not pin then
            pin = makePin(Minimap)
            mmPins[used] = pin
          end
          pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
          pin:SetSize(isNext and 10 or 7, isNext and 10 or 7)
          pin:ClearAllPoints()
          pin:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
          paintPin(pin, node, isNext)
          pin:Show()
        end
      end
    end
  end
  for i = used + 1, #mmPins do mmPins[i]:Hide() end
end

-- Distance and direction to the next stop, for the panel.
function ns.NextStopInfo()
  local p, r = ns.GetNextStop()
  if not p then return nil end
  local mapID, px, py = ns.PlayerPos()
  if mapID ~= r.mapID then return nil end
  local dx, dy = (p.x - px) * r.W, -(p.y - py) * r.H
  local def = ns.OreByKey[ns.MainType(p.node)]
  return def and def.label or "Spot", sqrt(dx * dx + dy * dy), ns.Compass(dx, dy)
end

---------------------------------------------------------------------------
-- Find Minerals / Find Herbs dots: if the game lets us read the minimap
-- tooltip (it often doesn't on Forever), note the resource at the cursor.
---------------------------------------------------------------------------
local lastText, lastTextT = nil, 0

local function cleanLine(s)
  s = s:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function scrapeMinimapTooltip()
  if not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= Minimap then return end
  local fs = _G.GameTooltipTextLeft1
  local text = plain(fs and fs:GetText())
  if not text then return end
  if text == lastText and GetTime() - lastTextT < 3 then return end
  lastText, lastTextT = text, GetTime()

  local mapID, px, py = ns.PlayerPos()
  if not mapID then return end
  local W, H = ns.MapSize(mapID)
  local radius, half, rotate, facing = minimapGeometry()
  local cx, cy = GetCursorPosition()
  local s = Minimap:GetEffectiveScale()
  local mx, my = Minimap:GetCenter()
  local dx, dy = (cx / s - mx) / half * radius, (cy / s - my) / half * radius
  if rotate then dx, dy = ns.Rotate(dx, dy, -facing) end
  local x, y = px + dx / W, py - dy / H
  if x < 0 or x > 1 or y < 0 or y > 1 then return end

  for line in text:gmatch("[^\n]+") do
    local key = ns.NodeToOre[cleanLine(line)]
    if key then ns.RecordSeen(key, mapID, x, y) end
  end
end

---------------------------------------------------------------------------
function ns.InitMap()
  canvas = WorldMapFrame and ((WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas())
    or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child))
  if canvas then
    overlay = CreateFrame("Frame", nil, canvas)
    overlay:SetAllPoints(canvas)
    overlay:SetFrameLevel(math.min(canvas:GetFrameLevel() + 2400, 9000))
    local function queue() mapDirty = true end
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", queue) end
    if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", queue) end
    WorldMapFrame:HookScript("OnShow", queue)
    local acc, sinceFull = 0, 0
    overlay:SetScript("OnUpdate", function(_, elapsed)
      acc = acc + elapsed
      if acc < 0.1 then return end
      sinceFull = sinceFull + acc
      acc = 0
      if mapDirty or sinceFull > 1 then
        mapDirty, sinceFull = false, 0
        ns.Safe("world map", refreshWorldMap)
      end
    end)
  else
    ns.Print("couldn't find the world map, so spots only show on the minimap.")
  end

  local mm = CreateFrame("Frame")
  local acc = 0
  mm:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    ns.Safe("minimap", refreshMinimap)
    ns.Safe("minimap dots", scrapeMinimapTooltip)
  end)
end

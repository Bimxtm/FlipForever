-- FlipForever Gathering module (was the separate Ore Farmer addon).
if select(2, ...).skipGather then return end
-- Ore Farmer: saved data, recording what you gather, sessions, and the route.
--
-- How gathering is detected on WoW Forever: the game hides most object names
-- from addons ("secret" values), so the main signal is the loot window. Ore in
-- the loot = a mining node, a herb = a herb node, fishing loot = fishing.
-- When the game does show a name (cast target or tooltip), that name is used
-- because it is more exact (e.g. Rich vs Small Thorium, or a fishing pool).
local addonName, ns = ...

local GetTime, time = GetTime, time

local frame = CreateFrame("Frame")
ns.frame = frame

local DEFAULTS = {
  version = 2,
  nodes = {},        -- [mapID] = { node, ... }
  yield = {},        -- [resourceKey] = { visits = n, items = { [itemID] = count } }
  prices = {},       -- [itemID] = { p = copper } (your own prices)
  hidden = {},       -- [resourceKey] = true to hide it
  hiddenCat = {},    -- [categoryKey] = true to hide a whole category
  zoneStats = {},    -- [mapID] = { active = seconds, value = copper, nodes = n }
  custom = {},       -- resources learned in game
  skills = {},       -- [categoryKey] = manual skill override
  speed = nil,       -- learned travel speed (yards/second)
  availability = 0.5,
  secondsPerNode = 6,
  showRoute = true,
  showMap = true,
  showMinimap = true,
  panelShown = true,
  debug = false,
  useGatherLite = true,       -- read GatherLite's spots when it is installed
  pinsWithGatherLite = false, -- draw all spots ourselves even though GatherLite does
}

local function fillDefaults(db, def)
  for k, v in pairs(def) do
    if db[k] == nil then
      if type(v) == "table" then
        db[k] = {}
        fillDefaults(db[k], v)
      else
        db[k] = v
      end
    end
  end
end

function ns.Print(msg)
  local chat = DEFAULT_CHAT_FRAME or ChatFrame1
  if chat then chat:AddMessage("|cff33ff99FlipForever|r |cffe0a040Gathering|r: " .. tostring(msg)) end
end

function ns.Debug(msg)
  if ns.db and ns.db.debug then ns.Print("|cff888888[debug]|r " .. tostring(msg)) end
end

-- Run a function, turning any Lua error into one friendly chat line instead of
-- an error popup (and never repeating the same one).
local reported = {}
function ns.Safe(where, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok and not reported[where] then
    reported[where] = true
    ns.Print("something went wrong in " .. where .. " (" .. tostring(err) .. "). The rest keeps working.")
  end
  return ok
end

-- WoW Forever can hand addons "secret" values that error when compared or
-- indexed. Treat those as unknown.
function ns.IsSecret(v)
  return issecretvalue ~= nil and v ~= nil and issecretvalue(v) and true or false
end

local function plain(v)
  if v == nil or ns.IsSecret(v) then return nil end
  return v
end
ns.Plain = plain

---------------------------------------------------------------------------
-- Position and map size
---------------------------------------------------------------------------
function ns.PlayerPos()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local mapID = plain(C_Map.GetBestMapForUnit("player"))
  if not mapID then return nil end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos or ns.IsSecret(pos) then return nil end
  local x, y = plain(pos.x), plain(pos.y)
  if not x or not y or (x == 0 and y == 0) then return nil end
  return mapID, x, y
end

local sizeCache = {}
-- Returns width, height (yards), guessed (true if the game wouldn't say).
function ns.MapSize(mapID)
  local c = sizeCache[mapID]
  if c then return c[1], c[2], c[3] end
  local w, h
  if C_Map.GetMapWorldSize then
    local ok, a, b = pcall(C_Map.GetMapWorldSize, mapID)
    if ok then w, h = plain(a), plain(b) end
  end
  if (not w or w <= 0) and C_Map.GetWorldPosFromMapPos and CreateVector2D then
    local ok, _, tl = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
    local ok2, _, br = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
    if ok and ok2 and tl and br then
      local top, left = tl:GetXY()
      local bottom, right = br:GetXY()
      if top and left and bottom and right then w, h = math.abs(left - right), math.abs(top - bottom) end
    end
  end
  local guessed = false
  if not w or w <= 0 or not h or h <= 0 then w, h, guessed = 3000, 2000, true end
  sizeCache[mapID] = { w, h, guessed }
  return w, h, guessed
end

function ns.MapName(mapID)
  local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and plain(info.name) or ("map " .. tostring(mapID))
end

function ns.ZoneNodes(mapID)
  local list = ns.db.nodes[mapID]
  if not list then
    list = {}
    ns.db.nodes[mapID] = list
  end
  return list
end

---------------------------------------------------------------------------
-- Profession skill and filters
---------------------------------------------------------------------------
-- Returns skill, source ("manual" / "detected"); nil, "none" if you don't have
-- that profession; nil if it can't be told.
function ns.GetSkill(cat)
  if ns.db.skills[cat] then return ns.db.skills[cat], "manual" end
  local c = ns.CategoryByKey[cat]
  if not c or not c.skillLine then return nil end
  if GetProfessions and GetProfessionInfo then
    local list = { GetProfessions() }
    local readable = true
    for i = 1, 5 do
      local idx = list[i]
      if idx then
        local name, _, rank, _, _, _, skillLine = GetProfessionInfo(idx)
        name, rank, skillLine = plain(name), plain(rank), plain(skillLine)
        if not name then readable = false end
        if rank and (skillLine == c.skillLine or name == c.label) then return rank, "detected" end
      end
    end
    if readable then return nil, "none" end
  end
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank = GetSkillLineInfo(i)
      if not isHeader and name == c.label then return rank, "detected" end
    end
  end
  return nil
end

function ns.GetMiningSkill() return ns.GetSkill("mining") end

function ns.CanGather(key)
  local def = ns.OreByKey[key]
  if not def then return true end
  local skill, src = ns.GetSkill(def.cat)
  if src == "none" then return false end -- you don't have this profession
  if (def.skill or 0) <= 0 or not skill then return true end
  return def.skill <= skill
end
ns.CanMine = ns.CanGather

function ns.IsEnabled(key)
  local def = ns.OreByKey[key]
  if def and ns.db.hiddenCat[def.cat] then return false end
  return not ns.db.hidden[key]
end

-- Enabled and allowed on the route (fishing spots are only markers).
function ns.OnRoute(key)
  local def = ns.OreByKey[key]
  return ns.IsEnabled(key) and not (def and def.noRoute)
end

function ns.OreValue(key)
  local def = ns.OreByKey[key]
  return ns.YieldValue(ns.db.yield[key], ns.PriceOf, def and def.ore)
end

---------------------------------------------------------------------------
-- Route (cached per zone; rebuilt when a spawn point or filter changes)
---------------------------------------------------------------------------
ns.routeCache = {}

function ns.MarkDirty(mapID)
  if mapID then ns.routeCache[mapID] = nil else ns.routeCache = {} end
  if ns.RequestMapRefresh then ns.RequestMapRefresh() end
end

-- Your spots, plus GatherLite's when it is installed.
function ns.ZoneSpots(mapID)
  if ns.AllNodes then return ns.AllNodes(mapID) end
  return ns.db.nodes[mapID] or {}
end

function ns.GetRoute(mapID)
  local source = ns.ZoneSpots(mapID)
  local r = ns.routeCache[mapID]
  if r and r.source == source then return r end
  local W, H, guessed = ns.MapSize(mapID)
  local pts = {}
  for _, node in ipairs(source) do
    local _, relevant = ns.NodeValue(node, ns.OreValue, ns.CanGather, ns.OnRoute)
    if relevant then pts[#pts + 1] = { x = node.x, y = node.y, node = node } end
  end
  r = { mapID = mapID, pts = pts, W = W, H = H, guessed = guessed, source = source,
        order = ns.BuildRoute(pts, W, H, debugprofilestop, 150) }
  ns.routeCache[mapID] = r
  return r
end

-- Fresh estimate with current prices and yields (route order is cached).
function ns.EstimateRoute(mapID)
  local r = ns.GetRoute(mapID)
  local anyGuess = false
  for _, p in ipairs(r.pts) do
    p.value = ns.NodeValue(p.node, function(k)
      local v, guess = ns.OreValue(k)
      if guess then anyGuess = true end
      return v
    end, ns.CanGather, ns.OnRoute)
  end
  local est = ns.EstimateLoop(r.pts, r.order, r.W, r.H, {
    speed = ns.db.speed, secondsPerNode = ns.db.secondsPerNode, availability = ns.db.availability,
  })
  est.guess = anyGuess or r.guessed
  return est, r
end

-- Next stop on the loop.
ns.nextStop = { route = nil, pos = nil }

local function updateNextStop(mapID, px, py)
  local r = ns.GetRoute(mapID)
  local n = #r.order
  local st = ns.nextStop
  if n == 0 then st.route, st.pos = r, nil; return end
  if st.route ~= r or not st.pos or not r.order[st.pos] then
    local best, bd
    for k = 1, n do
      local p = r.pts[r.order[k]]
      local d = ns.Yards(p.x, p.y, px, py, r.W, r.H)
      if not bd or d < bd then best, bd = k, d end
    end
    st.route, st.pos = r, best
  end
  -- Reached it (gathered, or passed by and it wasn't there): move on.
  for _ = 1, n do
    local p = r.pts[r.order[st.pos]]
    if ns.Yards(p.x, p.y, px, py, r.W, r.H) > 12 then break end
    st.pos = st.pos % n + 1
  end
end

function ns.GetNextStop()
  local r, pos = ns.nextStop.route, ns.nextStop.pos
  if not r or not pos or ns.routeCache[r.mapID] ~= r then return nil end
  return r.pts[r.order[pos]], r
end

---------------------------------------------------------------------------
-- Farming session (time counts while moving or gathering; idle time after
-- your last node is dropped)
---------------------------------------------------------------------------
function ns.ResetSession()
  ns.session = { start = nil, active = 0, pending = 0, value = 0, nodes = 0, lastMine = 0, mapID = nil }
end
ns.ResetSession()

local function zoneStats(mapID)
  local z = ns.db.zoneStats[mapID]
  if not z then
    z = { active = 0, value = 0, nodes = 0 }
    ns.db.zoneStats[mapID] = z
  end
  return z
end

---------------------------------------------------------------------------
-- Recording
---------------------------------------------------------------------------
local pending    -- { key, t } from a cast whose target name we could read
local lastHover  -- { key, t } from a tooltip we could read

local function lootItems()
  local items = {}
  if not GetNumLootItems then return items end
  for i = 1, GetNumLootItems() do
    local link = plain(GetLootSlotLink and GetLootSlotLink(i))
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then
      local _, name, qty = GetLootSlotInfo(i)
      items[#items + 1] = { id = id, name = plain(name), qty = tonumber(plain(qty)) or 1 }
    end
  end
  return items
end

-- Which resource does this loot come from?
local function keyFromItems(items)
  for _, it in ipairs(items) do
    if ns.ItemToOre[it.id] then return ns.ItemToOre[it.id] end
  end
  -- Something new: an unknown ore (Trade Goods > Metal & Stone, "... Ore") or herb.
  if C_Item and C_Item.GetItemInfoInstant then
    for _, it in ipairs(items) do
      local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(it.id)
      classID, subclassID = plain(classID), plain(subclassID)
      if classID == 7 and it.name then
        if subclassID == 7 and it.name:find(" Ore$") then
          ns.Print("learned a new ore: " .. it.name)
          return ns.RegisterCustomOre(it.name, "mining", it.id)
        elseif subclassID == 9 then
          ns.Print("learned a new herb: " .. it.name)
          return ns.RegisterCustomOre(it.name, "herbalism", it.id)
        end
      end
    end
  end
  return nil
end

local function targetIsDeadMob()
  return UnitExists and UnitExists("target") and UnitIsDead and plain(UnitIsDead("target")) and true or false
end

local function record(key, items)
  local mapID, x, y = ns.PlayerPos()
  if not mapID then ns.Debug("no map position, not recorded"); return end
  local def = ns.OreByKey[key]
  local W, H = ns.MapSize(mapID)
  local node, isNew, newVisit = ns.AddObservation(ns.ZoneNodes(mapID), key, x, y, W, H, time(),
    def and def.merge, true)

  local yd = ns.db.yield[key]
  if not yd then
    yd = { visits = 0, items = {} }
    ns.db.yield[key] = yd
  end
  if newVisit then yd.visits = yd.visits + 1 end

  local s = ns.session
  if not s.start then s.start = GetTime() end
  local z = zoneStats(mapID)
  s.active = s.active + s.pending -- travel time to this node counts
  z.active = z.active + s.pending
  s.pending = 0
  s.lastMine = GetTime()
  if newVisit then
    s.nodes = s.nodes + 1
    z.nodes = z.nodes + 1
  end

  local value = 0
  for _, it in ipairs(items) do
    yd.items[it.id] = (yd.items[it.id] or 0) + it.qty
    value = value + it.qty * (ns.PriceOf(it.id) or 0)
    if ns.TrackItem then ns.TrackItem(it.id) end
  end
  s.value = s.value + value
  z.value = z.value + value

  ns.Debug(string.format("recorded %s at %.3f, %.3f (map %d)%s, loot worth %s",
    def and def.label or key, x, y, mapID, isNew and ", new spot" or "", ns.FormatMoney(value)))
  if isNew then ns.MarkDirty(mapID) elseif ns.RequestMapRefresh then ns.RequestMapRefresh() end
  if ns.RefreshUI then ns.RefreshUI() end
end

-- Seen on the minimap without gathering it.
function ns.RecordSeen(key, mapID, x, y)
  local def = ns.OreByKey[key]
  local W, H = ns.MapSize(mapID)
  local _, isNew = ns.AddObservation(ns.ZoneNodes(mapID), key, x, y, W, H, time(), def and def.merge, false)
  if isNew then
    ns.MarkDirty(mapID)
    ns.Debug("noted " .. (def and def.label or key) .. " from the minimap")
  end
end

-- A tooltip or cast showed a readable name: remember it for the next loot.
function ns.NoteName(name, fromCast)
  local key = ns.OreKeyForNodeName(name)
  if key then
    local entry = { key = key, t = GetTime() }
    if fromCast then pending = entry else lastHover = entry end
  end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local handlers = {}

function handlers.ADDON_LOADED(name)
  if name ~= addonName then return end
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
    ns.disabled = true
    ns.Print("this game client doesn't give addons map positions, so Gathering can't work here.")
    return
  end
  OreFarmerDB = OreFarmerDB or {}
  fillDefaults(OreFarmerDB, DEFAULTS)
  ns.db = OreFarmerDB
  if ns.db.skill then -- version 1 kept one mining skill
    ns.db.skills.mining = ns.db.skill
    ns.db.skill = nil
  end
  for nodeName, info in pairs(ns.db.custom) do
    if type(info) == "table" then ns.RegisterCustomOre(nodeName, info.cat, info.item)
    else ns.RegisterCustomOre(nodeName, "mining") end
  end
  if ns.InitMap then ns.Safe("map", ns.InitMap) end
  if ns.InitUI then ns.Safe("panel", ns.InitUI) end
end

function handlers.UNIT_SPELLCAST_SENT(unit, target)
  unit, target = plain(unit), plain(target)
  if unit ~= "player" or not target or target == "" then return end
  ns.NoteName(target, true)
  ns.Debug("cast target: " .. target)
end

function handlers.LOOT_OPENED()
  local items = lootItems()
  local now = GetTime()
  local named = (pending and now - pending.t < 15 and pending) or (lastHover and now - lastHover.t < 20 and lastHover)
  local key

  if IsFishingLoot and plain(IsFishingLoot()) then
    local def = named and ns.OreByKey[named.key]
    key = (def and def.cat == "fishing") and named.key or "fish:spot"
  elseif targetIsDeadMob() then
    ns.Debug("loot from a dead mob, ignored")
    return
  else
    local fromItems = keyFromItems(items)
    local def = named and ns.OreByKey[named.key]
    -- Prefer the exact name if it agrees with the loot (same profession).
    if def and (not fromItems or ns.OreByKey[fromItems].cat == def.cat) then
      key = named.key
    else
      key = fromItems
    end
  end
  pending, lastHover = nil, nil
  if not key then
    ns.Debug("loot window: nothing farmable recognised")
    return
  end
  record(key, items)
end

function handlers.ZONE_CHANGED_NEW_AREA()
  ns.nextStop.route = nil
  if ns.RequestMapRefresh then ns.RequestMapRefresh() end
end

function handlers.SKILL_LINES_CHANGED()
  ns.MarkDirty() -- you may be able to gather more now
end

frame:SetScript("OnEvent", function(_, event, ...)
  if ns.disabled then return end
  if event ~= "ADDON_LOADED" and not ns.db then return end
  ns.Safe(event, handlers[event], ...)
end)
for event in pairs(handlers) do pcall(frame.RegisterEvent, frame, event) end

-- Readable world tooltips (hovering a vein, herb, pool or chest).
if GameTooltip then
  GameTooltip:HookScript("OnShow", function(tip)
    if not ns.db then return end
    if tip.GetUnit and tip:GetUnit() then return end
    local fs = _G.GameTooltipTextLeft1
    local text = plain(fs and fs:GetText())
    if text then ns.NoteName(text, false) end
  end)
end

---------------------------------------------------------------------------
-- Ticker: travel speed, session time, next stop
---------------------------------------------------------------------------
local acc = 0
local function tick(dt)
  local speed = plain(GetUnitSpeed and GetUnitSpeed("player")) or 0
  local onTaxi = UnitOnTaxi and plain(UnitOnTaxi("player"))
  if speed > 0 and not onTaxi and speed <= 14 then
    if speed > (ns.db.speed or 0) then ns.db.speed = speed end
  end

  local s = ns.session
  if s.start then
    if (speed > 0 and not onTaxi) or GetTime() - s.lastMine < 10 then s.pending = s.pending + dt end
    -- Nothing gathered for 5 minutes: the farming stretch is over; drop the idle tail.
    if GetTime() - s.lastMine > 300 then
      s.pending = 0
      s.start = nil
    end
  end

  local mapID, px, py = ns.PlayerPos()
  if mapID and ns.db.showRoute then updateNextStop(mapID, px, py) end
end

frame:SetScript("OnUpdate", function(_, elapsed)
  if not ns.db then return end
  acc = acc + elapsed
  if acc < 0.25 then return end
  local dt = acc
  acc = 0
  ns.Safe("update", tick, dt)
end)

-- Measured gold per hour for this run (nil until enough data).
function ns.SessionRate()
  local s = ns.session
  if s.active < 120 or s.nodes < 3 then return nil end
  return s.value / s.active * 3600
end

function ns.ZoneRate(mapID)
  local z = ns.db.zoneStats[mapID]
  if not z or z.active < 600 or z.nodes < 10 then return nil, z end
  return z.value / z.active * 3600, z
end

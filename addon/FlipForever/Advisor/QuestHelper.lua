-- FlipForever quest helper: where to go next for the quests in your log.
-- FlipForever has no quest database of its own yet, so it learns from your play and keeps what it
-- learns for every character on the account:
--   - where you took each quest (the quest giver),
--   - where its objectives moved forward (each kill, item or event, as a map point),
--   - where you handed it in.
-- From that, the next spot of a quest is the area of its first unfinished objective, or, once it
-- is done, the place to hand it in (the giver until a hand-in has been seen). If the game client
-- can tell the next waypoint itself, that comes first.
-- /ff quest points the waypoint arrow at the next spot; quest spots also show on the world map.
-- Setting: questHelper (on by default).
local FF = FlipForever
local QH = {}
FF.QuestHelper = QH

local MAX_POINTS = 30   -- objective points kept per objective (newest replace the oldest)

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

function QH:Enabled() return FlipForeverDB.settings.questHelper ~= false end

-- learned data, shared by all characters: [questID] = { title, giver, turnin, obj = { [i] = { points } } }
function QH:Data()
  FlipForeverDB.quests = FlipForeverDB.quests or {}
  return FlipForeverDB.quests
end

function QH:Entry(questID, title)
  local d = self:Data()
  d[questID] = d[questID] or { obj = {} }
  if title and title ~= "" then d[questID].title = title end
  d[questID].obj = d[questID].obj or {}
  return d[questID]
end

local function here()
  if not (FF.Arrow and FF.Arrow.PlayerPos) then return nil end
  local m, x, y = FF.Arrow.PlayerPos()
  if m and x and y then return { m = m, x = x, y = y } end
  return nil
end

-- The quest log -----------------------------------------------------------------------------------
-- { questID, title, complete, objectives = { { text, done } } } for every quest in the log
function QH:Log()
  local out = {}
  local QL = C_QuestLog
  if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo) then return out end
  local ok, n = pcall(QL.GetNumQuestLogEntries)
  for i = 1, (ok and tonumber(n) or 0) do
    local info = QL.GetInfo(i)
    local id = info and plain(info.questID)
    if id and not info.isHeader then
      local q = { questID = id, title = plain(info.title) or ("Quest " .. id), objectives = {} }
      local okC, complete = pcall(QL.IsComplete or function() return false end, id)
      q.complete = okC and complete and true or false
      local okO, objs = pcall(QL.GetQuestObjectives or function() return {} end, id)
      for k, o in ipairs(okO and objs or {}) do
        q.objectives[k] = { text = plain(o.text) or "", done = o.finished and true or false, have = tonumber(o.numFulfilled) or 0 }
      end
      out[#out + 1] = q
    end
  end
  return out
end

-- Learning ----------------------------------------------------------------------------------------
local lastNpc        -- { n, m, x, y } of the NPC whose quest window you opened last
local progress = {}  -- [questID][objective] = count seen last time (no point recorded for the first look)

function QH:SeeNpc()
  local name = UnitName and plain(UnitName("npc"))
  local p = here()
  if name and p then lastNpc = { n = name, m = p.m, x = p.x, y = p.y } end
end

function QH:OnAccepted(questID)
  questID = tonumber(plain(questID))
  if not questID then return end
  local title
  for _, q in ipairs(self:Log()) do if q.questID == questID then title = q.title end end
  local e = self:Entry(questID, title)
  if lastNpc then e.giver = { n = lastNpc.n, m = lastNpc.m, x = lastNpc.x, y = lastNpc.y } end
end

function QH:OnTurnedIn(questID)
  questID = tonumber(plain(questID))
  if not questID then return end
  local e = self:Entry(questID)
  local p = lastNpc or here()
  if p then e.turnin = { n = p.n, m = p.m, x = p.x, y = p.y } end
  progress[questID] = nil
end

-- objective counts went up: note where you are for that objective
function QH:OnLogUpdate()
  local p = here()
  for _, q in ipairs(self:Log()) do
    local seen = progress[q.questID]
    local first = seen == nil
    seen = seen or {}
    for k, o in ipairs(q.objectives) do
      if not first and p and o.have > (seen[k] or 0) then
        local e = self:Entry(q.questID, q.title)
        local pts = e.obj[k] or {}
        pts[#pts + 1] = { m = p.m, x = p.x, y = p.y }
        while #pts > MAX_POINTS do table.remove(pts, 1) end
        e.obj[k] = pts
      end
      seen[k] = o.have
    end
    progress[q.questID] = seen
    -- just finished: say where to hand it in
    if q.complete and not seen.complete then
      seen.complete = true
      if not first and self:Enabled() then
        local spot = self:Spot(q)
        if spot then FF:Print(FF:T("Quest ready to hand in: %s. /ff quest points the arrow there."):format(q.title)) end
      end
    end
  end
end

-- Where to go -------------------------------------------------------------------------------------
-- middle of an objective's points, on the map most of them are on
local function centre(points)
  if not points or #points == 0 then return nil end
  local count, best = {}, nil
  for _, p in ipairs(points) do
    count[p.m] = (count[p.m] or 0) + 1
    if not best or count[p.m] > count[best] then best = p.m end
  end
  local sx, sy, n = 0, 0, 0
  for _, p in ipairs(points) do
    if p.m == best then sx, sy, n = sx + p.x, sy + p.y, n + 1 end
  end
  return { m = best, x = sx / n, y = sy / n }
end
QH.Centre = centre

-- the next spot for a quest from the log: { m, x, y, label, kind = "turnin" | "objective" | "game" }
function QH:Spot(q)
  local e = self:Data()[q.questID]
  if q.complete then
    if e and e.turnin then return { m = e.turnin.m, x = e.turnin.x, y = e.turnin.y, kind = "turnin",
      label = FF:T("Hand in: %s"):format(e.turnin.n or q.title) } end
    if e and e.giver then return { m = e.giver.m, x = e.giver.x, y = e.giver.y, kind = "turnin",
      label = FF:T("Hand in (quest giver): %s"):format(e.giver.n) } end
  else
    for k, o in ipairs(q.objectives) do
      if not o.done then
        local c = e and centre(e.obj[k])
        if c then return { m = c.m, x = c.x, y = c.y, kind = "objective", label = o.text ~= "" and o.text or q.title } end
        break   -- the first unfinished objective decides; later ones wait
      end
    end
  end
  -- the game's own waypoint, where the client has one
  if C_QuestLog and C_QuestLog.GetNextWaypoint then
    local ok, m, x, y = pcall(C_QuestLog.GetNextWaypoint, q.questID)
    m, x, y = plain(m), plain(x), plain(y)
    if ok and m and x and y then return { m = m, x = x, y = y, kind = "game", label = q.title } end
  end
  return nil
end

-- the quests that have a spot, ready-to-hand-in ones first
function QH:Spots()
  local out = {}
  for _, q in ipairs(self:Log()) do
    local s = self:Spot(q)
    if s then s.quest = q out[#out + 1] = s end
  end
  table.sort(out, function(a, b)
    local ra, rb = a.kind == "turnin" and 0 or 1, b.kind == "turnin" and 0 or 1
    if ra ~= rb then return ra < rb end
    return a.quest.title < b.quest.title
  end)
  return out
end

-- Advisor steps pinned on the map (right-click a step in the Advisor) -----------------------------
function QH:PinsEnabled() return FlipForeverDB.settings.advisorPins ~= false end

function QH:PinStore()
  local db = FF:DB()
  local name = UnitName("player") or "?"
  db.chars[name] = db.chars[name] or {}
  db.chars[name].mapPins = db.chars[name].mapPins or {}
  return db.chars[name].mapPins
end

local function samePin(a, m, x, y, label)
  return a.m == m and math.abs(a.x - x) < 0.0005 and math.abs(a.y - y) < 0.0005 and a.label == label
end

function QH:IsPinned(m, x, y, label)
  for _, a in ipairs(self:PinStore()) do if samePin(a, m, x, y, label) then return true end end
  return false
end

-- pins or unpins a place; returns true when it is pinned afterwards
function QH:TogglePin(m, x, y, label, title)
  if not (m and x and y) then return false end
  local list = self:PinStore()
  for i, a in ipairs(list) do
    if samePin(a, m, x, y, label) then
      table.remove(list, i)
      FF:Print(FF:T("Removed from the map:") .. " " .. (label or ""))
      self:RefreshAll()
      return false
    end
  end
  list[#list + 1] = { m = m, x = x, y = y, label = label, title = title }
  FF:Print(FF:T("Pinned on the map:") .. " " .. (label or ""))
  self:RefreshAll()
  return true
end

-- quest spots (quest helper) and pinned Advisor steps, each behind its own switch
function QH:MapSpots()
  local out = {}
  if self:Enabled() then for _, s in ipairs(self:Spots()) do out[#out + 1] = s end end
  if self:PinsEnabled() then
    for _, a in ipairs(self:PinStore()) do
      out[#out + 1] = { m = a.m, x = a.x, y = a.y, kind = "advisor", label = a.label or "", quest = { title = a.title or FF:T("Advisor step") }, pin = a }
    end
  end
  return out
end

function QH:RefreshAll()
  pcall(self.RefreshMap, self)
  pcall(self.RefreshMinimap, self)
end

local function iconFor(s)
  if s.kind == "advisor" then return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" end
  return s.kind == "turnin" and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\AvailableQuestIcon"
end

-- /ff quest: the arrow points at the next quest spot; again for the one after it
QH.pick = 0
function QH:Next()
  if not self:Enabled() then FF:Print(FF:T("The quest helper is off (Settings, Features).")) return nil end
  local spots = self:Spots()
  if #spots == 0 then
    FF:Print(FF:T("No quest spots known yet. FlipForever learns them as you take quests, work on them and hand them in."))
    return nil
  end
  self.pick = self.pick % #spots + 1
  local s = spots[self.pick]
  if FF.Arrow and FF.Arrow.SetTarget then
    FF.Arrow:SetTarget(s.m, s.x, s.y, ("%s - %s"):format(s.quest.title, s.label))
  end
  return s
end

-- World map pins ----------------------------------------------------------------------------------
local pins, overlay = {}, nil

local function mapCanvas()
  if not WorldMapFrame then return nil end
  return (WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas())
    or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
end

local function pin(i, canvas)
  if pins[i] then return pins[i] end
  overlay = overlay or CreateFrame("Frame", nil, canvas)
  if overlay.SetAllPoints then overlay:SetAllPoints(canvas) end
  if overlay.SetFrameLevel and canvas.GetFrameLevel then overlay:SetFrameLevel((canvas:GetFrameLevel() or 1) + 20) end
  local p = CreateFrame("Frame", nil, overlay)
  p.tex = p:CreateTexture(nil, "OVERLAY")
  p.tex:SetAllPoints(p)
  if p.EnableMouse then p:EnableMouse(true) end
  p:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.spot) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.spot.quest.title, 1, 0.82, 0)
    GameTooltip:AddLine(self.spot.label, 1, 1, 1, true)
    if self.spot.kind == "advisor" then
      GameTooltip:AddLine(FF:T("Pinned from the Advisor. Click: arrow points here. Right-click: remove."), 0.6, 0.6, 0.6, true)
    else
      GameTooltip:AddLine(FF:T("Learned from your play. /ff quest points the arrow here."), 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
  end)
  p:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  p:SetScript("OnMouseUp", function(self, button)
    local s = self.spot
    if not s then return end
    if button == "RightButton" and s.pin then
      if GameTooltip then GameTooltip:Hide() end
      QH:TogglePin(s.pin.m, s.pin.x, s.pin.y, s.pin.label, s.pin.title)
    elseif FF.Arrow and FF.Arrow.SetTarget then
      FF.Arrow:SetTarget(s.m, s.x, s.y, ("%s - %s"):format(s.quest.title, s.label))
    end
  end)
  pins[i] = p
  return p
end

-- returns how many pins are shown
function QH:RefreshMap()
  for _, p in ipairs(pins) do p:Hide() end
  if not ((self:Enabled() or self:PinsEnabled()) and WorldMapFrame and WorldMapFrame:IsShown()) then return 0 end
  local canvas = mapCanvas()
  local shown = canvas and plain(WorldMapFrame:GetMapID())
  if not shown then return 0 end
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local scale = plain(WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale()) or 1
  local size = 18 / ((scale and scale > 0) and scale or 1)
  local n = 0
  for _, s in ipairs(self:MapSpots()) do
    if s.m == shown then
      n = n + 1
      local p = pin(n, canvas)
      p.spot = s
      p:SetSize(size, size)
      p:ClearAllPoints()
      p:SetPoint("CENTER", canvas, "TOPLEFT", s.x * w, -s.y * h)
      p.tex:SetTexture(iconFor(s))
      p:Show()
    end
  end
  return n
end

-- Minimap pins -----------------------------------------------------------------------------------
-- Quest spots on your map: inside the minimap where they are, the others on its edge (faded),
-- pointing the way.
local mmPins = {}

local function mapSize(m)
  local ns = FF.gatherNS
  if ns and ns.MapSize then
    local ok, w, h = pcall(ns.MapSize, m)
    if ok and w and h then return w, h end
  end
  if C_Map and C_Map.GetMapWorldSize then
    local w, h = C_Map.GetMapWorldSize(m)
    w, h = plain(w), plain(h)
    if w and w > 0 then return w, h end
  end
  return nil
end

-- yards shown from the centre to the edge of the minimap
local function viewRadius()
  if C_Minimap and C_Minimap.GetViewRadius then
    local r = plain(C_Minimap.GetViewRadius())
    if r and r > 0 then return r end
  end
  local ns = FF.gatherNS
  if ns and ns.MinimapRadius and Minimap and Minimap.GetZoom then
    local ok, r = pcall(ns.MinimapRadius, plain(Minimap:GetZoom()) or 0, IsIndoors and plain(IsIndoors()) or false)
    if ok and r and r > 0 then return r end
  end
  return 150
end

local function rotate(dx, dy, facing)
  -- the same turn as the gathering pins (the minimap turns against your facing)
  local c, s = math.cos(facing), math.sin(facing)
  return dx * c + dy * s, -dx * s + dy * c
end

-- returns how many pins are shown
function QH:RefreshMinimap()
  local used = 0
  local m, px, py
  if (self:Enabled() or self:PinsEnabled()) and Minimap and FF.Arrow and FF.Arrow.PlayerPos then m, px, py = FF.Arrow.PlayerPos() end
  local W, H
  if m then W, H = mapSize(m) end
  if W then
    local half = (Minimap:GetWidth() or 140) / 2
    local toPx = half / viewRadius()
    local edge = half - 6
    local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
    local rotating = getCVar and getCVar("rotateMinimap") == "1"
    local facing = rotating and GetPlayerFacing and plain(GetPlayerFacing()) or 0
    for _, s in ipairs(self:MapSpots()) do
      if s.m == m then
        local dx, dy = (s.x - px) * W, -(s.y - py) * H
        if rotating then dx, dy = rotate(dx, dy, facing) end
        local ox, oy = dx * toPx, dy * toPx
        local d = math.sqrt(ox * ox + oy * oy)
        local outside = d > edge
        if outside then ox, oy = ox * edge / d, oy * edge / d end
        used = used + 1
        local p = mmPins[used]
        if not p then
          p = CreateFrame("Frame", nil, Minimap)
          p.tex = p:CreateTexture(nil, "OVERLAY")
          p.tex:SetAllPoints(p)
          mmPins[used] = p
        end
        if p.SetFrameLevel and Minimap.GetFrameLevel then p:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 6) end
        p:SetSize(14, 14)
        p:ClearAllPoints()
        p:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
        p.tex:SetTexture(iconFor(s))
        p:SetAlpha(outside and 0.5 or 1)
        p.spot, p.outside, p.ox, p.oy = s, outside, ox, oy
        p:Show()
      end
    end
  end
  for i = used + 1, #mmPins do mmPins[i]:Hide() end
  return used, mmPins
end

local mapHooked = false
local function hookMap()
  if mapHooked or not WorldMapFrame then return end
  mapHooked = true
  local function queue() if C_Timer and C_Timer.After then C_Timer.After(0, function() QH:RefreshMap() end) else QH:RefreshMap() end end
  if WorldMapFrame.HookScript then WorldMapFrame:HookScript("OnShow", queue) end
  if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", queue) end
end

-- Events ------------------------------------------------------------------------------------------
for _, ev in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW" }) do
  pcall(FF.On, FF, ev, function() QH:SeeNpc() end)
end
-- older clients send (log index, quest ID), newer ones only the quest ID
pcall(FF.On, FF, "QUEST_ACCEPTED", function(a, b) QH:OnAccepted(b or a) end)
pcall(FF.On, FF, "QUEST_TURNED_IN", function(questID) QH:OnTurnedIn(questID) end)
pcall(FF.On, FF, "QUEST_LOG_UPDATE", function() QH:OnLogUpdate() if WorldMapFrame and WorldMapFrame:IsShown() then QH:RefreshMap() end end)
FF:On("PLAYER_LOGIN", function()
  hookMap()
  -- the minimap moves with you: refresh its quest pins twice a second
  if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(0.5, function() pcall(QH.RefreshMinimap, QH) end) end
end)

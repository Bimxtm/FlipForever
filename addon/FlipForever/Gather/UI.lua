-- FlipForever Gathering module (was the separate Ore Farmer addon).
if select(2, ...).skipGather then return end
-- Ore Farmer: the user interface.
--   * Main window (/ore, minimap button, addon menu): Overview, Resources,
--     Zones, Prices and Settings tabs.
--   * Tracker: a small always-visible panel with the next stop and live numbers.
--   * Minimap button and AddOns-menu entry.
local _, ns = ...

local main, tracker, minimapButton
local GOLD = { 0.88, 0.63, 0.25 }

---------------------------------------------------------------------------
-- Small widget helpers
---------------------------------------------------------------------------
local function skin(f, alpha)
  local edge = f:CreateTexture(nil, "BACKGROUND", nil, -2)
  edge:SetPoint("TOPLEFT", -1, 1)
  edge:SetPoint("BOTTOMRIGHT", 1, -1)
  edge:SetColorTexture(0.2, 0.8, 0.5, 0.9)   -- FlipForever green, like every other panel
  local bg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
  bg:SetAllPoints()
  bg:SetColorTexture(0.05, 0.06, 0.08, alpha or 0.96)
end

local function movable(f, saveKey)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if saveKey then
      local point, _, relPoint, x, y = self:GetPoint()
      ns.db[saveKey] = { point, relPoint, x, y }
    end
  end)
end

local function restorePos(f, saveKey, default)
  f:ClearAllPoints()
  local pos = ns.db[saveKey]
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint(unpack(default)) end
end

local function button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function closeButton(parent, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
  b:SetPoint("TOPRIGHT", 2, 2)
  b:SetSize(26, 26)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

local function checkbox(parent, text, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  cb.label:SetJustifyH("LEFT")
  if text then cb.label:SetText(text) end
  cb:SetScript("OnClick", onClick)
  return cb
end

local function text(parent, font, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  fs:SetJustifyH(justify or "LEFT")
  return fs
end

local function header(parent, label, y)
  local fs = text(parent, "GameFontNormal")
  fs:SetPoint("TOPLEFT", 4, y)
  fs:SetText(label)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
  line:SetHeight(1)
  line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
  line:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
  return fs
end

local function colorText(c, s)
  local f = function(v) return math.floor(v * 255 + 0.5) end
  return string.format("|cff%02x%02x%02x%s|r", f(c[1]), f(c[2]), f(c[3]), s)
end

-- A "- value +" stepper.
local function stepper(parent, label, get, set, step, lo, hi, fmt)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(440, 24)
  f.label = text(f)
  f.label:SetPoint("LEFT", 4, 0)
  f.label:SetText(label)
  f.value = text(f, "GameFontHighlight", "CENTER")
  f.value:SetWidth(70)
  f.value:SetPoint("RIGHT", -34, 0)
  local function update() f.value:SetText(string.format(fmt, get())) end
  f.minus = button(f, "-", 26, function() set(math.max(lo, get() - step)); update(); ns.RefreshUI() end)
  f.minus:SetPoint("RIGHT", f.value, "LEFT", -4, 0)
  f.plus = button(f, "+", 26, function() set(math.min(hi, get() + step)); update(); ns.RefreshUI() end)
  f.plus:SetPoint("RIGHT", -4, 0)
  f.Update = update
  return f
end

local function changed()
  ns.MarkDirty()
  ns.RefreshUI()
end

-- Our own yes/no box. (Blizzard's StaticPopup system must not be touched by
-- addons on this client: doing so taints it and gets actions blocked.)
local confirmFrame
local function confirm(question, onYes)
  if not confirmFrame then
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(320, 110)
    f:SetPoint("CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    skin(f)
    f.text = text(f, "GameFontHighlight", "CENTER")
    f.text:SetPoint("TOP", 0, -18)
    f.text:SetWidth(290)
    f.yes = button(f, "Yes", 100, function()
      f:Hide()
      if f.onYes then f.onYes() end
    end)
    f.yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 14)
    f.no = button(f, "No", 100, function() f:Hide() end)
    f.no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 14)
    confirmFrame = f
  end
  confirmFrame.text:SetText(question)
  confirmFrame.onYes = onYes
  confirmFrame:Show()
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local pages = {}
local PAGE_W, PAGE_H = 520, 400

-- Overview ---------------------------------------------------------------
local function buildOverview(page)
  header(page, "Where you are", -4)
  page.where = text(page, "GameFontHighlight")
  page.where:SetPoint("TOPLEFT", 8, -26)
  page.where:SetWidth(PAGE_W - 16)
  page.skills = text(page)
  page.skills:SetPoint("TOPLEFT", page.where, "BOTTOMLEFT", 0, -4)

  header(page, "This zone's loop", -74)
  page.loop = text(page)
  page.loop:SetPoint("TOPLEFT", 8, -96)
  page.loop:SetWidth(PAGE_W - 16)
  page.loop:SetSpacing(4)

  page.nextBox = CreateFrame("Frame", nil, page)
  page.nextBox:SetPoint("TOPLEFT", 4, -170)
  page.nextBox:SetSize(PAGE_W - 8, 44)
  local nb = page.nextBox:CreateTexture(nil, "BACKGROUND")
  nb:SetAllPoints()
  nb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.12)
  page.nextText = text(page.nextBox, "GameFontNormalLarge")
  page.nextText:SetPoint("LEFT", 12, 0)
  page.nextText:SetWidth(PAGE_W - 30)

  header(page, "Your earnings", -228)
  page.earn = text(page)
  page.earn:SetPoint("TOPLEFT", 8, -250)
  page.earn:SetWidth(PAGE_W - 16)
  page.earn:SetSpacing(4)

  page.bNew = button(page, "Start a new run", 130, function()
    ns.ResetSession()
    ns.Print("run counters reset.")
    ns.RefreshUI()
  end)
  page.bNew:SetPoint("BOTTOMLEFT", 4, 4)
  page.bRoute = button(page, "Route", 120, function()
    ns.db.showRoute = not ns.db.showRoute
    changed()
  end)
  page.bRoute:SetPoint("LEFT", page.bNew, "RIGHT", 6, 0)
  page.bTracker = button(page, "Tracker", 120, function() ns.SetTrackerShown(not ns.db.panelShown) end)
  page.bTracker:SetPoint("LEFT", page.bRoute, "RIGHT", 6, 0)
  -- (No "open map" button: opening Blizzard's map from addon code taints it.)
  page.mapHint = text(page)
  page.mapHint:SetPoint("LEFT", page.bTracker, "RIGHT", 10, 0)
  page.mapHint:SetText("|cff888888Press M for the map|r")

  page.Refresh = function(self)
    self.bRoute:SetText(ns.db.showRoute and "Route: on" or "Route: off")
    self.bTracker:SetText(ns.db.panelShown and "Tracker: on" or "Tracker: off")
    local skills = {}
    for _, c in ipairs(ns.CATEGORIES) do
      if c.skillLine then
        local s, src = ns.GetSkill(c.key)
        skills[#skills + 1] = string.format("%s %s%s", c.label, s and tostring(s) or "?", src == "manual" and "*" or "")
      end
    end
    self.skills:SetText("|cffaaaaaa" .. table.concat(skills, "   ·   ") .. "|r")

    local mapID = ns.PlayerPos()
    if not mapID then
      self.where:SetText("No map position here (instance or loading screen).")
      self.loop:SetText("")
      self.nextText:SetText("")
    else
      self.where:SetText(ns.MapName(mapID))
      local nodes = ns.ZoneSpots(mapID)
      local own = #(ns.db.nodes[mapID] or {})
      if #nodes == 0 then
        self.loop:SetText("No spots known in this zone yet.\nGather ore, herbs, fish or chests: every spot is added when you loot it.")
      else
        local est, r = ns.EstimateRoute(mapID)
        local fromGL = #nodes - own
        local t = { string.format("Spots known: |cffffffff%d|r%s     On the route: |cffffffff%d|r", #nodes,
          fromGL > 0 and string.format(" |cff888888(%d yours, %d from GatherLite)|r", own, fromGL) or "", #r.pts) }
        if #r.pts >= 2 then
          t[#t + 1] = string.format("Loop: |cffffffff%d yd|r, about |cffffffff%s|r per round", est.yards + 0.5, ns.FormatTime(est.seconds))
          t[#t + 1] = string.format("Estimate: |cffffd040%s|r per round,  |cffffd040%s|r per hour%s",
            ns.FormatMoney(est.value), ns.FormatMoney(est.perHour), est.guess and "  |cff888888(rough, needs more data)|r" or "")
        else
          t[#t + 1] = "Find at least 2 spots for a loop."
        end
        self.loop:SetText(table.concat(t, "\n"))
      end
      local label, dist, dir = ns.NextStopInfo()
      if ns.db.showRoute and label then
        self.nextText:SetText(string.format("Next: |cffffffff%s|r  ·  %d yd %s", label, dist + 0.5, dir))
      else
        self.nextText:SetText(ns.db.showRoute and "|cff888888No next stop yet.|r" or "|cff888888Route is off.|r")
      end
    end

    local s = ns.session
    local t = {}
    local rate = ns.SessionRate()
    t[1] = string.format("This run: |cffffffff%d|r gathered, worth |cffffd040%s|r%s", s.nodes, ns.FormatMoney(s.value),
      rate and string.format("  (|cffffd040%s/h|r)", ns.FormatMoney(rate)) or "")
    t[2] = string.format("Time spent moving and gathering: %s", ns.FormatTime(s.active + s.pending))
    if mapID then
      local zrate, z = ns.ZoneRate(mapID)
      if zrate then
        t[3] = string.format("Measured in this zone: |cffffd040%s/h|r over %s", ns.FormatMoney(zrate), ns.FormatTime(z.active))
      elseif z then
        t[3] = "|cff888888Measured rate for this zone appears after 10 minutes and 10 spots.|r"
      end
    end
    self.earn:SetText(table.concat(t, "\n"))
  end
end

-- Resources --------------------------------------------------------------
local COL_W, ROW_H, ROWS = 250, 20, 13

local function buildResources(page)
  page.cat = "mining"
  page.tabs = {}
  for i, c in ipairs(ns.CATEGORIES) do
    local tab = button(page, c.label, 124, function()
      page.cat = c.key
      page:Refresh()
    end)
    tab:SetPoint("TOPLEFT", 4 + (i - 1) * 128, -2)
    tab.cat = c.key
    page.tabs[i] = tab
  end

  page.catCheck = checkbox(page, nil, function(btn)
    ns.db.hiddenCat[page.cat] = not btn:GetChecked() or nil
    changed()
  end)
  page.catCheck:SetPoint("TOPLEFT", 4, -32)

  page.allOff = button(page, "None", 60, function()
    for _, def in ipairs(ns.ORES) do if def.cat == page.cat then ns.db.hidden[def.key] = true end end
    changed()
  end)
  page.allOff:SetPoint("TOPRIGHT", -4, -32)
  page.allOn = button(page, "All", 60, function()
    for _, def in ipairs(ns.ORES) do if def.cat == page.cat then ns.db.hidden[def.key] = nil end end
    changed()
  end)
  page.allOn:SetPoint("RIGHT", page.allOff, "LEFT", -4, 0)
  page.mineable = button(page, "Only what I can gather", 160, function()
    for _, def in ipairs(ns.ORES) do
      if def.cat == page.cat then ns.db.hidden[def.key] = (not ns.CanGather(def.key)) or nil end
    end
    changed()
  end)
  page.mineable:SetPoint("RIGHT", page.allOn, "LEFT", -4, 0)

  page.hint = text(page)
  page.hint:SetPoint("BOTTOMLEFT", 4, 4)
  page.hint:SetWidth(PAGE_W - 8)
  page.hint:SetText("|cff888888Hidden resources disappear from the maps and the route. Grey numbers = skill you still need.|r")

  page.checks = {}
  page.Refresh = function(self)
    for _, tab in ipairs(self.tabs) do
      if tab.cat == self.cat then tab:Disable() else tab:Enable() end
    end
    local catDef = ns.CategoryByKey[self.cat]
    local skill = ns.GetSkill(self.cat)
    self.catCheck:SetChecked(not ns.db.hiddenCat[self.cat])
    self.catCheck.label:SetText(string.format("Show %s%s", catDef.label,
      skill and string.format("  |cff888888(your skill: %d)|r", skill) or ""))

    local list = {}
    for _, def in ipairs(ns.ORES) do
      if def.cat == self.cat then list[#list + 1] = def end
    end
    local perCol = math.max(ROWS, math.ceil(#list / 2))
    local known = {}
    for _, nodes in pairs(ns.db.nodes) do
      for _, node in ipairs(nodes) do
        for k in pairs(node.t) do known[k] = (known[k] or 0) + 1 end
      end
    end
    for i, def in ipairs(list) do
      local cb = self.checks[i]
      if not cb then
        cb = checkbox(self, nil, function(btn)
          ns.db.hidden[btn.key] = not btn:GetChecked() or nil
          changed()
        end)
        cb.label:SetWidth(COL_W - 30)
        cb.label:SetWordWrap(false)
        self.checks[i] = cb
      end
      local col, row = math.floor((i - 1) / perCol), (i - 1) % perCol
      cb.key = def.key
      cb:ClearAllPoints()
      cb:SetPoint("TOPLEFT", 4 + col * COL_W, -62 - row * ROW_H)
      cb:SetChecked(not ns.db.hidden[def.key])
      local note = ns.CanGather(def.key) and "" or string.format(" |cff888888(%d)|r", def.skill)
      local n = known[def.key] or 0
      cb.label:SetText(colorText(def.color, def.label) .. note .. (n > 0 and string.format(" |cffaaaaaa· %d|r", n) or ""))
      cb:Show()
    end
    for i = #list + 1, #self.checks do self.checks[i]:Hide() end
  end
end

-- Zones -------------------------------------------------------------------
local ZONE_ROWS = 15

local function buildZones(page)
  header(page, "All zones with spots (best first)", -4)
  local cols = { { "Zone", 8, 190 }, { "Spots", 200, 50 }, { "Loop", 255, 70 }, { "Estimate/h", 330, 90 }, { "Measured/h", 425, 90 } }
  for _, c in ipairs(cols) do
    local fs = text(page, "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", c[2], -28)
    fs:SetWidth(c[3])
    fs:SetText(c[1])
  end
  page.rows = {}
  for i = 1, ZONE_ROWS do
    local row = {}
    for j, c in ipairs(cols) do
      local fs = text(page)
      fs:SetPoint("TOPLEFT", c[2], -46 - (i - 1) * 20)
      fs:SetWidth(c[3])
      fs:SetWordWrap(false)
      row[j] = fs
    end
    if i % 2 == 0 then
      local band = page:CreateTexture(nil, "BACKGROUND")
      band:SetColorTexture(1, 1, 1, 0.03)
      band:SetPoint("TOPLEFT", 4, -43 - (i - 1) * 20)
      band:SetSize(PAGE_W - 8, 20)
    end
    page.rows[i] = row
  end
  page.empty = text(page)
  page.empty:SetPoint("TOPLEFT", 8, -50)
  page.empty:SetText("No spots recorded anywhere yet.")

  page.Refresh = function(self)
    local list = {}
    for mapID, nodes in pairs(ns.db.nodes) do
      if #nodes > 0 then
        local est = ns.EstimateRoute(mapID)
        local zrate = ns.ZoneRate(mapID)
        list[#list + 1] = { name = ns.MapName(mapID), spots = #nodes, est = est, measured = zrate }
      end
    end
    table.sort(list, function(a, b) return (a.measured or a.est.perHour) > (b.measured or b.est.perHour) end)
    self.empty:SetShown(#list == 0)
    for i = 1, ZONE_ROWS do
      local row, z = self.rows[i], list[i]
      if z then
        row[1]:SetText(z.name)
        row[2]:SetText(tostring(z.spots))
        row[3]:SetText(z.est.nodes >= 2 and ns.FormatTime(z.est.seconds) or "-")
        row[4]:SetText(z.est.nodes >= 2 and (ns.FormatMoney(z.est.perHour) .. (z.est.guess and "|cff888888*|r" or "")) or "-")
        row[5]:SetText(z.measured and ns.FormatMoney(z.measured) or "|cff888888-|r")
      else
        for j = 1, #row do row[j]:SetText("") end
      end
    end
  end
end

-- Prices --------------------------------------------------------------------
local function priceText(id)
  local p, src = ns.PriceOf(id)
  if not src then return "|cff888888?|r" end
  if src == "vendor" then return "|cff888888" .. ns.FormatMoney(p) .. " (vendor)|r" end
  if src == "manual" then return ns.FormatMoney(p) .. " |cff888888(yours)|r" end
  return ns.FormatMoney(p)
end

local function buildPrices(page)
  page.source = text(page)
  page.source:SetPoint("TOPLEFT", 4, -4)
  page.source:SetWidth(PAGE_W - 8)

  header(page, "Ore  →  bar", -26)
  page.left = text(page)
  page.left:SetPoint("TOPLEFT", 8, -48)
  page.left:SetWidth(255)
  page.left:SetSpacing(3)

  page.herbHeader = text(page, "GameFontNormal")
  page.herbHeader:SetPoint("TOPLEFT", 275, -48)
  page.herbHeader:SetText("Herbs you gather")
  page.right = text(page)
  page.right:SetPoint("TOPLEFT", 275, -68)
  page.right:SetWidth(240)
  page.right:SetSpacing(3)

  page.hint = text(page)
  page.hint:SetPoint("BOTTOMLEFT", 4, 4)
  page.hint:SetWidth(PAGE_W - 8)
  page.hint:SetText("|cff888888Set your own price: /ore price <item link or ID> <gold>   (0 clears it)|r")

  page.Refresh = function(self)
    local src = ns.PriceSourceName()
    self.source:SetText(src and ("Prices come from |cffffffff" .. src .. "|r.")
      or "|cffff8040No price scan yet: vendor prices are used until you scan at the auction house.|r")
    local out, done = {}, {}
    for _, def in ipairs(ns.ORES) do
      if def.cat == "mining" and def.ore and not done[def.ore] and not def.custom then
        done[def.ore] = true
        local line = colorText(def.color, def.label) .. "  " .. priceText(def.ore)
        if def.bar then
          line = line .. "  →  " .. priceText(def.bar)
          local po, so = ns.PriceOf(def.ore)
          local pb, sb = ns.PriceOf(def.bar)
          if so and so ~= "vendor" and sb and sb ~= "vendor" then
            line = line .. (pb > po and "  |cff40ff40smelt|r" or "  |cffffd040sell ore|r")
          end
        end
        out[#out + 1] = line
      end
    end
    self.left:SetText(table.concat(out, "\n"))
    local herbs = {}
    for _, def in ipairs(ns.ORES) do
      if def.cat == "herbalism" and def.ore and ns.CanGather(def.key) and ns.IsEnabled(def.key) then
        herbs[#herbs + 1] = colorText(def.color, def.label) .. "  " .. priceText(def.ore)
        if #herbs >= 16 then break end
      end
    end
    self.right:SetText(#herbs > 0 and table.concat(herbs, "\n") or "|cff888888None shown.|r")
  end
end

-- Settings ----------------------------------------------------------------
local function buildSettings(page)
  header(page, "Show", -4)
  page.checks = {}
  local opts = {
    { "showMap", "Spots on the world map" },
    { "showMinimap", "Spots on the minimap" },
    { "showRoute", "Route line and next stop" },
    { "panelShown", "Small tracker window", function(v) ns.SetTrackerShown(v) end },
    { "minimapButton", "Minimap button", function(v) ns.SetMinimapButtonShown(v) end },
    { "debug", "Explain in chat what gets recorded" },
    { "useGatherLite", "Use GatherLite's spots", function(v) ns.db.useGatherLite = v; ns.ResetGatherLiteCache() end },
    { "pinsWithGatherLite", "Also draw spots myself" },
  }
  for i, o in ipairs(opts) do
    local cb = checkbox(page, o[2], function(btn)
      local v = btn:GetChecked() and true or false
      if o[3] then o[3](v) else ns.db[o[1]] = v end
      changed()
    end)
    cb:SetPoint("TOPLEFT", 4 + ((i - 1) % 2) * 255, -24 - math.floor((i - 1) / 2) * 24)
    cb.setting = o[1]
    page.checks[i] = cb
  end

  header(page, "Estimates", -128)
  page.avail = stepper(page, "Spots that have something when you arrive",
    function() return math.floor(ns.db.availability * 100 + 0.5) end,
    function(v) ns.db.availability = v / 100 end, 10, 10, 100, "%d%%")
  page.avail:SetPoint("TOPLEFT", 0, -146)
  page.perNode = stepper(page, "Seconds per spot (dismount, gather, loot)",
    function() return ns.db.secondsPerNode end,
    function(v) ns.db.secondsPerNode = v end, 1, 2, 20, "%d s")
  page.perNode:SetPoint("TOPLEFT", 0, -170)
  page.speed = text(page)
  page.speed:SetPoint("TOPLEFT", 8, -198)

  header(page, "Skills", -216)
  page.skills = text(page)
  page.skills:SetPoint("TOPLEFT", 8, -236)
  page.skills:SetWidth(PAGE_W - 16)
  page.skills:SetSpacing(2)

  header(page, "Data", -300)
  page.bZone = button(page, "Forget this zone", 140, function()
    local mapID = ns.PlayerPos()
    if not mapID then return end
    confirm("Forget all Ore Farmer spots in " .. ns.MapName(mapID) .. "?", function()
      ns.db.nodes[mapID] = nil
      ns.db.zoneStats[mapID] = nil
      ns.MarkDirty(mapID)
      ns.RefreshUI()
    end)
  end)
  page.bZone:SetPoint("TOPLEFT", 4, -322)
  page.bAll = button(page, "Forget everything", 140, function()
    confirm("Forget ALL Ore Farmer spots, loot history and your own prices?", function()
      ns.db.nodes, ns.db.yield, ns.db.prices, ns.db.zoneStats = {}, {}, {}, {}
      ns.ResetSession()
      ns.MarkDirty()
      ns.RefreshUI()
    end)
  end)
  page.bAll:SetPoint("LEFT", page.bZone, "RIGHT", 6, 0)
  page.bCheck = button(page, "Troubleshooting info", 160, function() SlashCmdList.OREFARMER("check") end)
  page.bCheck:SetPoint("LEFT", page.bAll, "RIGHT", 6, 0)

  page.Refresh = function(self)
    for _, cb in ipairs(self.checks) do cb:SetChecked(ns.db[cb.setting] and true or false) end
    self.avail:Update()
    self.perNode:Update()
    self.speed:SetText(string.format("|cffaaaaaaTravel speed learned from you: %.1f yards/second|r", ns.db.speed or 7))
    local t = {}
    for _, c in ipairs(ns.CATEGORIES) do
      if c.skillLine then
        local s, src = ns.GetSkill(c.key)
        t[#t + 1] = string.format("%s: |cffffffff%s|r %s", c.label, s and tostring(s) or (src == "none" and "-" or "?"),
          src == "manual" and "|cff888888(set by you)|r" or (src == "none" and "|cff888888(not learned: hidden from the route)|r")
          or (src and "|cff888888(detected)|r" or "|cff888888(not found)|r"))
      end
    end
    t[#t + 1] = "|cff888888Wrong or missing? /ore skill 150,  /ore skill herbalism 120,  /ore skill auto|r"
    self.skills:SetText(table.concat(t, "\n"))
  end
end

---------------------------------------------------------------------------
-- Main window
---------------------------------------------------------------------------
local TABS = {
  { key = "overview", label = "Overview", build = buildOverview },
  { key = "resources", label = "Resources", build = buildResources },
  { key = "zones", label = "Zones", build = buildZones },
  { key = "prices", label = "Prices", build = buildPrices },
  { key = "settings", label = "Settings", build = buildSettings },
}

local function selectPage(key)
  main.current = key
  for _, t in ipairs(TABS) do
    local shown = t.key == key
    pages[t.key]:SetShown(shown)
    if shown then main.tabButtons[t.key]:Disable() else main.tabButtons[t.key]:Enable() end
  end
  ns.RefreshUI()
end

local function buildMain()
  main = CreateFrame("Frame", "OreFarmerMain", UIParent)
  main:SetSize(PAGE_W + 24, PAGE_H + 80)
  main:SetFrameStrata("HIGH")
  main:SetToplevel(true)
  skin(main)
  movable(main, "mainPos")
  restorePos(main, "mainPos", { "CENTER", UIParent, "CENTER", 0, 40 })
  closeButton(main)
  -- Escape closes the window. Done with our own key handler instead of
  -- Blizzard's UISpecialFrames list, which the game menu reads (taint).
  -- Outside combat only; every other key passes through to the game.
  main:EnableKeyboard(true)
  main:SetPropagateKeyboardInput(true)
  main:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then return end
    if key == "ESCAPE" then
      self:SetPropagateKeyboardInput(false)
      self:Hide()
    else
      self:SetPropagateKeyboardInput(true)
    end
  end)
  main:SetScript("OnHide", function(self)
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
  end)

  local icon = main:CreateTexture(nil, "ARTWORK")
  icon:SetSize(22, 22)
  icon:SetPoint("TOPLEFT", 10, -8)
  icon:SetTexture("Interface\\Icons\\INV_Ore_Copper_01")
  local title = text(main, "GameFontNormalLarge")
  title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  title:SetText("|cff33ff99Flip|rForever  Gathering")
  local sub = text(main)
  sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
  sub:SetText("|cff888888mining · herbs · fishing · treasure|r")

  main.tabButtons = {}
  for i, t in ipairs(TABS) do
    local b = button(main, t.label, 100, function() selectPage(t.key) end)
    b:SetPoint("TOPLEFT", 12 + (i - 1) * 104, -38)
    main.tabButtons[t.key] = b

    local page = CreateFrame("Frame", nil, main)
    page:SetSize(PAGE_W, PAGE_H)
    page:SetPoint("TOPLEFT", 12, -68)
    t.build(page)
    page:Hide()
    pages[t.key] = page
  end

  local acc = 0
  main:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 1 then return end
    acc = 0
    ns.RefreshUI()
  end)
  main:SetScript("OnShow", function() ns.RefreshUI() end)
  main:Hide()
  selectPage("overview")
end

function ns.ToggleMain(page)
  if not main then return end
  if page then
    selectPage(page)
    main:Show()
  elseif main:IsShown() then
    main:Hide()
  else
    main:Show()
  end
end

---------------------------------------------------------------------------
-- Tracker (small panel)
---------------------------------------------------------------------------
local TRACK_LINES = 5

local function buildTracker()
  tracker = CreateFrame("Frame", "OreFarmerPanel", UIParent)
  tracker:SetSize(250, 30 + TRACK_LINES * 14 + 10)
  tracker:SetFrameStrata("MEDIUM")
  restorePos(tracker, "panelPos", { "TOPRIGHT", UIParent, "TOPRIGHT", -200, -220 })
  skin(tracker, 0.85)
  movable(tracker, "panelPos")
  closeButton(tracker, function() ns.SetTrackerShown(false) end)

  local title = text(tracker, "GameFontNormal")
  title:SetPoint("TOPLEFT", 8, -7)
  title:SetText("|cff33ff99Gathering|r")
  local menu = button(tracker, "Menu", 50, function() ns.ToggleMain() end)
  menu:SetHeight(18)
  menu:SetPoint("TOPRIGHT", -26, -4)

  tracker.lines = {}
  for i = 1, TRACK_LINES do
    local fs = text(tracker)
    fs:SetPoint("TOPLEFT", 8, -26 - (i - 1) * 14)
    fs:SetWidth(234)
    fs:SetWordWrap(false)
    tracker.lines[i] = fs
  end

  local acc = 0
  tracker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 1 then return end
    acc = 0
    ns.Safe("tracker", ns.RefreshTracker)
  end)
  tracker:SetShown(ns.db.panelShown)
end

function ns.RefreshTracker()
  if not tracker or not tracker:IsShown() then return end
  local t = {}
  local mapID = ns.PlayerPos()
  if not mapID then
    t[1] = "|cff888888No map position here.|r"
  else
    t[1] = ns.MapName(mapID)
    local nodes = ns.ZoneSpots(mapID)
    if #nodes == 0 then
      t[2] = "|cff888888No spots here yet. Gather something!|r"
    else
      local est, r = ns.EstimateRoute(mapID)
      t[2] = string.format("%d spots  ·  loop %s", #nodes, #r.pts >= 2 and ns.FormatTime(est.seconds) or "-")
      if #r.pts >= 2 then
        t[3] = string.format("Est. |cffffd040%s/h|r%s", ns.FormatMoney(est.perHour), est.guess and " |cff888888(rough)|r" or "")
      end
    end
    if ns.db.showRoute then
      local label, dist, dir = ns.NextStopInfo()
      if label then t[4] = string.format("|cffffd040Next:|r %s  %d yd %s", label, dist + 0.5, dir) end
    end
  end
  local s, rate = ns.session, ns.SessionRate()
  if s.nodes > 0 then
    t[5] = string.format("Run: %d  ·  %s%s", s.nodes, ns.FormatMoney(s.value), rate and ("  ·  " .. ns.FormatMoney(rate) .. "/h") or "")
  end
  for i = 1, TRACK_LINES do tracker.lines[i]:SetText(t[i] or "") end
end

function ns.SetTrackerShown(show)
  ns.db.panelShown = show and true or false
  if tracker then
    tracker:SetShown(ns.db.panelShown)
    if show then ns.Safe("tracker", ns.RefreshTracker) end
  end
  ns.RefreshUI()
end
ns.SetPanelShown = ns.SetTrackerShown

---------------------------------------------------------------------------
-- Minimap button and AddOns menu entry
---------------------------------------------------------------------------
local function placeMinimapButton()
  local angle = math.rad(ns.db.minimapAngle or 200)
  local r = Minimap:GetWidth() / 2 + 8
  local x, y = math.cos(angle) * r, math.sin(angle) * r
  if GetMinimapShape and GetMinimapShape() == "SQUARE" then
    local m = math.max(math.abs(math.cos(angle)), math.abs(math.sin(angle)))
    x, y = x / m, y / m
  end
  minimapButton:ClearAllPoints()
  minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function buildMinimapButton()
  local b = CreateFrame("Button", "OreFarmerMinimapButton", Minimap)
  minimapButton = b
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture("Interface\\Icons\\INV_Ore_Copper_01")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  b:SetScript("OnClick", function(_, which)
    if which == "RightButton" then ns.SetTrackerShown(not ns.db.panelShown) else ns.ToggleMain() end
  end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      ns.db.minimapAngle = math.deg((math.atan2 or math.atan)(cy / s - my, cx / s - mx))
      placeMinimapButton()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff33ff99Flip|rForever Gathering")
    GameTooltip:AddLine("Left-click: open the window", 1, 1, 1)
    GameTooltip:AddLine("Right-click: show/hide the tracker", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  placeMinimapButton()
  b:SetShown(ns.db.minimapButton ~= false)
end

function ns.SetMinimapButtonShown(show)
  ns.db.minimapButton = show and true or false
  if minimapButton then minimapButton:SetShown(show) end
end

local function registerAddonMenu()
  -- FlipForever has one AddOns-menu entry for everything (its window links to Gathering)
  if FlipForever and FlipForever.Hub then return end
  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
      text = "FlipForever: Gathering",
      icon = "Interface\\Icons\\INV_Ore_Copper_01",
      notCheckable = true,
      func = function() ns.ToggleMain() end,
    })
  end
end

---------------------------------------------------------------------------
function ns.InitUI()
  if ns.db.minimapButton == nil then ns.db.minimapButton = true end
  buildMain()
  buildTracker()
  ns.Safe("minimap button", buildMinimapButton)
  ns.Safe("addon menu", registerAddonMenu)
  ns.RefreshUI()
end

function ns.RefreshUI()
  ns.Safe("tracker", ns.RefreshTracker)
  if main and main:IsShown() and main.current and pages[main.current] then
    ns.Safe(main.current .. " page", pages[main.current].Refresh, pages[main.current])
  end
end

---------------------------------------------------------------------------
-- /ore
---------------------------------------------------------------------------
local HELP = {
  "/ore  -  open or close the Ore Farmer window",
  "/ore tracker  -  show or hide the small tracker",
  "/ore skill 150  -  set your mining skill (/ore skill herbalism 120, /ore skill auto)",
  "/ore price 2772 0.45  -  your own price in gold for an item (link or ID; 0 clears)",
  "/ore debug  -  explain in chat what gets recorded (on/off)",
  "/ore check  -  troubleshooting info",
}

local CAT_ALIASES = { mining = "mining", mine = "mining", herbalism = "herbalism", herb = "herbalism",
                      herbs = "herbalism", fishing = "fishing", fish = "fishing" }

SLASH_OREFARMER1 = "/ore"
SLASH_OREFARMER2 = "/orefarmer"
SlashCmdList.OREFARMER = function(msg)
  if not ns.db then
    ns.Print("not available in this game client.")
    return
  end
  local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  if cmd == "" then
    ns.ToggleMain()
  elseif cmd == "tracker" then
    ns.SetTrackerShown(not ns.db.panelShown)
  elseif cmd == "show" or cmd == "options" or cmd == "resources" then
    ns.ToggleMain("resources")
  elseif cmd == "zones" or cmd == "prices" or cmd == "settings" then
    ns.ToggleMain(cmd)
  elseif cmd == "skill" then
    local catWord, num = arg:match("^(%a+)%s*(%S*)$")
    local cat = CAT_ALIASES[catWord or ""] or "mining"
    if not catWord then num = arg end
    if num == "auto" or arg == "auto" then
      ns.db.skills[cat] = nil
      ns.Print(ns.CategoryByKey[cat].label .. " skill: detected automatically.")
    elseif tonumber(num) then
      ns.db.skills[cat] = tonumber(num)
      ns.Print(string.format("%s skill set to %d.", ns.CategoryByKey[cat].label, ns.db.skills[cat]))
    else
      ns.Print("usage: /ore skill 150,  /ore skill herbalism 120,  or  /ore skill auto")
    end
    ns.MarkDirty()
  elseif cmd == "avail" and tonumber(arg) then
    ns.db.availability = math.max(0.05, math.min(1, tonumber(arg) / 100))
    ns.Print(string.format("expecting %d%% of spots to have something.", ns.db.availability * 100 + 0.5))
  elseif cmd == "price" then
    ns.SetManualPrice(arg)
  elseif cmd == "debug" then
    ns.db.debug = not ns.db.debug
    ns.Print("explaining recordings in chat: " .. (ns.db.debug and "on" or "off"))
  elseif cmd == "check" then
    local function has(path)
      local v = _G
      for part in path:gmatch("[^%.]+") do
        v = type(v) == "table" and v[part] or nil
      end
      return v ~= nil and "|cff40ff40yes|r" or "|cffff4040no|r"
    end
    for _, p in ipairs({ "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_Map.GetMapRectOnMap",
      "C_Map.GetMapWorldSize", "C_Map.GetWorldPosFromMapPos", "C_Minimap.GetViewRadius", "GetProfessions",
      "Auctionator.API.v1", "AucAdvanced.API", "TSM_API.GetCustomPriceValue", "issecretvalue" }) do
      ns.Print(p .. ": " .. has(p))
    end
    local mapID, x, y = ns.PlayerPos()
    if mapID then
      local w, h, guessed = ns.MapSize(mapID)
      ns.Print(string.format("map %d (%s) at %.3f, %.3f; size %d x %d yd%s", mapID, ns.MapName(mapID), x, y, w, h,
        guessed and " (guessed)" or ""))
    else
      ns.Print("no map position right now.")
    end
    local shown = WorldMapFrame and ns.Plain(WorldMapFrame:GetMapID())
    if shown and mapID then
      ns.Print(string.format("world map shows map %d; your zone %s on it.", shown,
        ns.RectOnMap(mapID, shown) and "fits" or "does NOT fit"))
    end
    for _, c in ipairs(ns.CATEGORIES) do
      if c.skillLine then
        local s, src = ns.GetSkill(c.key)
        ns.Print(c.label .. " skill: " .. tostring(s) .. " (" .. tostring(src or "not found") .. ")")
      end
    end
    local total = 0
    for _, list in pairs(ns.db.nodes) do total = total + #list end
    ns.Print("spots saved: " .. total)
  else
    for _, l in ipairs(HELP) do ns.Print(l) end
  end
  ns.RefreshUI()
end

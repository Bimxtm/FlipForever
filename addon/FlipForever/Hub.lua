-- FlipForever: the main window. Everything the addon can do is reachable from here with the
-- mouse - no slash commands needed. Opened by the gold-coin minimap button, the AddOns menu,
-- the Settings buttons on the auction house panel and in the Advisor, or /ff.
local FF = FlipForever
local H = {}
FF.Hub = H

local frame, mmButton, capture

-- Small widget helpers ---------------------------------------------------------------------------
local function button(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(FF:T(text))
  b:SetScript("OnClick", onClick)
  return b
end

local function check(parent, label, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
  c.text:SetJustifyH("LEFT")
  if c.text.SetWordWrap then c.text:SetWordWrap(false) end
  c.text:SetWidth(310)
  c.text:SetText(FF:T(label))
  c:SetScript("OnClick", onClick)
  return c
end

local function heading(parent, label, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", 16, y)
  fs:SetText(FF:T(label))
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.2, 0.8, 0.5, 0.35)
  line:SetHeight(1)
  line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
  line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
  return fs
end

-- Key capture: "press the key you want" ------------------------------------------------------------
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true }

local function startCapture(label, onKey)
  if InCombatLockdown() then FF:Print(FF:T("Can't change keys during a fight.")) return end
  if not capture then
    capture = CreateFrame("Frame", "FlipForeverKeyCapture", UIParent, "BackdropTemplate")
    capture:SetSize(320, 90)
    capture:SetPoint("CENTER", 0, 120)
    capture:SetFrameStrata("DIALOG")
    capture:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    capture:SetBackdropColor(0.05, 0.06, 0.08, 0.97)
    capture:SetBackdropBorderColor(1, 0.82, 0, 1)
    capture.text = capture:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    capture.text:SetPoint("CENTER")
    capture.text:SetWidth(290)
    capture:EnableKeyboard(true)
    capture:SetScript("OnKeyDown", function(self, key)
      if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
      if MODIFIERS[key] then return end
      self:Hide()
      if key == "ESCAPE" then return end
      local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
      if self.onKey then self.onKey(combo) end
    end)
    -- gamepad buttons work too (switch: controller); Back cancels
    capture:SetScript("OnGamePadButtonDown", function(self, button)
      self:Hide()
      if button == "PADBACK" then return end
      local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. button
      if self.onKey then self.onKey(combo) end
    end)
    -- mouse buttons 4/5 work too
    capture:SetScript("OnMouseDown", function(self, mouse)
      if mouse == "Button4" or mouse == "Button5" then
        self:Hide()
        if self.onKey then self.onKey(mouse:upper()) end
      end
    end)
  end
  capture.onKey = onKey
  if capture.EnableGamePadButton then pcall(capture.EnableGamePadButton, capture, FF:Controller()) end
  capture.text:SetText(FF:T("Press the key you want for\n|cffffd200") .. label .. "|r\n\n|cff888888(Escape cancels)|r")
  capture:Show()
end

-- Pages ------------------------------------------------------------------------------------------
local TABS = { { "overview", "Overview" }, { "list", "Shopping list" }, { "gear", "Gear" }, { "settings", "Settings" } }
local LIST_ROWS = 18

local function text(parent, font, x, y, w)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x, y)
  if w then fs:SetWidth(w) end
  fs:SetJustifyH("LEFT")
  return fs
end

-- Overview: where you stand at a glance, and the things you open most
local function buildOverview(f)
  local pg = CreateFrame("Frame", nil, f)
  pg:SetAllPoints(f)
  heading(pg, "Auction house", -64)
  pg.plan = text(pg, "GameFontHighlight", 20, -86, 360)
  pg.today = text(pg, "GameFontHighlightSmall", 20, -134, 360)
  pg.week = text(pg, "GameFontHighlightSmall", 20, -148, 360)
  pg.own = text(pg, "GameFontHighlightSmall", 20, -162, 360)
  pg.auto = text(pg, "GameFontHighlightSmall", 20, -176, 360)
  button(pg, "See the shopping list", 178, function() H:SelectTab("list") end):SetPoint("TOPLEFT", 16, -196)
  pg.reload = button(pg, "Reload UI (sync)", 178, function() FF:ReloadForSync() end)
  pg.reload:SetPoint("TOPLEFT", 206, -196)
  heading(pg, "Next step (Advisor)", -226)
  pg.advice = text(pg, "GameFontHighlight", 20, -248, 360)
  -- click the next step to open the Advisor with all steps
  pg.adviceClick = CreateFrame("Button", nil, pg)
  pg.adviceClick:SetPoint("TOPLEFT", 16, -244)
  pg.adviceClick:SetSize(368, 76)
  pg.adviceClick:SetScript("OnClick", function() FF.Advisor:Show() end)
  pg.adviceClick:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(FF:T("Click to open the Advisor with all your next steps."))
    GameTooltip:Show()
  end)
  pg.adviceClick:SetScript("OnLeave", function() GameTooltip:Hide() end)
  heading(pg, "Open", -330)
  button(pg, "Advisor", 86, function() FF.Advisor:Show() end):SetPoint("TOPLEFT", 16, -352)
  f.gather = button(pg, "Gathering", 86, function()
    local ns = FF.gatherNS
    if ns and not ns.db and not ns.skipGather and ns.Start then ns.Start() end
    if ns and ns.ToggleMain and not ns.skipGather and ns.db then ns.ToggleMain()
    else FF:Print(FF:GatherOffReason() or FF:T("Gathering didn't load.")) end
  end)
  f.gather:SetPoint("TOPLEFT", 106, -352)
  f.profs = button(pg, "Professions", 86, function() FF.Professions:Toggle() end)
  f.profs:SetPoint("TOPLEFT", 196, -352)
  f.talents = button(pg, "Talents", 86, function() FF.Advisor:OpenTalents() end)
  f.talents:SetPoint("TOPLEFT", 286, -352)
  pg.combat = check(pg, "Combat helper on screen", function() FF.Combat:Toggle() end)
  pg.combat:SetPoint("TOPLEFT", 14, -384)
  pg.autopilot = check(pg, "Autopilot at the auction house", function() FF.Auto:SetEnabled(not FF.Auto:Enabled()) end)
  pg.autopilot:SetPoint("TOPLEFT", 14, -408)
  if not FF.Auto.AVAILABLE then pg.autopilot:Hide() end
  -- leveling: XP per hour, time to the next level, rested XP (Settings: Features)
  pg.level = text(pg, "GameFontHighlightSmall", 20, -440, 360)
  -- bag value: merchant and auction value of your bags; hover for what's worth posting
  pg.bags = text(pg, "GameFontHighlightSmall", 20, -458, 360)
  -- profession cooldowns of every character on this realm (Settings: Features)
  pg.cooldowns = text(pg, "GameFontHighlightSmall", 20, -476, 360)
  pg.bagsHover = CreateFrame("Button", nil, pg)
  pg.bagsHover:SetPoint("TOPLEFT", 16, -454)
  pg.bagsHover:SetSize(368, 18)
  pg.bagsHover:SetScript("OnEnter", function(self)
    if not (FF.BagValue and FF.BagValue:Enabled()) then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    FF.BagValue:Tooltip(GameTooltip)
    GameTooltip:Show()
  end)
  pg.bagsHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return pg
end

-- Shopping list: every item with its price now, your max, what you bought, and a Skip box
local function buildList(f)
  local pg = CreateFrame("Frame", nil, f)
  pg:SetAllPoints(f)
  pg.summary = text(pg, "GameFontNormal", 16, -64, 368)
  local cols = { { "Item", 20 }, { "Now", 140 }, { "Max", 196 }, { "Profit", 252 }, { "Got", 306 }, { "Skip", 344 } }
  for _, c in ipairs(cols) do text(pg, "GameFontDisableSmall", c[2], -86):SetText(FF:T(c[1])) end
  pg.rows = {}
  for i = 1, LIST_ROWS do
    local y = -102 - (i - 1) * 22
    local r = {}
    r.name = text(pg, "GameFontHighlightSmall", 20, y - 5, 118)
    r.now = text(pg, "GameFontHighlightSmall", 140, y - 5, 54)
    r.max = text(pg, "GameFontHighlightSmall", 196, y - 5, 54)
    r.profit = text(pg, "GameFontHighlightSmall", 252, y - 5, 52)
    r.got = text(pg, "GameFontHighlightSmall", 306, y - 5, 36)
    r.skip = check(pg, "", function(self) H:SetSkipped(r.id, self:GetChecked()) end)
    r.skip:SetPoint("TOPLEFT", 342, y)
    pg.rows[i] = r
  end
  pg.offset = 0
  pg:EnableMouseWheel(true)
  pg:SetScript("OnMouseWheel", function(self, delta)
    self.offset = math.max(0, self.offset - delta * 3)
    H:RefreshList()
  end)
  pg.hint = text(pg, "GameFontDisableSmall", 16, -506, 368)
  pg.hint:SetText(FF:T("Scroll with the mouse wheel. Skipped items are never bought on this character, on this list or later ones, until you untick them. Green 'Now' = cheaper than your max in the last scan."))
  return pg
end

-- Gear: affordable auction house upgrades for this character (GearFinder.lua)
local GEAR_ROWS = 14
local function buildGear(f)
  local pg = CreateFrame("Frame", nil, f)
  pg:SetAllPoints(f)
  pg.summary = text(pg, "GameFontNormal", 16, -64, 260)
  pg.search = button(pg, "Search my scan", 110, function()
    if FF.Gear.running then return end
    pg.summary:SetText(FF:T("Searching your latest scan..."))
    FF.Gear:Search()
  end)
  pg.search:SetPoint("TOPRIGHT", -16, -60)
  local cols = { { "Slot", 20 }, { "Item", 86 }, { "Price", 236 }, { "Better", 296 } }
  for _, c in ipairs(cols) do text(pg, "GameFontDisableSmall", c[2], -90):SetText(FF:T(c[1])) end
  pg.rows = {}
  for i = 1, GEAR_ROWS do
    local y = -106 - (i - 1) * 24
    local r = {}
    r.slot = text(pg, "GameFontHighlightSmall", 20, y - 5, 64)
    r.name = text(pg, "GameFontHighlightSmall", 86, y - 5, 148)
    -- one line per item: long names end in "..." instead of running into the next row;
    -- hover the name for the full item with all its stats
    if r.name.SetWordWrap then r.name:SetWordWrap(false) end
    if r.name.SetMaxLines then r.name:SetMaxLines(1) end
    r.hover = CreateFrame("Button", nil, pg)
    r.hover:SetPoint("TOPLEFT", 84, y)
    r.hover:SetSize(150, 20)
    r.hover:SetScript("OnEnter", function(self)
      local d = r.data
      if not (d and d.link) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(d.link)
      if d.pct then GameTooltip:AddLine(FF:T("Better than what you wear by %d%%"):format(math.floor(d.pct * 100 + 0.5)), 0.2, 1, 0.6) end
      if FlipForeverDB.settings.gearStats ~= false and FF.Gear.StatDiffText then
        local ok, diff = pcall(FF.Gear.StatDiffText, FF.Gear, d, 8)
        if ok and diff ~= "" then GameTooltip:AddLine(FF:T("Compared with what you wear:") .. " " .. diff, 1, 1, 1, true) end
      end
      GameTooltip:Show()
      -- what you wear in that slot, side by side (the game's own compare tooltips)
      if GameTooltip_ShowCompareItem then
        pcall(GameTooltip_ShowCompareItem, GameTooltip)
      elseif ShoppingTooltip1 and d.slot and GetInventoryItemLink then
        local worn = GetInventoryItemLink("player", d.slot)
        if worn then
          ShoppingTooltip1:SetOwner(GameTooltip, "ANCHOR_NONE")
          ShoppingTooltip1:ClearAllPoints()
          ShoppingTooltip1:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 4, 0)
          ShoppingTooltip1:SetHyperlink(worn)
          ShoppingTooltip1:Show()
        end
      end
    end)
    r.hover:SetScript("OnLeave", function()
      GameTooltip:Hide()
      if ShoppingTooltip1 then ShoppingTooltip1:Hide() end
      if ShoppingTooltip2 then ShoppingTooltip2:Hide() end
    end)
    r.price = text(pg, "GameFontHighlightSmall", 236, y - 5, 58)
    r.gain = text(pg, "GameFontHighlightSmall", 296, y - 5, 40)
    r.buy = button(pg, "Buy", 44, function() FF.Gear:Buy(r.data) end)
    r.buy:SetPoint("TOPLEFT", 340, y)
    pg.rows[i] = r
  end
  pg.hint = text(pg, "GameFontDisableSmall", 16, -452, 368)
  pg.hint:SetText(FF:T("Upgrades over what you're wearing, scored with your class's stat weights. Only gear you can use at your level, at most a quarter of your gold. Random-stat items (\"of the Bear\") are scored version by version. Buy works at the auction house, one key press per purchase."))
  return pg
end

local QUALITY = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee" }

function H:RefreshGear()
  local pg = frame and frame.pages and frame.pages.gear
  if not (pg and pg:IsShown()) then return end
  local G = FF.Gear
  local list = G.results or {}
  if G.running then
    pg.summary:SetText(FF:T("Searching your latest scan..."))
  elseif G.searched then
    pg.summary:SetText(#list > 0 and FF:T("%d upgrade%s you can afford (budget %s)"):format(#list, FF:Plural(#list), FF:Money(G:Budget()))
      or "No affordable upgrades in your latest scan.")
  else
    pg.summary:SetText(FF:T("Find upgrades for your character in your latest scan."))
  end
  for i, w in ipairs(pg.rows) do
    local r = list[i]
    w.data = r
    w.slot:SetShown(r ~= nil); w.name:SetShown(r ~= nil); w.price:SetShown(r ~= nil); w.gain:SetShown(r ~= nil); w.buy:SetShown(r ~= nil)
    if r then
      w.slot:SetText(G.SLOT_NAMES[r.slot] or "")
      w.name:SetText((QUALITY[r.quality] or "|cffffffff") .. r.name .. "|r")
      w.price:SetText(r.bag and ("|cff33ff99" .. FF:T("in bags") .. "|r") or FF:Money(r.price))
      w.buy:SetText(r.bag and FF:T("Equip") or FF:T("Buy"))
      w.gain:SetText(r.pct and ("|cff33ff99+%d%%|r"):format(math.floor(r.pct * 100 + 0.5)) or "|cff33ff99new|r")
    end
  end
end

-- Items the playing character never wants to buy (ticked "Skip" in the list)
function H:Skipped()
  local db = FF:DB()
  db.skip = db.skip or {}
  local me = UnitName("player") or "?"
  db.skip[me] = db.skip[me] or {}
  return db.skip[me]
end

function H:SetSkipped(id, on)
  if not id then return end
  self:Skipped()[id] = on and true or nil
  FF:Print((on and "%s won't be bought any more." or "%s is back on the shopping list."):format(FF:ItemName(id)))
  self:RefreshList()
end

-- The rows of the shopping list (also used by the tests)
function H:ListRows()
  local plan = FF:Plan()
  local rows = {}
  if not (plan and plan.buy) then return rows end
  local model = FF.Planner and FF.Planner:Model() or {}
  local bought = FF:Progress().bought
  local skipped = self:Skipped()
  for _, b in ipairs(plan.buy) do
    local m = model[b.id]
    local now = m and m.cur_min
    local got = bought[b.id] or 0
    local status
    if skipped[b.id] then status = "skipped"
    elseif got >= (b.qty or 0) then status = "done"
    elseif now and not b.gap and now <= (b.max or 0) then status = "deal"
    else status = "watching" end
    -- expected profit per unit if bought at today's lowest price: the expected sale after the AH cut, minus the price
    local cut = plan.cut or 0.05
    local sale = b.exp or (m and m.market)
    local profit = (sale and now) and math.floor(sale * (1 - cut) - now) or nil
    rows[#rows + 1] = { id = b.id, name = b.name or FF:ItemName(b.id), now = now, max = b.max, live = b.gap ~= nil,
      got = got, qty = b.qty or 0, status = status, profit = profit }
  end
  -- deals first (best profit first), then items being watched, then done and skipped ones
  local ORDER = { deal = 1, watching = 2, done = 3, skipped = 4 }
  table.sort(rows, function(a, b)
    if ORDER[a.status] ~= ORDER[b.status] then return ORDER[a.status] < ORDER[b.status] end
    if (a.profit or -math.huge) ~= (b.profit or -math.huge) then return (a.profit or -math.huge) > (b.profit or -math.huge) end
    return a.id < b.id
  end)
  return rows
end

local STATUS_COLOR = { deal = "|cff33ff99", done = "|cff888888", skipped = "|cff666666", watching = "|cffffffff" }

function H:RefreshList()
  local pg = frame and frame.pages and frame.pages.list
  if not (pg and pg:IsShown()) then return end
  local rows = self:ListRows()
  local deals, done = 0, 0
  for _, r in ipairs(rows) do
    if r.status == "deal" then deals = deals + 1 elseif r.status == "done" then done = done + 1 end
  end
  local plan = FF:Plan()
  pg.summary:SetText(#rows == 0 and "No shopping list for this character yet."
    or ("%d items  ·  %d look like deals  ·  %d done%s"):format(#rows, deals, done,
      plan and plan.live and "  ·  built in game" or ""))
  pg.offset = math.min(pg.offset, math.max(0, #rows - LIST_ROWS))
  for i, w in ipairs(pg.rows) do
    local r = rows[i + pg.offset]
    w.id = r and r.id
    w.name:SetShown(r ~= nil); w.now:SetShown(r ~= nil); w.max:SetShown(r ~= nil); w.profit:SetShown(r ~= nil); w.got:SetShown(r ~= nil); w.skip:SetShown(r ~= nil)
    if r then
      local c = STATUS_COLOR[r.status] or "|cffffffff"
      w.name:SetText(c .. r.name .. "|r")
      w.now:SetText(r.now and ((r.status == "deal" and "|cff33ff99" or "") .. FF:Money(r.now)) or "-")
      w.max:SetText(r.live and "live" or FF:Money(r.max or 0))
      w.profit:SetText(r.profit and ((r.profit > 0 and "|cff33ff99" or "|cffff8080") .. FF:Money(r.profit) .. "|r") or "-")
      w.skip:SetChecked(r.status == "skipped")
    end
  end
end

function H:RefreshOverview()
  local pg = frame and frame.pages and frame.pages.overview
  if not (pg and pg:IsShown()) then return end
  local plan = FF:Plan()
  if plan and plan.buy then
    pg.plan:SetText(FF:T("Shopping list: |cffffff00%d|r to buy, |cffffff00%d|r sell prices%s\nBudget left: %s\n%s"):format(
      #plan.buy, #(plan.sell or {}), plan.live and "  (built in game)" or "", FF:Money(FF.Trader:BudgetLeft()), FF:ScanAgeLine()))
  else
    pg.plan:SetText(FF:T("|cffff8800No shopping list yet.|r Scan at the auction house; the list builds itself.\n") .. FF:ScanAgeLine())
  end
  pg.today:SetText(FF:TodayLine() .. FF:GoalSuffix("day"))
  pg.week:SetText(FF:WeekLine() .. FF:GoalSuffix("week"))
  pg.own:SetText(FF.Auctions and FF.Auctions:Line() or "")
  pg.auto:SetText(FF.Auto:Enabled() and ("Autopilot: on" .. (FF.Auto.StatusLine and ("  ·  " .. (FF.Auto:StatusLine() or "")) or ""))
    or (FF.Auto.AVAILABLE and "Autopilot: off" or ""))
  pg.reload:SetText(FF.needReload and "|cffffd200RELOAD|r" or "Reload UI (sync)")
  local adv = FF.Advisor and FF.Advisor.last
  pg.advice:SetText(adv and adv[1] and adv[1].text or "Open the Advisor to see what to do next.")
  pg.combat:SetChecked(FF.Combat:Enabled())
  pg.autopilot:SetChecked(FF.Auto:Enabled())
  pg.level:SetText(FF.Leveling and FF.Leveling:Line() or "")
  pg.bags:SetText(FF.BagValue and FF.BagValue:Line() or "")
  pg.cooldowns:SetText(FF.Cooldowns and FF.Cooldowns:Line() or "")
end

-- Language ---------------------------------------------------------------------------------------
function H:LanguageName(code)
  if not code or code == "" then return FF:T("Game language") end
  for _, l in ipairs(FF.LANGUAGES) do if l[1] == code then return l[2] end end
  return code
end

function H:NextLanguage()
  local s = FlipForeverDB.settings
  local order = { "" }
  for _, l in ipairs(FF.LANGUAGES) do order[#order + 1] = l[1] end
  local cur = s.language or ""
  local idx = 1
  for i, code in ipairs(order) do if code == cur then idx = i end end
  s.language = order[idx % #order + 1]
  local chosen = s.language ~= "" and s.language or FF:Language()
  local msg = ("Language: %s. Click Reload to switch every window."):format(H:LanguageName(s.language))
  if FF.SCRIPT_LANGS[chosen] and GetLocale and GetLocale() ~= chosen then
    msg = msg .. " If letters show as boxes, set the game client to this language too: it brings the fonts."
  end
  FF:Print(msg)
  FF.needReload = true
  H:Refresh()
end

function H:SelectTab(name)
  if not frame then return end
  H.tab = name
  for key, page in pairs(frame.pages) do page:SetShown(key == name) end
  for key, b in pairs(frame.tabs) do
    if key == name then b:LockHighlight() else b:UnlockHighlight() end
  end
  H:Refresh()
end

-- The window ----------------------------------------------------------------------------------------
local function build()
  local f = FF:Window("FlipForeverHub", 400, 600, { pos = "hubPos", default = { "CENTER", -200, 40 } })

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText("|cff33ff99Flip|rForever")
  -- the Advisor from every tab (also: right-click the minimap coin, /ff guide, or a key in Key Bindings)
  f.advisorBtn = button(f, "Advisor", 80, function() FF.Advisor:Toggle() end)
  f.advisorBtn:SetPoint("TOPRIGHT", -30, -10)
  -- bug reports and suggestions go to the FlipForever app, which sends them (Community page)
  f.reportBtn = button(f, "Report a bug", 100, function() FF:AskReport("bug") end)
  f.reportBtn:SetPoint("RIGHT", f.advisorBtn, "LEFT", -6, 0)

  -- Tabs: Overview · Shopping list · Settings ------------------------------
  f.pages = {}
  -- Settings scroll (mouse wheel or the bar on the right): every feature can be switched here
  local scroll = CreateFrame("ScrollFrame", "FlipForeverHubSettings", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -58)
  scroll:SetPoint("BOTTOMRIGHT", -28, 30)
  local pg = CreateFrame("Frame", nil, scroll)
  pg:SetSize(372, 1256)
  scroll:SetScrollChild(pg)
  f.pages.settings = scroll
  f.pages.overview = buildOverview(f)
  f.pages.list = buildList(f)
  f.pages.gear = buildGear(f)
  f.tabs = {}
  for i, t in ipairs(TABS) do
    local b = button(f, t[2], 88, function() H:SelectTab(t[1]) end)
    b:SetPoint("TOPLEFT", 16 + (i - 1) * 92, -34)
    f.tabs[t[1]] = b
  end

  -- (the Advisor, Gathering, Professions and Talents buttons are on the Overview)
  -- Settings: one column, top to bottom, so nothing overlaps whatever the language
  local fy = -6
  local function section(label)
    heading(pg, label, fy - 4)
    fy = fy - 26
  end
  local function row(c, h)
    c:SetPoint("TOPLEFT", 14, fy)
    fy = fy - (h or 22)
    return c
  end
  local function note(text)
    local fs = pg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", 20, fy - 2)
    fs:SetPoint("RIGHT", pg, "RIGHT", -16, 0)
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(FF:T(text)) end
    fy = fy - 28
    return fs
  end
  -- a label on the left, a button (and an optional second one) on the right
  local function keyRow(onSet, onClear)
    local fs = pg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 20, fy - 6)
    fs:SetWidth(180)
    fs:SetJustifyH("LEFT")
    local set = button(pg, "Set key", 80, onSet)
    set:SetPoint("TOPLEFT", 206, fy)
    local clear
    if onClear then clear = button(pg, "Clear", 70, onClear) clear:SetPoint("TOPLEFT", 290, fy) end
    fy = fy - 28
    return fs, set, clear
  end

  -- Window size: every FlipForever window
  section("Window size")
  f.scaleLabel, f.scaleBtn = keyRow(function() H:NextScale() end)
  f.scaleBtn:SetText(FF:T("Size"))

  -- Gold reserve: what auction buying always leaves on the character (also /ff reserve)
  section("Gold reserve")
  local pctBtn, minBtn
  f.reserveLabel, pctBtn, minBtn = keyRow(function() FF.Trader:NextReservePct() H:Refresh() end,
    function() FF.Trader:NextReserveMin() H:Refresh() end)
  pctBtn:SetText(FF:T("Share"))
  minBtn:SetText(FF:T("Minimum"))
  note("Buying keeps this share of your gold, at least the minimum (never more than half your gold). Turn it off under Features.")

  -- Combat helper -------------------------------------------------------
  section("Combat helper")
  f.combat = row(check(pg, "Show the combat helper", function() FF.Combat:Toggle() end))
  f.combatMode = row(check(pg, "Blizzard's assistant decides", function() FF.Combat:ToggleBlizzard() end))
  f.autoTarget = row(check(pg, "Auto-target", function(self) FF.Combat:SetAutoTarget(self:GetChecked()) end))
  f.tank = row(check(pg, "Tank mode", function(self) FF.Combat:SetTank(self:GetChecked()) end))
  f.smart = row(check(pg, "Wait for cooldowns", function(self)
    FlipForeverDB.settings.combatSmart = self:GetChecked() and true or false
    FF.Combat:Rebuild()
  end))
  f.combatKeyText, f.combatKeyButton = keyRow(function()
    startCapture("the combat helper", function(k) FF.Combat:SetKey(k) end)
  end, function() FF.Combat:SetKey(nil) end)
  note("Auto-target: nearest enemy when you have none. Tank: click an ally, then the key hits what's on them.")

  -- Auction house -------------------------------------------------------
  section("Auction house")
  f.auto = row(check(pg, "Autopilot: check my list every minute, scan every 30 min", function() FF.Auto:SetEnabled(not FF.Auto:Enabled()) end))
  f.livePlan = row(check(pg, "After a scan: rebuild my shopping list in game (no reload)", function(self)
    FlipForeverDB.settings.livePlanning = self:GetChecked() and true or false
  end))
  f.pauseScan = row(check(pg, "Otherwise: alert + pause autopilot until Reload", function(self)
    FlipForeverDB.settings.reloadAfterScan = self:GetChecked() and true or false
  end))
  f.vendorFlips = row(check(pg, "Vendor flips: buy below merchant price, sell at merchants", function(self)
    FlipForeverDB.settings.vendorFlips = self:GetChecked() and true or false
    FlipForeverDB.settings.autoVendor = FlipForeverDB.settings.vendorFlips
  end))
  f.autoDuration = row(check(pg, "Auction length by sell speed (fast: 12 h, slow: 48 h)", function(self)
    FlipForeverDB.settings.autoDuration = self:GetChecked() and true or false
  end))
  f.gearAlert = row(check(pg, "Alert me when a scan finds a new gear upgrade", function(self)
    FlipForeverDB.settings.gearAlert = self:GetChecked() and true or false
  end))
  f.tips = row(check(pg, "Prices in item tooltips", function(self)
    FlipForeverDB.settings.tooltips = self:GetChecked() and true or false
  end))
  f.ahKeyText, f.ahKeyButton = keyRow(function()
    startCapture("the auction house button", function(k) FF:SetActionKey(k) end)
  end, function() FF:SetActionKey(nil) end)
  row(button(pg, "Check the whole list again", 178, function() FF:ResetProgress() end), 26)
  f.planText = note()

  -- Advisor -------------------------------------------------------------
  section("Advisor")
  f.popup = row(check(pg, "Pop up my next steps on level-up", function(self)
    FlipForeverDB.settings.advisorPopup = self:GetChecked() and true or false
  end))
  f.arrow = row(check(pg, "Waypoint arrow (map pin, /ffway x y, next gathering stop)", function(self)
    FlipForeverDB.settings.arrow = self:GetChecked() and true or false
    FF.Arrow:Refresh()
  end))
  -- language: click to go through every language the game supports ("Game language" follows the client)
  f.langLabel = pg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.langLabel:SetPoint("TOPLEFT", 20, fy - 6)
  f.lang = button(pg, "Language", 154, function() H:NextLanguage() end)
  f.lang:SetPoint("TOPLEFT", 206, fy)
  fy = fy - 28

  -- Buttons on screen ---------------------------------------------------
  section("Buttons on screen")
  f.mm = row(check(pg, "FlipForever minimap button", function(self)
    FlipForeverDB.settings.hideMinimap = not self:GetChecked()
    H:ApplyMinimap()
  end))
  f.oreMM = row(check(pg, "Gathering (ore) minimap button", function(self)
    local ns = FF.gatherNS
    if ns and ns.SetMinimapButtonShown and ns.db then ns.SetMinimapButtonShown(self:GetChecked()) end
  end))
  f.tracker = row(check(pg, "Gathering tracker (next stop, live gold)", function(self)
    local ns = FF.gatherNS
    if ns and ns.SetTrackerShown and ns.db then ns.SetTrackerShown(self:GetChecked()) end
  end))
  f.profPanel = row(check(pg, "Planner next to profession windows", function(self)
    FlipForeverDB.settings.profPanel = self:GetChecked() and true or false
  end))

  -- Features: one switch for everything that isn't covered above, in groups -----------------------
  -- (the order here is the switch list in the tests)
  section("Features")
  f.features = {}
  local function group(label)
    local fs = pg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 20, fy - 4)
    fs:SetText("|cff33ff99" .. FF:T(label) .. "|r")
    fy = fy - 20
  end
  local function feature(key, label, default, after, tip)
    local c = check(pg, label, function(self)
      FlipForeverDB.settings[key] = self:GetChecked() and true or false
      if after then after() end
    end)
    row(c)
    c.key, c.default = key, default
    if tip and c.SetScript then
      c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(FF:T(tip), 1, 1, 1, true)
        GameTooltip:Show()
      end)
      c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    f.features[#f.features + 1] = c
    return c
  end
  local function combatApply() if FF.Combat and FF.Combat:Enabled() then FF.Combat:Apply() end end

  group("Merchant")
  feature("merchantStrip", "Sell junk strip under the merchant window", true, function() if FF.Merchant then FF.Merchant:RefreshStrip() end end)
  feature("autoJunk", "Always sell grey items at merchants", false)
  feature("autoRepair", "Always repair at merchants (your own gold)", false)
  group("Auction house and mail")
  feature("undercutCheck", "Check my auctions for undercuts at the auction house", true)
  feature("undercutFix", "Undercut auctions: cancel and repost where it pays", true, nil,
    "Only when the new price still earns more than the deposit you lose by cancelling.")
  feature("goldReserve", "Buying keeps a gold reserve (20% of my gold, at least 20g)", true, nil,
    "Buying stops before your gold drops below the reserve and sizes purchases to what is left. The minimum never takes more than half your gold. Change it under Gold reserve above or with /ff reserve <percent> <gold>.")
  feature("bagSpace", "Buying stops before my bags are full (keeps 2 slots free)", true, nil,
    "Auction buying counts your free bag slots (profession bags not counted) and stops while a few stay free. Change how many with /ff bags <slots>.")
  feature("fastFlips", "Buying skips flips with too many cheaper listings ahead", true, nil,
    "Before buying, counts the units listed below your sell price and how fast the item sells; skips it when they would take more than twice the hold time to sell.")
  feature("expirySaver", "Expiry saver: items that expired twice go to a merchant or disenchanting", true, nil,
    "Before posting an item whose auctions expired twice or more in a row, FlipForever compares the auction (after cut and deposit) with what a merchant pays and what disenchanting gives, and holds it with a tip when those pay as much. Tooltips show the streak.")
  feature("disenchant","Disenchant values in tooltips, /ff disenchant buy list", true, nil,
    "What a green, blue or purple weapon or armor piece gives when disenchanted, at your scanned prices. /ff disenchant lists items listed below that value and buys them at the auction house.")
  feature("vendorResale", "Vendor resale finder at merchants, /ff vendors", true, nil,
    "Merchants you visit are remembered with their spot. Their limited items that sell for clearly more on the auction house are named at the merchant; /ff vendors lists the best ones and pins them on the map.")
  feature("ahSummary", "Summary when I close the auction house", true, nil,
    "What you bought, posted and sold while the auction house was open, and how your gold changed, in one chat line.")
  feature("goldGoals", "Gold goals on the Overview (/ff goal day|week <gold>)", true, function() H:Refresh() end,
    "Set a daily or weekly profit goal with /ff goal day <gold> or /ff goal week <gold>; the Overview shows how far you are (sales after the cut minus buying).")
  feature("restock", "Restock reminders for crafted items I sell", true, nil,
    "When an item you craft and posted in the last two weeks is gone from the auction house and your bags, the auction house reminds you once a day to craft and post it again.")
  feature("craftButton", "Profession planner: Craft button for the top recipe", true, function() if FF.Professions then pcall(FF.Professions.Refresh, FF.Professions) end end,
    "Crafts the planner's top skill-up or profitable recipe the planned number of times (as many as your materials allow), with the profession window open.")
  feature("profCooldowns", "Overview: profession cooldowns of all my characters", true, function() H:Refresh() end,
    "Transmutes, Mooncloth and other crafts with a cooldown are read when you open the profession window; the Overview and the app show when each is ready again on every character.")
  feature("craftCostTooltip", "Crafting cost in item tooltips for things I can craft", true, nil,
    "For items one of your professions on this character can make: what the materials cost at scanned prices, next to the auction price. Open the profession window once so its recipes are known.")
  feature("bestPostTime","Show the hours my auctions sell best when posting", true, nil,
    "From your own sales: the 4-hour window of the day in which an item (or all your items) sold most. Shown when posting and in tooltips.")
  feature("headStart", "New realm: estimate prices from my other realm until I scan", true, function() if FF.Professions then pcall(FF.Professions.Refresh, FF.Professions) end end,
    "On a realm without scans yet, tooltips and the profession planner show prices from your other realm (same faction first), marked as estimates. Buying waits for this realm's own scans.")
  feature("mailButton", "Collect auction gold button at the mailbox", true)
  feature("mailOpenAll", "Open all mail button at the mailbox", true, function() if FF.Mailbox then FF.Mailbox:Refresh() end end)
  feature("sendToAlt", "Send to alt button at the mailbox (materials and flip stock)", true, function() if FF.Mailbox then FF.Mailbox:RefreshAlt() end end)
  group("Gathering and bags")
  feature("nodeTimers", "Gathering: skip spots I gathered in the last 15 min", true, function() local ns = FF.gatherNS if ns and ns.MarkDirty then ns.MarkDirty() end end)
  feature("quietChat", "RP realms: keep FlipForever's messages out of the shared chat", true, nil,
    "On RP realms, FlipForever's chat lines go to a chat tab named FlipForever (/ff chattab makes it) or are kept for /ff log. Answers to your /ff commands, alerts and errors still show.")
  feature("enemyAlert","PvP: sound and chat line when an enemy player is near or targets me", true, nil,
    "On PvP realms in the open world: when a player of the other faction who can attack you shows up on a nameplate or targets you. Quiet in dungeons and battlegrounds; each player is named at most once a minute.")
  feature("bagValue", "Overview: value of my bags, items worth posting", true)
  group("Advisor, quests and talents")
  feature("trainerReminder", "Advisor: remind me of new spells at my class trainer", true)
  feature("levelInfo", "Overview: XP per hour, time to level, rested XP", true)
  feature("talentOverlay", "Show my build on the Talents window (next point marked)", true, function() if FF.TalentOverlay then FF.TalentOverlay:Refresh() end end)
  feature("talentLevels", "Talents: the talent to take at every level for my chosen build", true, function() if FF.TalentOverlay then FF.TalentOverlay:Refresh() end end,
    "The Talents window panel gets a By level button (mouse wheel scrolls), and the Advisor lists the build level by level. Change the build with the arrows.")
  feature("questHelper", "Quest helper: learn quest spots, map pins, /ff quest", true, function() if FF.QuestHelper then FF.QuestHelper:RefreshMap() end end,
    "FlipForever remembers where quest givers and objectives are as you play and shows them on the map and minimap.")
  feature("advisorPins", "Advisor: pin steps on the map and minimap (right-click a step)", true, function() if FF.QuestHelper then FF.QuestHelper:RefreshAll() end end)
  feature("questLogPin", "Quest log: Pin on map button for the selected quest", true, function() if FF.QuestHelper then pcall(FF.QuestHelper.SetupLogButton, FF.QuestHelper) end end)
  feature("levelRoute", "Advisor: leveling route, the next town for my level with the arrow", true)
  feature("dungeonAdvisor", "Advisor: the dungeon with the most upgrades for my weak slots", true)
  feature("advisorQuestSpots", "Advisor: class quests in my log point to their next learned spot", true)
  group("Combat helper")
  feature("combatBuffs", "Combat helper: cast my missing buffs before a fight", true, combatApply)
  feature("threatWarning", "Combat helper: warn me about high threat", true)
  feature("combatLearn", "Combat helper: learn the best order from my fights", true, combatApply,
    "Tries small changes to the spell order and keeps the one that kills fastest for you.")
  feature("combatTips", "Combat helper: tell me after a fight what to do better", true)
  feature("combatGuide", "Combat helper: emergency key, interrupts, cooldowns for elites", true, combatApply,
    "Big cooldowns are kept for elites, rares, bosses and players.")
  feature("combatTutorial", "Combat helper: also test the orders from written class guides", true, combatApply,
    "The spell orders from WoW: Forever leveling guides are tested next to the helper's own.")
  feature("controller", "Controller: gamepad buttons for keys, readable button names", true, nil,
    "Bind the combat helper, emergency and arrow in Key Bindings, FlipForever, or use Set key with a gamepad button.")
  feature("combatShare", "Share anonymous combat data to improve the helper", true, nil,
    "Only spell orders and fight times, no names. The desktop app sends them.")
  group("Gear")
  feature("gearTooltip", "Gear upgrade line in item tooltips", true)
  feature("gearStats", "Gear finder: show the stat gains against what I wear", true)
  pg:SetHeight(-fy + 16)

  local foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  foot:SetPoint("BOTTOMLEFT", 16, 14)
  foot:SetPoint("RIGHT", -16, 0)
  foot:SetJustifyH("LEFT")
  foot:SetText(FF:T("Buy / post / scan buttons appear next to the auction house. Type /ff help for every command."))
  -- keep the open page current (purchases, autopilot, new lists) without spamming refreshes
  local since = 0
  f:SetScript("OnUpdate", function(_, elapsed)
    since = since + (elapsed or 0)
    if since >= 1 then since = 0 H:RefreshOverview() H:RefreshList() end
  end)
  f:Hide()
  return f
end

function H:Refresh()
  if not (frame and frame:IsShown()) then return end
  H:RefreshOverview()
  H:RefreshList()
  H:RefreshGear()
  local s = FlipForeverDB.settings
  frame.combat:SetChecked(FF.Combat:Enabled())
  frame.autoTarget:SetChecked(FF.Combat:AutoTarget())
  frame.tank:SetChecked(FF.Combat:IsTank())
  frame.smart:SetChecked(FF.Combat:Smart())
  frame.combatMode:SetChecked(s.combatBlizzard == true)
  frame.combatMode:SetEnabled(FF.Combat:BlizzardAssistSpell() ~= nil)
  frame.combatMode.text:SetText(FF.Combat:BlizzardAssistSpell() and "Blizzard's assistant decides"
    or "|cff888888Blizzard's assistant (not in this client)|r")
  local ckeys = {}
  for i, k in ipairs(FF.Combat:Keys()) do ckeys[i] = FF:KeyLabel(k) end
  frame.combatKeyText:SetText(FF:T("Key: ") .. (#ckeys > 0 and ("|cffffff00" .. table.concat(ckeys, ", ") .. "|r") or "|cff888888none - click the icon|r"))
  frame.auto:SetChecked(FF.Auto:Enabled())
  frame.ahKeyText:SetText(FF:T("Big-button key: ") .. (s.key and ("|cffffff00" .. FF:KeyLabel(s.key) .. "|r") or "|cff888888none - click it|r"))
  local plan = FF:Plan()
  frame.planText:SetText(plan and plan.buy and ("Shopping list for " .. (UnitName("player") or "?") .. ": " .. #plan.buy .. " buys, " .. #(plan.sell or {}) .. " sell prices" .. (plan.live and " (built in game from your newest scan)." or "."))
    or "No shopping list for this character yet - build one in the FlipForever app.")
  frame.popup:SetChecked(s.advisorPopup ~= false)
  frame.tips:SetChecked(s.tooltips ~= false)
  frame.profPanel:SetChecked(s.profPanel ~= false)
  frame.pauseScan:SetChecked(s.reloadAfterScan ~= false)
  frame.livePlan:SetChecked(s.livePlanning ~= false)
  frame.langLabel:SetText(FF:T("Language") .. ":")
  frame.scaleLabel:SetText(FF:T("All FlipForever windows: %d%%"):format(math.floor(FF:WindowScale() * 100 + 0.5)))
  if s.goldReserve == false then
    frame.reserveLabel:SetText(FF:T("Gold reserve: off"))
  else
    frame.reserveLabel:SetText(FF:T("Keep %d%%, at least %s"):format(math.floor((tonumber(s.reservePct) or 0.20) * 100 + 0.5),
      FF:Money(tonumber(s.reserveMin) or 200000)))
  end
  frame.lang:SetText(H:LanguageName(s.language))
  frame.vendorFlips:SetChecked(s.vendorFlips ~= false)
  frame.arrow:SetChecked(s.arrow ~= false)
  frame.autoDuration:SetChecked(s.autoDuration ~= false)
  frame.gearAlert:SetChecked(s.gearAlert ~= false)
  frame.mm:SetChecked(not s.hideMinimap)
  for _, c in ipairs(frame.features) do
    local v = s[c.key]
    if v == nil then v = c.default end
    c:SetChecked(v and true or false)
  end
  local ns = FF.gatherNS
  local gatherOn = ns and ns.db and not ns.skipGather
  frame.oreMM:SetEnabled(gatherOn and true or false)
  frame.tracker:SetEnabled(gatherOn and true or false)
  if gatherOn then
    frame.oreMM:SetChecked(ns.db.minimapButton ~= false)
    frame.tracker:SetChecked(ns.db.panelShown ~= false)
  end
end

-- Settings, Window size: 80 -> 90 -> 100 -> 110 -> 80 %
function H:NextScale()
  local cur, list = FF:WindowScale(), FF.WINDOW_SCALES
  local nextScale = list[1]
  for i, s in ipairs(list) do
    if math.abs(s - cur) < 0.01 then nextScale = list[i % #list + 1] break end
  end
  FF:SetWindowScale(nextScale)
  H:Refresh()
end

function H:Toggle()
  frame = frame or build()
  if frame:IsShown() then frame:Hide() else frame:Show() H:SelectTab(H.tab or "overview") end
end

function H:Show(tab)
  frame = frame or build()
  frame:Show()
  H:SelectTab(tab or H.tab or "overview")
end

-- Quick summary for the minimap tooltip ------------------------------------------------------------
function H:Summary()
  local out = {}
  local plan = FF:Plan()
  if plan and plan.buy then
    local left = plan.budget and ("  ·  budget left " .. FF:Money(FF.Trader:BudgetLeft())) or ""
    out[#out + 1] = ("Shopping list: %d to check%s"):format(#plan.buy, left)
  else
    out[#out + 1] = "No shopping list for this character yet"
  end
  out[#out + 1] = FF:TodayLine()
  if FF.Auto:Enabled() then
    local now = time()
    local nextScan = FF.Auto.nextScan and math.max(0, FF.Auto.nextScan - now)
    out[#out + 1] = "Autopilot on" .. (nextScan and ("  ·  next scan in " .. math.floor(nextScan / 60) .. " min") or "") .. " (at the AH)"
  end
  local adv = FF.Advisor and FF.Advisor.last
  if adv and adv[1] then
    out[#out + 1] = "Next: " .. adv[1].text:gsub("|T.-|t%s*", "")
  end
  return out
end

-- Minimap button (gold coin) ------------------------------------------------------------------------
local function placeMinimap()
  local angle = math.rad(FlipForeverDB.settings.minimapAngle or 200)
  local r = (Minimap:GetWidth() / 2) + 6
  mmButton:ClearAllPoints()
  mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function createMinimap()
  if mmButton or not Minimap then return end
  mmButton = CreateFrame("Button", "FlipForeverMinimapButton", Minimap)
  mmButton:SetSize(31, 31)
  mmButton:SetFrameStrata("MEDIUM")
  mmButton:SetFrameLevel(8)
  mmButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mmButton:RegisterForDrag("LeftButton")
  local icon = mmButton:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  local border = mmButton:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mmButton:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then FF.Advisor:Toggle() else H:Toggle() end
  end)
  mmButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      FlipForeverDB.settings.minimapAngle = math.deg(math.atan2(py / scale - my, px / scale - mx))
      placeMinimap()
    end)
  end)
  mmButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mmButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff33ff99Flip|rForever")
    for _, l in ipairs(H:Summary()) do GameTooltip:AddLine(l, 0.85, 0.85, 0.85, true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: FlipForever window", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Advisor (what to do next)", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  mmButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  placeMinimap()
end

function H:ApplyMinimap()
  createMinimap()
  if mmButton then mmButton:SetShown(not FlipForeverDB.settings.hideMinimap) end
end

FF:On("PLAYER_LOGIN", function()
  H:ApplyMinimap()
  -- one entry in the AddOns menu (top-right of the minimap) for everything
  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
      text = "FlipForever", icon = "Interface\\Icons\\INV_Misc_Coin_01", notCheckable = true,
      func = function() H:Toggle() end,
    })
  end
end)

-- Talent build on the game's Talents window: marks every talent of the chosen Advisor build
-- with its place in the order, highlights the next point, and shows the whole order in a
-- panel beside the window. Read-only: you still spend every point yourself.
local FF = FlipForever
local AD = FF.Advisor
local TO = {}
FF.TalentOverlay = TO

local GOLD, GREEN, GREY, WHITE = "|cffffd200", "|cff40ff40", "|cff888888", "|cffffffff"

function TO:Enabled()
  return FlipForeverDB and FlipForeverDB.settings and FlipForeverDB.settings.talentOverlay ~= false
end

-- Where each talent sits in the game's trees: name -> { tab, index, rank, max, tier }, and the
-- points spent per tree.
function TO:Trees()
  local where, spent, names = {}, {}, {}
  if not (GetNumTalentTabs and GetNumTalents and GetTalentInfo) then return where, spent, names end
  local okTabs, tabs = pcall(GetNumTalentTabs)
  for tab = 1, (okTabs and tabs or 0) do
    spent[tab] = 0
    if GetTalentTabInfo then
      local r = { pcall(GetTalentTabInfo, tab) }
      if r[1] and type(r[2]) == "string" then names[tab] = r[2] end
    end
    local okN, n = pcall(GetNumTalents, tab)
    for i = 1, (okN and n or 0) do
      local r = { pcall(GetTalentInfo, tab, i) }
      if r[1] and type(r[2]) == "string" then
        local rank = tonumber(r[6]) or 0
        where[r[2]] = { tab = tab, index = i, tier = tonumber(r[4]) or 1, rank = rank, max = tonumber(r[7]) or 1 }
        spent[tab] = spent[tab] + rank
      end
    end
  end
  return where, spent, names
end

-- The build as an ordered plan: one entry per talent with its state.
--   state: "done" (target rank reached), "next" (the next point), "todo", "level" (needs a
--   higher level), "missing" (not in this client's trees).
function TO:Plan(build, level)
  local plan = { steps = {}, byName = {} }
  if not (build and build.talents) then return plan end
  local where, spent, names = self:Trees()
  plan.spent, plan.treeNames = spent, names
  -- Builds that only name their key talents get an order of our own: lower tiers first (the
  -- guide's order within a tier), and the next point is one you can already take.
  local list = {}
  for i, t in ipairs(build.talents) do list[i] = { t = t, i = i } end
  if build.keyOnly then
    table.sort(list, function(a, b)
      local wa, wb = where[a.t[1]], where[b.t[1]]
      local ta, tb = wa and wa.tier or 99, wb and wb.tier or 99
      if ta ~= tb then return ta < tb end
      return a.i < b.i
    end)
  end
  local function unlocked(w) return (spent[w.tab] or 0) >= ((w.tier or 1) - 1) * 5 end
  local nextFound, firstLocked = false, nil
  for order, e in ipairs(list) do
    local t = e.t
    local name, want, minLevel = t[1], t[2], t[3]
    local w = where[name]
    local s = { order = order, name = name, minLevel = minLevel }
    if not w then
      s.state = "missing"
    else
      s.tab, s.index, s.cur, s.tier = w.tab, w.index, w.rank, w.tier
      s.treeName = names[w.tab]
      s.target = math.min(want or w.max, w.max)
      if s.cur >= s.target then
        s.state = "done"
      elseif (minLevel or 0) > (level or 60) then
        s.state = "level"
      elseif not nextFound and (not build.keyOnly or unlocked(w)) then
        s.state, nextFound = "next", true
      else
        s.state = "todo"
        if build.keyOnly and not firstLocked and not unlocked(w) then firstLocked = s end
      end
    end
    plan.steps[#plan.steps + 1] = s
    plan.byName[name] = s
  end
  -- nothing reachable yet: the first locked talent is next, with the points its tier still needs
  if not nextFound and firstLocked then
    firstLocked.state = "next"
    firstLocked.needPoints = (firstLocked.tier - 1) * 5 - (spent[firstLocked.tab] or 0)
  end
  plan.done = 0
  for _, s in ipairs(plan.steps) do if s.state == "done" then plan.done = plan.done + 1 end end
  return plan
end

-- "Yours 0/10/0" next to the build's planned split.
function TO:PointsLine(build, plan)
  local mine = {}
  for tab = 1, #(plan.spent or {}) do mine[tab] = plan.spent[tab] or 0 end
  local parts = {}
  if build.points then parts[#parts + 1] = FF:T("Build %s"):format(build.points) end
  if #mine > 0 then parts[#parts + 1] = FF:T("yours %s"):format(table.concat(mine, "/")) end
  local ok, unspent = pcall(UnitCharacterPoints or function() return 0 end, "player")
  unspent = ok and tonumber(unspent) or 0
  if unspent > 0 then parts[#parts + 1] = GOLD .. FF:T("%d to spend"):format(unspent) .. "|r" end
  return table.concat(parts, " - ")
end

-- Drift: points you spent in a tree the build leaves empty ("0" in its split). Returns the
-- warning line, or nil. Example split "0/26/0", yours "3/10/0": 3 points off the build in tree 1.
function TO:DriftLine(build, plan)
  if not (build and build.points and plan and plan.spent) then return nil end
  local want = {}
  for n in tostring(build.points):gmatch("%d+") do want[#want + 1] = tonumber(n) end
  local off, trees = 0, {}
  for tab, spent in ipairs(plan.spent) do
    if want[tab] == 0 and (spent or 0) > 0 then
      off = off + spent
      trees[#trees + 1] = (plan.treeNames and plan.treeNames[tab]) or ("tree " .. tab)
    end
  end
  if off == 0 then return nil end
  return "|cffff8800" .. FF:T("%d point%s in %s, which this build leaves empty - a respec at your trainer puts them back."):format(
    off, FF:Plural(off), table.concat(trees, ", ")) .. "|r"
end

-- Where your points should stand per level band, for builds with a full pick order: the order
-- is followed point by point (one point per level from 10), so at level 20 the first 11 points
-- are spent, at 30 the first 21, and so on. Returns { level, split = { per tree }, total } per band.
TO.BANDS = { 20, 30, 40, 50, 60 }
function TO:Bands(build, plan)
  if not (build and not build.keyOnly and plan and plan.steps and #plan.steps > 0) then return nil end
  local trees = math.max(#(plan.spent or {}), 3)
  local order = {}   -- one entry per point: the tree it goes into
  for _, s in ipairs(plan.steps) do
    if s.tab and s.target then
      for _ = 1, s.target do order[#order + 1] = s.tab end
    end
  end
  if #order == 0 then return nil end
  local out = {}
  for _, lvl in ipairs(self.BANDS) do
    local points = math.min(lvl - 9, #order)
    local split = {}
    for t = 1, trees do split[t] = 0 end
    for i = 1, points do split[order[i]] = (split[order[i]] or 0) + 1 end
    out[#out + 1] = { level = lvl, split = split, total = points }
    if points >= #order then break end   -- the build is complete by this band
  end
  return out
end

-- Two short lines for the panel: "By level 20: 0/11/0  30: 0/21/0  40: 5/26/0" and the rest.
-- The band you are in now is gold; when you have fewer points in a tree than the order puts
-- there by your level, a short note says so.
function TO:BandLines(build, plan, level)
  local bands = self:Bands(build, plan)
  if not bands then return nil end
  level = tonumber(level) or 60
  local parts = {}
  local current
  for _, b in ipairs(bands) do
    local text = ("%d: %s"):format(b.level, table.concat(b.split, "/"))
    if not current and level <= b.level then current = b text = GOLD .. text .. "|r" end
    parts[#parts + 1] = text
  end
  local first = FF:T("By level") .. " " .. table.concat(parts, "  ", 1, math.min(3, #parts))
  local second = #parts > 3 and table.concat(parts, "  ", 4) or nil
  -- behind the order: compare against the points you can have spent at your level
  local behind
  if plan.spent and level >= 10 then
    local points = level - 9
    local want = {}
    for _, s in ipairs(plan.steps) do
      if s.tab and s.target and points > 0 then
        local n = math.min(s.target, points)
        want[s.tab] = (want[s.tab] or 0) + n
        points = points - n
      end
    end
    for tab, n in pairs(want) do
      local have = plan.spent[tab] or 0
      if have < n then
        behind = (behind or 0) + (n - have)
      end
    end
  end
  return first, second, behind
end

-- By level: the talent to take at every level from 10 to 60 for the chosen build -----------------
function TO:LevelsEnabled()
  return FlipForeverDB and FlipForeverDB.settings and FlipForeverDB.settings.talentLevels ~= false
end

-- Plays the build from an empty tree, one point per level: each level takes the first talent of
-- the order that is below its target, allowed at that level and unlocked (5 points per tier in
-- its tree). When the build's next talent sits in a tier that is still locked, the point goes
-- into the lowest open talent of that tree that the build does not use ("filler").
-- Returns a list of { level, name, rank, max, tab, index, treeName, filler, state } where
-- state is "done" (you have that rank), "next" (the first one you don't) or "todo".
TO.FIRST_LEVEL, TO.LAST_LEVEL = 10, 60
function TO:LevelPlan(build, plan, level)
  if not (build and plan and plan.steps) then return nil end
  local where = self:Trees()
  local steps = {}
  for _, s in ipairs(plan.steps) do
    if s.tab and s.target and s.target > 0 then steps[#steps + 1] = s end
  end
  if #steps == 0 then return nil end
  local planned = {}
  for _, s in ipairs(steps) do planned[s.name] = true end
  local rank, spent = {}, {}
  local function open(tab, tier) return (spent[tab] or 0) >= ((tier or 1) - 1) * 5 end
  local function filler(tab)
    local best, bestName
    for name, w in pairs(where) do
      if w.tab == tab and not planned[name] and (rank[name] or 0) < (w.max or 1) and open(tab, w.tier) then
        if not best or w.tier < best.tier or (w.tier == best.tier and w.index < best.index) then best, bestName = w, name end
      end
    end
    return best, bestName
  end
  local out = {}
  for lvl = self.FIRST_LEVEL, self.LAST_LEVEL do
    local pick, locked
    for _, s in ipairs(steps) do
      if (rank[s.name] or 0) < s.target and (s.minLevel or 0) <= lvl then
        if open(s.tab, s.tier) then pick = s break end
        locked = locked or s
      end
    end
    local e
    if pick then
      rank[pick.name] = (rank[pick.name] or 0) + 1
      local w = where[pick.name] or {}
      e = { name = pick.name, tab = pick.tab, index = pick.index, max = w.max or pick.target, target = pick.target }
    elseif locked then
      local w, name = filler(locked.tab)
      if not w then break end
      rank[name] = (rank[name] or 0) + 1
      e = { name = name, tab = w.tab, index = w.index, max = w.max, filler = true, forName = locked.name }
    else
      break   -- the build is complete (or waits for a level): the rest of the points are free
    end
    spent[e.tab] = (spent[e.tab] or 0) + 1
    e.level, e.rank = lvl, rank[e.name]
    e.treeName = plan.treeNames and plan.treeNames[e.tab]
    local have = where[e.name] and where[e.name].rank or 0
    e.cur = have
    out[#out + 1] = e
  end
  local nextFound = false
  for _, e in ipairs(out) do
    if e.cur >= e.rank then e.state = "done"
    elseif not nextFound then e.state, nextFound = "next", true
    else e.state = "todo" end
  end
  return out
end

-- The same plan in short ranges for the Advisor window: "L10-14 Improved Frostbolt 5/5"
function TO:LevelRanges(list)
  local out = {}
  for _, e in ipairs(list or {}) do
    local last = out[#out]
    if last and last.name == e.name and last.to == e.level - 1 then
      last.to, last.rank = e.level, e.rank
    else
      out[#out + 1] = { from = e.level, to = e.level, name = e.name, rank = e.rank, max = e.max, filler = e.filler, tree = e.treeName }
    end
  end
  local lines = {}
  for _, r in ipairs(out) do
    local lv = r.from == r.to and ("L%d"):format(r.from) or ("L%d-%d"):format(r.from, r.to)
    lines[#lines + 1] = ("%s  %s %d/%d%s"):format(lv, r.name, r.rank, r.max or r.rank,
      r.filler and (" " .. GREY .. FF:T("(filler)") .. "|r") or (r.tree and (" " .. GREY .. r.tree .. "|r") or ""))
  end
  return lines
end

-- one line of the by-level list: "L12  Frostbite 2/3  Frost"
function TO:LevelLine(e, level)
  local color = (e.state == "done" and GREEN) or (e.state == "next" and GOLD) or (e.filler and GREY) or WHITE
  local text = ("%sL%d  %s %d/%d|r"):format(color, e.level, e.name, e.rank, e.max or e.rank)
  if e.filler then text = text .. " " .. GREY .. FF:T("(opens the tier for %s)"):format(e.forName) .. "|r"
  elseif e.treeName then text = text .. " " .. GREY .. e.treeName .. "|r" end
  if e.state == "next" then text = text .. " " .. GOLD .. FF:T("next") .. "|r" end
  if level and e.level > level and e.state ~= "done" then text = text:gsub("^|cff%x%x%x%x%x%x", GREY) end
  return text
end

-- the build's role in plain words
local ROLES = { dps = "Damage", tank = "Tank", healer = "Healer", pvp = "PvP", leveling = "Leveling" }
function TO:RoleLine(build)
  if not (build.role and ROLES[build.role]) then return "" end
  return FF:T("Role: %s"):format(FF:T(ROLES[build.role]))
end

-- one line of the order, with the tree after it so you know which tab to open
function TO:StepLine(s)
  local line = self:StepText(s)
  if s.treeName and s.state ~= "missing" then line = line .. " " .. GREY .. s.treeName .. "|r" end
  return line
end

function TO:StepText(s)
  local label = s.name
  if s.state == "done" then
    return ("%s%d. %s|r %s(%d/%d)|r"):format(GREEN, s.order, label, GREEN, s.cur, s.target)
  elseif s.state == "next" then
    return ("%s%d. %s (%d/%d) - %s|r"):format(GOLD, s.order, label, s.cur, s.target, FF:T("next"))
  elseif s.state == "level" then
    return ("%s%d. %s - %s|r"):format(GREY, s.order, label, FF:T("from level %d"):format(s.minLevel))
  elseif s.state == "missing" then
    return ("%s%d. %s|r"):format(GREY, s.order, label)
  end
  return ("%s%d. %s (%d/%d)|r"):format(WHITE, s.order, label, s.cur, s.target)
end

-- The game's Talents window and its talent buttons (names differ between client versions) -------
local FRAME_NAMES = { "PlayerTalentFrame", "TalentFrame", "ClassTalentFrame", "PlayerSpellsFrame" }
local TALENT_ADDONS = { "Blizzard_TalentUI", "Blizzard_ClassTalentUI", "Blizzard_PlayerSpells" }

function TO:GameFrame()
  for _, n in ipairs(FRAME_NAMES) do
    local f = _G[n]
    if type(f) == "table" then return f, n end
  end
  if self.foundName and type(_G[self.foundName]) == "table" then return _G[self.foundName], self.foundName end
end

-- WoW: Forever's own Talents window has its own name: look for a top-level frame called
-- "...Talent...Frame" (the shown one first) and remember it
function TO:FindFrame()
  local best, bestName
  for name, obj in pairs(_G) do
    if type(name) == "string" and type(obj) == "table" and name:find("Talent") and name:find("Frame$")
       and not name:find("^FlipForever") and type(obj.GetObjectType) == "function" then
      local okP, parent = pcall(obj.GetParent, obj)
      if okP and parent == UIParent then
        local shown = obj.IsShown and obj:IsShown()
        if not best or (shown and not best.shown) then best, bestName = { shown = shown }, name end
      end
    end
  end
  self.foundName = bestName
  return bestName and _G[bestName], bestName
end

function TO:SelectedTab(f)
  if not f then return 1 end
  if PanelTemplates_GetSelectedTab then
    local ok, t = pcall(PanelTemplates_GetSelectedTab, f)
    if ok and type(t) == "number" then return t end
  end
  return f.selectedTab or f.currentSelectedTab or 1
end

-- the talent buttons of the shown tree: list of { button, index }
function TO:Buttons(frameName)
  local list = {}
  for i = 1, 60 do
    local b = _G[frameName .. "Talent" .. i]
    if not b then break end
    local idx = (b.GetID and b:GetID()) or i
    list[#list + 1] = { button = b, index = (type(idx) == "number" and idx > 0) and idx or i }
  end
  return list
end

-- our marks, kept apart from the game's buttons
local marks = setmetatable({}, { __mode = "k" })
function TO:Mark(button) return marks[button] end

-- the build's line for a talent tooltip: "FlipForever build: 3rd pick, 2/3 - next"
function TO:TooltipLine(s)
  if not s then return nil end
  local state = ({ done = FF:T("done"), next = FF:T("next"), level = s.minLevel and FF:T("from level %d"):format(s.minLevel) or nil })[s.state]
  local line = s.level and FF:T("FlipForever build: level %d"):format(s.level) or FF:T("FlipForever build: pick %d"):format(s.order)
  if s.target then line = line .. (" - %d/%d"):format(s.cur or 0, s.target) end
  if state then line = line .. " - " .. state end
  return line
end

-- adds the build's line under the game's tooltip of a marked talent button
local function addToTooltip(button)
  local m = marks[button]
  if not (m and m.step and m:IsShown() and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button)) then return end
  local s = m.step
  local r, g, b = 1, 1, 1
  if s.state == "next" then r, g, b = 1, 0.82, 0 elseif s.state == "done" then r, g, b = 0.25, 1, 0.25 end
  GameTooltip:AddLine(TO:TooltipLine(s), r, g, b)
  GameTooltip:Show()
end

local function marker(button)
  if marks[button] then return marks[button] end
  local m = CreateFrame("Frame", nil, button)
  m:SetAllPoints(button)
  if m.SetFrameLevel and button.GetFrameLevel then m:SetFrameLevel((button:GetFrameLevel() or 1) + 2) end
  m.glow = m:CreateTexture(nil, "OVERLAY")
  m.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  m.glow:SetBlendMode("ADD")
  m.glow:SetPoint("CENTER", m, "CENTER", 0, 0)
  m.glow:SetSize(64, 64)
  m.num = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  m.num:SetPoint("TOPLEFT", m, "TOPLEFT", -4, 4)
  marks[button] = m
  if button.HookScript then button:HookScript("OnEnter", addToTooltip) end
  return m
end

-- Mark the build's talents on the shown tree. Returns how many buttons were marked.
function TO:Decorate(plan)
  local f, fname = self:GameFrame()
  if not f then return 0 end
  local tab = self:SelectedTab(f)
  local byIndex = {}
  for _, s in ipairs(plan.steps) do
    if s.tab == tab and s.index then byIndex[s.index] = s end
  end
  local marked = 0
  for _, e in ipairs(self:Buttons(fname)) do
    local s = self:Enabled() and byIndex[e.index]
    if s then
      local m = marker(e.button)
      if s.state == "next" then
        m.glow:SetVertexColor(1, 0.82, 0)
        m.glow:Show()
      elseif s.state == "done" then
        m.glow:SetVertexColor(0.25, 1, 0.25)
        m.glow:Show()
      else
        m.glow:Hide()
      end
      m.num:SetText((s.state == "next" and GOLD or WHITE) .. s.order .. "|r")
      m.state, m.step = s.state, s
      m:Show()
      marked = marked + 1
    elseif marks[e.button] then
      marks[e.button]:Hide()
      marks[e.button].state, marks[e.button].step = nil, nil
    end
  end
  return marked
end

-- Panel beside the Talents window -----------------------------------------------------------------
local panel
local MAX_LINES = 22

function TO:Panel(parent)
  if panel then return panel end
  panel = CreateFrame("Frame", "FlipForeverTalentPanel", parent or UIParent, "BackdropTemplate")
  panel:SetSize(240, 518)
  panel:SetPoint("TOPLEFT", parent or UIParent, "TOPRIGHT", -30, -12)
  -- same look as the other FlipForever windows (Core.lua FF:Window), attached to the Talents window
  if panel.SetBackdrop then
    panel:SetBackdrop(FF.WINDOW_BACKDROP)
    panel:SetBackdropColor(0.05, 0.06, 0.08, 0.92)
    if panel.SetBackdropBorderColor then panel:SetBackdropBorderColor(0.2, 0.8, 0.5, 1) end
  end
  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.title:SetPoint("TOPLEFT", 12, -10)
  panel.title:SetText(FF:T("FlipForever build"))
  local function arrow(text, step, x)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(24, 20)
    b:SetPoint("TOPRIGHT", x, -6)
    b:SetText(text)
    b:SetScript("OnClick", function() TO.levelOffset = nil AD:CycleBuild(step) TO:Refresh() end)
    return b
  end
  panel.prev = arrow("<", -1, -36)
  panel.next = arrow(">", 1, -10)
  -- switch between the talent order and the talent for every level
  panel.view = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  panel.view:SetSize(64, 20)
  panel.view:SetPoint("TOPRIGHT", -62, -6)
  panel.view:SetScript("OnClick", function() TO:SetView(TO:View() == "levels" and "order" or "levels") end)
  if panel.EnableMouseWheel then panel:EnableMouseWheel(true) end
  panel:SetScript("OnMouseWheel", function(_, delta) TO:ScrollLevels(delta) end)
  panel.build = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  panel.build:SetPoint("TOPLEFT", 12, -30)
  panel.build:SetPoint("RIGHT", -12, 0)
  panel.build:SetJustifyH("LEFT")
  -- one line: long build names are cut instead of running over the lines below
  if panel.build.SetWordWrap then panel.build:SetWordWrap(false) end
  panel.points = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.points:SetPoint("TOPLEFT", 12, -48)
  panel.points:SetPoint("RIGHT", -12, 0)
  panel.points:SetJustifyH("LEFT")
  panel.role = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.role:SetPoint("TOPLEFT", 12, -62)
  panel.role:SetPoint("RIGHT", -12, 0)
  panel.role:SetJustifyH("LEFT")
  -- where your points should stand per level band (builds with a full pick order)
  panel.bands1 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.bands1:SetPoint("TOPLEFT", 12, -76)
  panel.bands1:SetPoint("RIGHT", -12, 0)
  panel.bands1:SetJustifyH("LEFT")
  panel.bands2 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.bands2:SetPoint("TOPLEFT", 12, -90)
  panel.bands2:SetPoint("RIGHT", -12, 0)
  panel.bands2:SetJustifyH("LEFT")
  panel.lines = {}
  panel.rows = {}
  for i = 1, MAX_LINES do
    -- each line is a button: click it to open that talent's tree
    local row = CreateFrame("Button", nil, panel)
    row:SetPoint("TOPLEFT", 12, -108 - (i - 1) * 13)
    row:SetPoint("RIGHT", -12, 0)
    row:SetHeight(13)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnClick", function(self) if self.tab then TO:ShowTree(self.tab) end end)
    -- hover: the game's own description of the talent, with the build's pick and target rank
    row:SetScript("OnEnter", function(self) TO:RowTooltip(self) end)
    row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetAllPoints(row)
    fs:SetJustifyH("LEFT")
    panel.lines[i], panel.rows[i] = fs, row
  end
  panel.note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.note:SetPoint("BOTTOMLEFT", 12, 10)
  panel.note:SetPoint("RIGHT", -12, 0)
  panel.note:SetJustifyH("LEFT")
  -- how to play the build, a few lines above the note
  panel.rotation = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.rotation:SetPoint("BOTTOMLEFT", panel.note, "TOPLEFT", 0, 6)
  panel.rotation:SetPoint("RIGHT", -12, 0)
  panel.rotation:SetJustifyH("LEFT")
  if panel.rotation.SetWordWrap then panel.rotation:SetWordWrap(true) end
  return panel
end

-- "order" (the build's talent order) or "levels" (the talent for every level); remembered
function TO:View()
  local s = FlipForeverDB and FlipForeverDB.settings
  return (s and s.talentView) or "order"
end

function TO:SetView(view)
  if FlipForeverDB and FlipForeverDB.settings then FlipForeverDB.settings.talentView = view end
  self.levelOffset = nil
  self:Refresh()
end

-- mouse wheel over the by-level list: a few levels up or down
function TO:ScrollLevels(delta)
  if self:View() ~= "levels" then return end
  self.levelOffset = math.max(1, (self.levelOffset or self.lastFirst or 1) - (delta or 0) * 3)
  self:Refresh()
end

-- Text of the panel (kept apart from the frame so it can be tested): title, points, lines, note.
function TO:PanelText(p)
  p = p or AD:Player()
  local build = AD:Build(p)
  if not build then return { build = FF:T("No builds for your class yet."), lines = {} } end
  local plan = self:Plan(build, p.level)
  local out = { plan = plan, lines = {} }
  out.build = build.name
  out.points = self:PointsLine(build, plan)
  out.role = self:RoleLine(build)
  local b1, b2, behind = self:BandLines(build, plan, p.level)
  out.bands1, out.bands2 = b1 or "", b2 or ""
  -- more points short than you have left to spend: some went elsewhere
  local ok, unspent = pcall(UnitCharacterPoints or function() return 0 end, "player")
  unspent = ok and tonumber(unspent) or 0
  if behind and behind > unspent then
    out.behind = "|cffff8800" .. FF:T("%d point%s behind the order for your level."):format(behind - unspent, FF:Plural(behind - unspent)) .. "|r"
  end
  out.rotation = build.rotation and (GOLD .. FF:T("How to play:") .. "|r " .. build.rotation) or ""
  local header = build.keyOnly and FF:T("Key talents, lower tiers first") or FF:T("Talent order")
  out.lines[1] = GOLD .. header .. "|r"
  out.tabs, out.steps = {}, {}
  for _, s in ipairs(plan.steps) do
    out.lines[#out.lines + 1] = self:StepLine(s)
    out.tabs[#out.lines] = s.tab
    out.steps[#out.lines] = s
  end
  if #plan.steps == 0 then out.lines[#out.lines + 1] = FF:T("This guide shows its talents only as a picture - follow it on the guide's page.") end
  -- By level view (button on the panel, mouse wheel scrolls): one line per level, the list
  -- opens a few levels before your next point
  out.levels = self:LevelsEnabled() and self:LevelPlan(build, plan, p.level) or nil
  out.view = (out.levels and self:View() == "levels") and "levels" or "order"
  if out.view == "levels" then
    local list = out.levels
    local first = 1
    for i, e in ipairs(list) do if e.state == "next" then first = i break end end
    if first == 1 and list[#list] and list[#list].state == "done" then first = #list end
    first = math.max(1, first - 3)
    if self.levelOffset then first = self.levelOffset end
    first = math.max(1, math.min(first, #list - (MAX_LINES - 2)))
    self.lastFirst, out.levelFirst = first, first
    out.lines = { GOLD .. FF:T("By level: %s"):format(build.name) .. "|r" }
    out.tabs, out.steps = {}, {}
    for i = first, #list do
      local e = list[i]
      out.lines[#out.lines + 1] = self:LevelLine(e, p.level)
      out.tabs[#out.lines] = e.tab
      out.steps[#out.lines] = { name = e.name, tab = e.tab, index = e.index, treeName = e.treeName, order = e.level,
                                cur = e.cur, target = e.rank, state = e.state, level = e.level }
    end
    if #list < (self.LAST_LEVEL - self.FIRST_LEVEL + 1) then
      out.lines[#out.lines + 1] = GREY .. FF:T("L%d+  free points: the build is complete"):format(self.FIRST_LEVEL + #list) .. "|r"
    end
  end
  local nextStep
  for _, s in ipairs(plan.steps) do if s.state == "next" then nextStep = s break end end
  if nextStep and nextStep.needPoints and nextStep.needPoints > 0 then
    out.note = FF:T("Spend %d more points in %s to reach %s."):format(nextStep.needPoints,
      (plan.treeNames and plan.treeNames[nextStep.tab]) or FF:T("this tree"), nextStep.name)
  elseif nextStep and nextStep.tab and plan.treeNames and plan.treeNames[nextStep.tab] then
    out.note = FF:T("Next point: %s in %s."):format(nextStep.name, plan.treeNames[nextStep.tab])
  elseif #plan.steps > 0 and plan.done == #plan.steps then
    out.note = FF:T("Build complete.")
  else
    out.note = build.note or ""
  end
  -- points that drifted off the build go first, so they're seen
  out.drift = self:DriftLine(build, plan)
  if out.drift then out.note = out.drift .. (out.note ~= "" and ("\n" .. out.note) or "") end
  if out.behind and not out.drift then out.note = out.behind .. (out.note ~= "" and ("\n" .. out.note) or "") end
  return out
end

function TO:Refresh()
  local f = self:GameFrame()
  if not (f and f.IsShown and f:IsShown()) then
    if panel then panel:Hide() end
    return
  end
  if not self:Enabled() then
    self:Decorate({ steps = {} })
    if panel then panel:Hide() end
    return
  end
  local text = self:PanelText()
  if next((self:Trees())) == nil then pcall(self.Probe, self, f, select(2, self:GameFrame())) end
  self:Decorate(text.plan or { steps = {} })
  local pn = self:Panel(f)
  pn.build:SetText(text.build or "")
  pn.view:SetText(text.view == "levels" and FF:T("Order") or FF:T("By level"))
  if text.levels then pn.view:Show() else pn.view:Hide() end
  pn.points:SetText(text.points or "")
  pn.role:SetText(text.role or "")
  pn.bands1:SetText(text.bands1 or "")
  pn.bands2:SetText(text.bands2 or "")
  pn.rotation:SetText(text.rotation or "")
  for i = 1, MAX_LINES do
    local l = text.lines[i]
    if i == MAX_LINES and #text.lines > MAX_LINES then l = GREY .. FF:T("(+%d more)"):format(#text.lines - MAX_LINES + 1) .. "|r" end
    pn.lines[i]:SetText(l or "")
    local shown = i < MAX_LINES or #text.lines <= MAX_LINES
    pn.rows[i].tab = shown and text.tabs and text.tabs[i] or nil
    pn.rows[i].step = shown and text.steps and text.steps[i] or nil
  end
  pn.note:SetText(text.note or "")
  pn:Show()
end

-- tooltip of a panel line: the talent's description from the game, then the build's details
function TO:RowTooltip(row)
  local s = row and row.step
  if not (s and GameTooltip) then return false end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  local described = false
  if s.tab and s.index and GameTooltip.SetTalent then
    described = pcall(GameTooltip.SetTalent, GameTooltip, s.tab, s.index)
  end
  if not described then GameTooltip:AddLine(s.name, 1, 1, 1) end
  if s.treeName then GameTooltip:AddLine(s.treeName, 0.6, 0.6, 0.6) end
  if s.state == "missing" then
    GameTooltip:AddLine(FF:T("Not in this game version's talent trees."), 0.6, 0.6, 0.6, true)
  else
    GameTooltip:AddLine(self:TooltipLine(s), 1, 0.82, 0)
    if s.needPoints and s.needPoints > 0 then
      GameTooltip:AddLine(FF:T("Spend %d more points in this tree first."):format(s.needPoints), 1, 1, 1, true)
    end
    GameTooltip:AddLine(FF:T("Click to open this tree."), 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
  return true
end

-- switch the Talents window to a tree, the same as clicking its tab (outside fights only)
function TO:ShowTree(tab)
  if InCombatLockdown and InCombatLockdown() then return false end
  local f, fname = self:GameFrame()
  if not f then return false end
  if self:SelectedTab(f) == tab then return true end
  local tb = _G[fname .. "Tab" .. tab]
  if not (tb and tb.Click) then return false end
  tb:Click()
  self:Refresh()
  return true
end

-- /ff talents: open (or close) the game's Talents window
function TO:Open()
  local ok, level = pcall(UnitLevel, "player")
  if ok and tonumber(level) and tonumber(level) < 10 then FF:Print(FF:T("Talents start at level 10.")) return false end
  local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
  if not self:GameFrame() and load then
    for _, a in ipairs(TALENT_ADDONS) do pcall(load, a) end
  end
  self:Hook()
  -- the game's own ways first (they differ between clients), then the frame itself, then the
  -- Talents key binding, which every client has
  local util = type(PlayerSpellsUtil) == "table" and PlayerSpellsUtil.ToggleClassTalentOrSpecFrame
  for _, fn in ipairs({ ToggleTalentFrame, util, ToggleClassTalentFrame, TogglePlayerSpellsFrame }) do
    if type(fn) == "function" and pcall(fn) then self:AfterOpen() return true end
  end
  local f = self:GameFrame()
  if f and ShowUIPanel then
    if f:IsShown() then HideUIPanel(f) else ShowUIPanel(f) end
    self:AfterOpen()
    return true
  end
  if type(RunBinding) == "function" and pcall(RunBinding, "TOGGLETALENTS") then
    self:AfterOpen()
    return true
  end
  FF:Print(FF:T("The Talents window could not be opened - press your Talents key (N)."))
  return false
end

-- What this client offers for talents, saved once per session in FlipForeverDB.talentProbe when
-- the classic talent functions return nothing (WoW: Forever has its own Talents window). Read
-- from the SavedVariables to learn how to read this client's talents.
function TO:Probe(frame, frameName)
  if self.probed or not FlipForeverDB then return end
  self.probed = true
  local function dump(...)
    local n, out = select("#", ...), {}
    for i = 1, math.min(n, 16) do out[i] = tostring((select(i, ...))) end
    return table.concat(out, " | ")
  end
  local function call(fn, ...)
    if type(fn) ~= "function" then return "missing" end
    return dump(pcall(fn, ...))
  end
  local p = { t = time and time() or 0, frame = frameName }
  p.numTabs = call(GetNumTalentTabs)
  p.tabInfo1 = call(GetTalentTabInfo, 1)
  p.numTalents1 = call(GetNumTalents, 1)
  p.info11 = call(GetTalentInfo, 1, 1)
  p.info11g = call(GetTalentInfo, 1, 1, false, false, 1)
  p.group = call(GetActiveTalentGroup)
  local fns, tabs = {}, {}
  local names = {}
  for name in pairs(_G) do if type(name) == "string" then names[#names + 1] = name end end
  for _, name in ipairs(names) do
    local v = rawget(_G, name)
    if type(name) == "string" and name:find("Talent") then
      if type(v) == "function" and #fns < 80 then fns[#fns + 1] = name end
    end
    if type(name) == "string" and name:find("^C_") and type(v) == "table" and #tabs < 80 then
      local keys = {}
      for k, f in pairs(v) do if type(k) == "string" and k:find("Talent") then keys[#keys + 1] = k end end
      if #keys > 0 or name:find("Talent") or name:find("Trait") or name:find("Spec") then
        table.sort(keys)
        tabs[#tabs + 1] = name .. ": " .. table.concat(keys, ",", 1, math.min(#keys, 20))
      end
    end
  end
  table.sort(fns) table.sort(tabs)
  p.functions, p.tables = fns, tabs
  -- the window's children two levels down: name, type, ID (talent buttons show up here)
  local kids = {}
  local function walk(f, depth, path)
    if depth > 3 or #kids >= 60 or type(f) ~= "table" or type(f.GetChildren) ~= "function" then return end
    local okC, list = pcall(function() return { f:GetChildren() } end)
    if not okC then return end
    for i, c in ipairs(list) do
      local okN, nm = pcall(c.GetName, c)
      local okT, ty = pcall(c.GetObjectType, c)
      local id = (type(c.GetID) == "function") and select(2, pcall(c.GetID, c)) or nil
      local keys = {}
      for k, v in pairs(c) do if type(k) == "string" and type(v) ~= "function" and #keys < 8 then keys[#keys + 1] = k end end
      kids[#kids + 1] = ("%s%d %s %s id=%s keys=%s"):format(path, i, tostring(okN and nm), tostring(okT and ty), tostring(id), table.concat(keys, ","))
      walk(c, depth + 1, path .. i .. ".")
      if #kids >= 60 then return end
    end
  end
  walk(frame, 1, "")
  p.children = kids
  FlipForeverDB.talentProbe = p
end

-- after opening: find the window if its name is new to us, hook it and show the panel
function TO:AfterOpen()
  if not self:GameFrame() then self:FindFrame() end
  self:Hook()
  self:Refresh()
end

-- Hooks: the Talents window is load-on-demand -----------------------------------------------------
local hooked = false
function TO:Hook()
  local f = self:GameFrame()
  if hooked or not f then return false end
  hooked = true
  if f.HookScript then
    f:HookScript("OnShow", function() TO:Refresh() end)
    f:HookScript("OnHide", function() if panel then panel:Hide() end end)
  end
  for _, fn in ipairs({ "TalentFrame_Update", "PlayerTalentFrame_Update", "PlayerTalentFrame_Refresh" }) do
    if type(_G[fn]) == "function" then hooksecurefunc(_G, fn, function() TO:Refresh() end) end
  end
  return true
end

FF:On("ADDON_LOADED", function(name)
  if type(name) == "string" and (name:find("Talent") or name:find("PlayerSpells")) then
    if not TO:GameFrame() then TO:FindFrame() end
    TO:Hook() TO:Refresh()
  end
end)
FF:On("PLAYER_LOGIN", function()
  if not TO:GameFrame() then pcall(TO.FindFrame, TO) end
  TO:Hook()
end)
for _, ev in ipairs({ "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP" }) do
  FF:On(ev, function() if hooked then TO:Refresh() end end)
end

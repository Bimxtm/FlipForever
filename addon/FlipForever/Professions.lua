-- FlipForever Profession planner (self-contained, no other addon needed).
--
-- When you open a profession window, FlipForever reads the game's own recipe data (every
-- recipe, its difficulty colour, its materials and what it makes) and remembers it per
-- character. The planner then ranks crafts by cost per skill-up:
--     (materials - what the result sells for) / chance to skill up
-- with prices from FlipForever's own auction scans (vendor price as a fallback), and lists
-- the materials you're missing. "Buy missing mats" hands them to the auction house buyer
-- (one key press per purchase, never above the price limit).
local FF = FlipForever
local P = {}
FF.Professions = P

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

-- skill-up chance by difficulty colour (classic formula, averaged over each colour band)
P.CHANCE = { [0] = 1.0, [1] = 0.75, [2] = 0.25, [3] = 0 }
P.COLOR = { [0] = "|cffff8040orange|r", [1] = "|cffffff00yellow|r", [2] = "|cff40c040green|r", [3] = "|cff808080grey|r" }
local POINTS_PER_STEP = 5

function P:Store()
  local s = FF.Advisor:CharStore()
  s.professions = s.professions or {}
  return s.professions
end

-- Capture -----------------------------------------------------------------------------------------
function P:Capture()
  local TS = C_TradeSkillUI
  if not (TS and TS.GetAllRecipeIDs and TS.GetRecipeInfo) then return nil end
  if TS.IsTradeSkillLinked and TS.IsTradeSkillLinked() then return nil end -- someone else's link
  if TS.IsTradeSkillGuild and TS.IsTradeSkillGuild() then return nil end
  local info = TS.GetBaseProfessionInfo and TS.GetBaseProfessionInfo()
  local name = info and plain(info.professionName)
  if not name then return nil end
  local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
  local recipes = {}
  for _, rid in ipairs(TS.GetAllRecipeIDs() or {}) do
    local r = TS.GetRecipeInfo(rid)
    local rname = r and plain(r.name)
    if rname then
      local e = { id = rid, name = rname, learned = r.learned and true or false, diff = plain(r.relativeDifficulty), mats = {} }
      local ok, sch = pcall(TS.GetRecipeSchematic, rid, false)
      if ok and sch then
        e.out = plain(sch.outputItemID)
        e.outQty = plain(sch.quantityMin) or 1
        for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
          local req = plain(slot.quantityRequired) or 0
          local rg = slot.reagents and slot.reagents[1]
          local isBasic = (basic == nil or slot.reagentType == nil or slot.reagentType == basic)
          if isBasic and req > 0 and rg and plain(rg.itemID) then e.mats[#e.mats + 1] = { rg.itemID, req } end
        end
      end
      recipes[#recipes + 1] = e
    end
  end
  self:Store()[name] = { skill = plain(info.skillLevel) or 0, max = plain(info.maxSkillLevel) or 0, t = time(), recipes = recipes }
  self.current = name
  return name
end

-- Prices --------------------------------------------------------------------------------------------
local function vendorSell(id)
  local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not fn then return nil end
  local info = { pcall(fn, id) }
  if not info[1] then return nil end
  table.remove(info, 1)
  local p = plain(info[11])
  return (type(p) == "number" and p > 0) and p or nil
end

-- what one unit of a material costs you: auction price, else ~4x its vendor sell price
-- (vendor goods like thread and vials usually cost about that)
function P:UnitCost(id)
  local p = FF:PriceOf(id)
  if p then return p, "ah" end
  -- something you make yourself (e.g. Bolt of Linen Cloth): what its own materials cost
  if self.craftCost and self.craftCost[id] then return self.craftCost[id], "crafted" end
  local sell = vendorSell(id)
  if sell then return sell * 4, "vendor" end
  return nil, nil
end

-- what the result is worth to you: auction price after the 5% cut, else its vendor price
function P:ItemValue(id)
  if not id then return 0 end
  local p = FF:PriceOf(id)
  if p then return math.floor(p * 0.95) end
  return vendorSell(id) or 0
end

-- Plan ------------------------------------------------------------------------------------------------
function P:Plan(profName)
  local data = self:Store()[profName]
  if not data then return {}, nil end
  -- cost of things this profession can make itself (one level deep is enough for 1-300)
  self.craftCost = {}
  for _, r in ipairs(data.recipes) do
    if r.learned and r.out and not FF:PriceOf(r.out) and #r.mats > 0 then
      local cost, ok = 0, true
      for _, m in ipairs(r.mats) do
        local unit = FF:PriceOf(m[1])
        if unit then cost = cost + unit * m[2] else ok = false end
      end
      if ok then self.craftCost[r.out] = cost / (r.outQty or 1) end
    end
  end
  local recs = {}
  for _, r in ipairs(data.recipes) do
    local chance = P.CHANCE[r.diff or 3] or 0
    if chance > 0 and #r.mats > 0 then
      local cost, unknown = 0, false
      for _, m in ipairs(r.mats) do
        local unit = self:UnitCost(m[1])
        if unit then cost = cost + unit * m[2] else unknown = true end
      end
      local value = self:ItemValue(r.out) * (r.outQty or 1)
      local net = cost - value
      recs[#recs + 1] = { recipe = r, chance = chance, cost = cost, value = value, net = net,
        perPoint = net / chance, unknown = unknown, learnable = not r.learned,
        crafts = math.min(math.ceil(POINTS_PER_STEP / chance), math.max(1, math.ceil(((data.max or 300) - (data.skill or 0)) / chance))) }
    end
  end
  table.sort(recs, function(a, b)
    if a.unknown ~= b.unknown then return not a.unknown end
    if a.learnable ~= b.learnable then return not a.learnable end -- what you already know first...
    return a.perPoint < b.perPoint
  end)
  -- ...unless an unlearned recipe is much cheaper: then it's worth the trainer visit
  local bestKnown, bestNew
  for _, r in ipairs(recs) do
    if not r.unknown then
      if r.learnable then bestNew = bestNew or r else bestKnown = bestKnown or r end
    end
  end
  if bestNew and (not bestKnown or bestNew.perPoint < bestKnown.perPoint * 0.7) then
    for i, r in ipairs(recs) do if r == bestNew then table.remove(recs, i) break end end
    table.insert(recs, 1, bestNew)
  end
  return recs, data
end

-- materials still needed for `crafts` crafts of a recommendation (bags + bank counted)
function P:Missing(rec, crafts)
  local out = {}
  for _, m in ipairs(rec.recipe.mats) do
    local need = m[2] * (crafts or rec.crafts)
    local have = (C_Item.GetItemCount and C_Item.GetItemCount(m[1], true)) or 0
    local unit, source = self:UnitCost(m[1])
    out[#out + 1] = { id = m[1], need = need, have = have, missing = math.max(0, need - have), unit = unit, source = source }
  end
  return out
end

-- the auction house buy list for the top crafts (vendor goods are left for the vendor)
function P:BuyList(profName, howMany)
  local recs = self:Plan(profName)
  local merged, order = {}, {}
  for i = 1, math.min(howMany or 1, #recs) do
    if not recs[i].learnable and not recs[i].unknown then
      for _, m in ipairs(self:Missing(recs[i])) do
        if m.missing > 0 and m.source == "ah" then
          if not merged[m.id] then merged[m.id] = { id = m.id, qty = 0, max = math.floor(m.unit * 1.25) } order[#order + 1] = m.id end
          merged[m.id].qty = merged[m.id].qty + m.missing
        end
      end
    end
  end
  local list = {}
  for _, id in ipairs(order) do list[#list + 1] = merged[id] end
  return list
end

-- the top step, in words (the Advisor shows this)
function P:TopStep(profName)
  local recs, data = self:Plan(profName)
  local r = recs[1]
  if not r or not data then return nil end
  local what = r.learnable and ("learn %s at the trainer, then craft it"):format(r.recipe.name)
    or ("craft %dx %s"):format(r.crafts, r.recipe.name)
  local price = r.unknown and "price unknown" or ((r.perPoint <= 0 and "makes a profit" or ("~" .. FF:Money(r.perPoint) .. " per skill-up")))
  return ("%s %d/%d: %s (%s)"):format(profName, data.skill, data.max, what, price)
end

-- Panel -------------------------------------------------------------------------------------------------
local frame
local ROWS = 6

local function professionFrame()
  return (ProfessionsFrame and ProfessionsFrame:IsShown() and ProfessionsFrame)
      or (TradeSkillFrame and TradeSkillFrame:IsShown() and TradeSkillFrame) or nil
end

local function build()
  local f = CreateFrame("Frame", "FlipForeverProfPlanner", UIParent, "BackdropTemplate")
  f:SetSize(380, 430)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  f:SetBackdropColor(0.05, 0.06, 0.08, 0.96)
  f:SetBackdropBorderColor(0.2, 0.8, 0.5, 1)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    FlipForeverDB.settings.profPos = { point, relPoint, x, y }
  end)
  tinsert(UISpecialFrames, "FlipForeverProfPlanner")
  CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", 2, 2)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOPLEFT", 14, -12)
  f.prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.prev:SetSize(24, 20)
  f.prev:SetPoint("TOPLEFT", 14, -38)
  f.prev:SetText("<")
  f.prev:SetScript("OnClick", function() P:Cycle(-1) end)
  f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.next:SetSize(24, 20)
  f.next:SetPoint("LEFT", f.prev, "RIGHT", 4, 0)
  f.next:SetText(">")
  f.next:SetScript("OnClick", function() P:Cycle(1) end)
  f.prof = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.prof:SetPoint("LEFT", f.next, "RIGHT", 8, 0)
  f.prof:SetPoint("RIGHT", f, "RIGHT", -14, 0)
  f.prof:SetJustifyH("LEFT")

  local h1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h1:SetPoint("TOPLEFT", 14, -68)
  h1:SetText("Cheapest skill-ups")
  f.rows = {}
  for i = 1, ROWS do
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 16, -70 - i * 20)
    fs:SetPoint("RIGHT", -14, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    f.rows[i] = fs
  end
  local h2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h2:SetPoint("TOPLEFT", 14, -70 - (ROWS + 1) * 20)
  h2:SetText("Materials for the top craft")
  f.mats = {}
  for i = 1, 6 do
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 16, -72 - (ROWS + 1 + i) * 18)
    fs:SetPoint("RIGHT", -14, 0)
    fs:SetJustifyH("LEFT")
    f.mats[i] = fs
  end
  f.buy = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.buy:SetSize(200, 24)
  f.buy:SetPoint("BOTTOMLEFT", 14, 14)
  f.buy:SetText("Buy missing mats at the AH")
  f.buy:SetScript("OnClick", function() P:QueueMats() end)
  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.hint:SetPoint("BOTTOMLEFT", 14, 44)
  f.hint:SetPoint("RIGHT", -14, 0)
  f.hint:SetJustifyH("LEFT")
  f:Hide()
  return f
end

function P:Cycle(step)
  local names = {}
  for name in pairs(self:Store()) do names[#names + 1] = name end
  table.sort(names)
  if #names == 0 then return end
  local idx = 1
  for i, n in ipairs(names) do if n == self.current then idx = i end end
  self.current = names[(idx - 1 + step) % #names + 1]
  self:Refresh()
end

function P:Refresh()
  if not (frame and frame:IsShown()) then return end
  frame.title:SetText("|cff33ff99Flip|rForever Profession planner")
  if not self.current then
    for name in pairs(self:Store()) do self.current = name break end
  end
  local recs, data = self:Plan(self.current or "")
  if not data then
    frame.prof:SetText("Open a profession window once - FlipForever reads its recipes.")
    for _, fs in ipairs(frame.rows) do fs:SetText("") end
    for _, fs in ipairs(frame.mats) do fs:SetText("") end
    frame.hint:SetText("")
    return
  end
  frame.prof:SetText(("%s  %d / %d  |cff888888(read %s)|r"):format(self.current, data.skill, data.max,
    date("%H:%M", data.t)))
  for i, fs in ipairs(frame.rows) do
    local r = recs[i]
    if r then
      local cost = r.unknown and "|cff888888price unknown|r"
        or (r.perPoint <= 0 and ("|cff33ff99+" .. FF:Money(-r.perPoint) .. " profit|r") or (FF:Money(r.perPoint) .. " / point"))
      fs:SetText(("%s%dx %s  %s  ·  %s"):format(r.learnable and "|cffffd200[trainer]|r " or "", r.crafts, r.recipe.name,
        P.COLOR[r.recipe.diff or 3], cost))
    else
      fs:SetText(i == 1 and "Nothing left that can skill up - visit your trainer for new recipes." or "")
    end
  end
  local top = recs[1]
  local missing = top and self:Missing(top) or {}
  for i, fs in ipairs(frame.mats) do
    local m = missing[i]
    if m then
      local src = (m.source == "vendor" and " |cff888888(vendor)|r") or (m.source == "crafted" and " |cff888888(craft it)|r") or ""
      local color = m.missing > 0 and "|cffff8080" or "|cff80ff80"
      fs:SetText(("%s  %s%d / %d|r  %s%s"):format(FF:ItemName(m.id), color, m.have, m.need,
        m.unit and FF:Money(m.unit) or "?", src))
    else
      fs:SetText("")
    end
  end
  frame.hint:SetText("Chance to skill up: orange 100%, yellow ~75%, green ~25%. Prices: FlipForever's scans, vendor goods ~4x sell price.")
end

function P:QueueMats()
  local list = self:BuyList(self.current, 1)
  if #list == 0 then
    FF:Print("Nothing to buy at the auction house for the top craft (you have it all, or it's vendor goods).")
    return
  end
  self.pendingMats = list
  FF:Print(("%d material%s queued. At the auction house, click |cffffd200Buy profession mats|r on the FlipForever panel."):format(#list, #list > 1 and "s" or ""))
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() then self:BuyPending() end
  if FF.UI then FF.UI:Refresh() end
end

function P:BuyPending()
  if not self.pendingMats then return end
  local list = self.pendingMats
  self.pendingMats = nil
  FF.Trader:StartBuying(list, "profession mats")
end

function P:Show()
  frame = frame or build()
  frame:ClearAllPoints()
  local pf = professionFrame()
  local pos = FlipForeverDB.settings.profPos
  if pf then frame:SetPoint("TOPLEFT", pf, "TOPRIGHT", 4, 0)
  elseif pos then frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else frame:SetPoint("CENTER", 200, 40) end
  frame:Show()
  self:Refresh()
end

function P:Toggle()
  if frame and frame:IsShown() then frame:Hide() else self:Show() end
end

-- Events --------------------------------------------------------------------------------------------------
local pending = false
local function recapture()
  if pending then return end
  pending = true
  C_Timer.After(0.5, function()
    pending = false
    if pcall(P.Capture, P) then P:Refresh() end
  end)
end

FF:On("TRADE_SKILL_SHOW", function()
  recapture()
  if FlipForeverDB.settings.profPanel ~= false then C_Timer.After(0.6, function() P:Show() end) end
end)
pcall(FF.On, FF, "TRADE_SKILL_LIST_UPDATE", recapture)
pcall(FF.On, FF, "TRADE_SKILL_DATA_SOURCE_CHANGED", recapture)
FF:On("TRADE_SKILL_CLOSE", function()
  if frame and frame:IsShown() and FlipForeverDB.settings.profPanel ~= false then frame:Hide() end
end)
FF:On("BAG_UPDATE_DELAYED", function() P:Refresh() end)

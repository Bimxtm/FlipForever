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
  local skill = plain(info.skillLevel) or 0
  self:LearnThresholds(self:Store()[name], recipes, skill)
  self:Store()[name] = { skill = skill, max = plain(info.maxSkillLevel) or 0, t = time(), recipes = recipes }
  self.current = name
  if FF.Cooldowns then pcall(FF.Cooldowns.Read, FF.Cooldowns, recipes) end
  return name
end

-- Exact skill-up chances -------------------------------------------------------------------------
-- The game only tells us a recipe's colour. When a recipe changes colour between two reads, the
-- skill at that moment is where its yellow / green / grey band starts. With those, the classic
-- formula gives the real chance: (grey - skill) / (grey - yellow). Shared by all characters.
local BAND = { [1] = "yellow", [2] = "green", [3] = "grey" }

function P:Thresholds()
  FlipForeverDB.recipeThresholds = FlipForeverDB.recipeThresholds or {}
  return FlipForeverDB.recipeThresholds
end

function P:LearnThresholds(prev, recipes, skill)
  if not (prev and prev.recipes) or (prev.skill or 0) >= skill then return end
  local old = {}
  for _, r in ipairs(prev.recipes) do old[r.id] = r.diff end
  local T = self:Thresholds()
  for _, r in ipairs(recipes) do
    local before, now = old[r.id], r.diff
    if before and now and now > before then
      local t = T[r.id] or {}
      -- it changed somewhere between the two reads: only an exact step of one band is trusted
      if now - before == 1 and skill - (prev.skill or 0) <= 1 then t[BAND[now]] = skill
      elseif not t[BAND[now]] then t[BAND[now] .. "Max"] = skill end
      T[r.id] = t
    end
  end
end

function P:Chance(r, skill)
  local diff = r.diff or 3
  if diff == 0 then return 1.0 end
  if diff >= 3 then return 0 end
  local t = self:Thresholds()[r.id]
  if t then
    local yellow, green, grey = t.yellow, t.green, t.grey
    if not grey and yellow and green then grey = green + (green - yellow) end -- bands are evenly spaced
    if grey and t.greyMax and grey > t.greyMax then grey = t.greyMax end      -- seen grey by then at the latest
    if grey and yellow and grey > yellow then
      return math.max(0.05, math.min(1, (grey - skill) / (grey - yellow))), true
    end
  end
  return P.CHANCE[diff] or 0, false
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
  -- new realm without scans: the other realm's price (never bought from: buy lists take "ah" only)
  local e = FF:EstimateOf(id)
  if e then return e, "estimate" end
  local sell = vendorSell(id)
  if sell then return sell * 4, "vendor" end
  return nil, nil
end

-- marks the planner while its prices are estimates from another realm ("" otherwise)
function P:EstimateNote()
  local realm = FF:EstimateRealm()
  if not realm then return "" end
  return "  " .. FF:T("|cffff8800(estimates from %s until you scan here)|r"):format(realm)
end

-- what the result is worth to you: auction price after the 5% cut, else its vendor price
function P:ItemValue(id)
  if not id then return 0 end
  local p = FF:PlanPriceOf(id)
  if p then return math.floor(p * 0.95) end
  return vendorSell(id) or 0
end

-- Crafting cost for tooltips (switch craftCostTooltip) -------------------------------------------------
-- What one item costs to make from a recipe this character knows, materials at scanned prices
-- (vendor goods ~4x their sell price). Returns cost, recipe name, profession, and true when a
-- material has no price (the cost is then a lower bound). nil when no known recipe makes it.
function P:CraftCostOf(itemID)
  if not itemID or FlipForeverDB.settings.craftCostTooltip == false then return nil end
  local best
  for prof, data in pairs(self:Store()) do
    for _, r in ipairs(data.recipes or {}) do
      if r.learned and r.out == itemID and #r.mats > 0 then
        local cost, unknown = 0, false
        for _, m in ipairs(r.mats) do
          local unit, how = self:UnitCost(m[1])
          if unit and how ~= "crafted" then cost = cost + unit * m[2] else unknown = true end
        end
        cost = math.floor(cost / (r.outQty or 1) + 0.5)
        if not best or (best.unknown and not unknown) or (best.unknown == unknown and cost < best.cost) then
          best = { cost = cost, name = r.name, prof = prof, unknown = unknown }
        end
      end
    end
  end
  if not best or best.cost <= 0 then return nil end
  return best.cost, best.name, best.prof, best.unknown
end

-- Plan ------------------------------------------------------------------------------------------------
function P:Plan(profName)
  local data = self:Store()[profName]
  if not data then return {}, nil end
  -- cost of things this profession can make itself (one level deep is enough for 1-300)
  self.craftCost, self.craftRecipe = {}, {}
  for _, r in ipairs(data.recipes) do
    if r.learned and r.out and #r.mats > 0 then self.craftRecipe[r.out] = r end
    if r.learned and r.out and not FF:PriceOf(r.out) and #r.mats > 0 then
      local cost, ok = 0, true
      for _, m in ipairs(r.mats) do
        local unit = FF:PlanPriceOf(m[1])
        if unit then cost = cost + unit * m[2] else ok = false end
      end
      if ok then self.craftCost[r.out] = cost / (r.outQty or 1) end
    end
  end
  local recs = {}
  for _, r in ipairs(data.recipes) do
    local chance, exact = self:Chance(r, data.skill or 0)
    if chance > 0 and #r.mats > 0 then
      local cost, unknown = 0, false
      for _, m in ipairs(r.mats) do
        local unit = self:UnitCost(m[1])
        if unit then cost = cost + unit * m[2] else unknown = true end
      end
      local value = self:ItemValue(r.out) * (r.outQty or 1)
      local net = cost - value
      recs[#recs + 1] = { recipe = r, chance = chance, exact = exact, cost = cost, value = value, net = net,
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

-- Crafting for profit -----------------------------------------------------------------------------------
-- Crafts you know whose result sells for more than the materials cost, after the AH cut and a
-- deposit allowance. Only results that sell fast (same "sells per day" rule as flipping), and
-- never more than you can sell in about two days.
P.DEPOSIT = 0.015

function P:ProfitList(profName)
  local s = FlipForeverDB.settings
  local minPerDay = s.craftMinPerDay or 3
  local minMargin = s.craftMinMargin or 0.10
  local names = {}
  if profName then names[1] = profName else for name in pairs(self:Store()) do names[#names + 1] = name end end
  table.sort(names)
  local out, seen = {}, {}
  for _, prof in ipairs(names) do
    local data = self:Store()[prof]
    if data then
      self:Plan(prof) -- fills craftCost / craftRecipe for things you make yourself
      for _, r in ipairs(data.recipes) do
        local price = r.learned and r.out and #r.mats > 0 and FF:PlanPriceOf(r.out)
        if price and not seen[r.id] then
          seen[r.id] = true
          local cost, unknown = 0, false
          for _, m in ipairs(r.mats) do
            local unit = self:UnitCost(m[1])
            if unit then cost = cost + unit * m[2] else unknown = true end
          end
          local qty = r.outQty or 1
          local value = math.floor(price * qty * (1 - 0.05 - P.DEPOSIT))
          local profit = value - cost
          local perDay = FF.Planner and FF.Planner:SellsPerDay(r.out)
          local margin = cost > 0 and profit / cost or 0
          if not unknown and profit > 0 and margin >= minMargin and perDay and perDay >= minPerDay then
            -- about half the market's sales over ~2 days, at most 20 crafts
            local crafts = math.max(1, math.min(20, math.floor(perDay * 0.5 * 2 / qty)))
            out[#out + 1] = { recipe = r, prof = prof, cost = cost, value = value, profit = profit, margin = margin,
              perDay = perDay, crafts = crafts, total = profit * crafts }
          end
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.recipe.id < b.recipe.id
  end)
  return out
end

-- auction house buy list for the top profitable crafts (what you don't already have)
function P:ProfitBuyList(profName, howMany)
  local list, merged = {}, {}
  for i, e in ipairs(self:ProfitList(profName)) do
    if i > (howMany or 1) then break end
    self:Plan(e.prof)
    for _, m in ipairs(self:Missing({ recipe = e.recipe, crafts = e.crafts })) do
      if m.missing > 0 and m.source == "ah" and m.unit then
        local entry = merged[m.id]
        if not entry then
          entry = { id = m.id, qty = 0, max = math.floor(m.unit * 1.25) }
          merged[m.id] = entry
          list[#list + 1] = entry
        end
        entry.qty = entry.qty + m.missing
      end
    end
  end
  return list
end

-- can you gather this yourself? (ores/herbs the Gathering module knows, and you have the skill)
function P:Gatherable(id)
  local ns = FF.gatherNS
  if not (ns and ns.ItemToOre and ns.OreByKey and ns.GetSkill and ns.db) then return false end
  local key = ns.ItemToOre[id]
  local def = key and ns.OreByKey[key]
  if not def then return false end
  local ok, skill, src = pcall(ns.GetSkill, def.cat)
  if not ok or src == "none" then return false end
  return skill == nil or (def.skill or 0) <= skill
end

local function have(id)
  return (C_Item.GetItemCount and C_Item.GetItemCount(id, true)) or 0
end

-- materials still needed for `crafts` crafts of a recommendation (bags + bank counted).
-- Things you craft yourself (bolts, bars...) also list *their* materials.
function P:Missing(rec, crafts)
  local out = {}
  for _, m in ipairs(rec.recipe.mats) do
    local need = m[2] * (crafts or rec.crafts)
    local got = have(m[1])
    local unit, source = self:UnitCost(m[1])
    local entry = { id = m[1], need = need, have = got, missing = math.max(0, need - got), unit = unit, source = source,
      gather = self:Gatherable(m[1]) }
    out[#out + 1] = entry
    local sub = source == "crafted" and self.craftRecipe and self.craftRecipe[m[1]]
    if sub and entry.missing > 0 then
      local times = math.ceil(entry.missing / (sub.outQty or 1))
      for _, s in ipairs(sub.mats) do
        local sneed = s[2] * times
        local sgot = have(s[1])
        local sunit, ssource = self:UnitCost(s[1])
        out[#out + 1] = { id = s[1], need = sneed, have = sgot, missing = math.max(0, sneed - sgot), unit = sunit,
          source = ssource, via = sub.name, gather = self:Gatherable(s[1]) }
      end
    end
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
  local f = FF:Window("FlipForeverProfPlanner", 470, 470, { pos = "profPos" })

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOPLEFT", 14, -12)
  f.prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.prev:SetSize(24, 20)
  f.prev:SetPoint("TOPLEFT", 14, -38)
  f.prev:SetText(FF:T("<"))
  f.prev:SetScript("OnClick", function() P:Cycle(-1) end)
  f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.next:SetSize(24, 20)
  f.next:SetPoint("LEFT", f.prev, "RIGHT", 4, 0)
  f.next:SetText(FF:T(">"))
  f.next:SetScript("OnClick", function() P:Cycle(1) end)
  f.prof = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.prof:SetPoint("LEFT", f.next, "RIGHT", 8, 0)
  f.prof:SetPoint("RIGHT", f, "RIGHT", -14, 0)
  f.prof:SetJustifyH("LEFT")

  f.h1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.h1:SetPoint("TOPLEFT", 14, -68)
  f.h1:SetJustifyH("LEFT")
  f.h1:SetWordWrap(false)
  f.h1:SetText(FF:T("Cheapest skill-ups"))
  f.mode = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.mode:SetSize(130, 20)
  f.mode:SetPoint("TOPRIGHT", -14, -64)
  f.h1:SetPoint("RIGHT", f.mode, "LEFT", -8, 0)
  f.mode:SetScript("OnClick", function() P:SetMode(P.mode == "profit" and "skill" or "profit") end)
  f.rows = {}
  for i = 1, ROWS do
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 16, -72 - i * 20)
    fs:SetPoint("RIGHT", -14, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    f.rows[i] = fs
  end
  f.h2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  -- materials sit below the last row with a clear gap (the header used to overlap the first material)
  local matTop = -72 - ROWS * 20 - 30
  f.h2:SetPoint("TOPLEFT", 14, matTop)
  f.h2:SetText(FF:T("Materials for the top craft"))
  f.mats = {}
  for i = 1, 6 do
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 16, matTop - 4 - i * 18)
    fs:SetPoint("RIGHT", -14, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    f.mats[i] = fs
  end
  f.buy = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.buy:SetSize(200, 24)
  f.buy:SetPoint("BOTTOMLEFT", 14, 14)
  f.buy:SetText(FF:T("Buy missing mats at the AH"))
  f.buy:SetScript("OnClick", function() if P.mode == "profit" then P:QueueProfitMats() else P:QueueMats() end end)
  -- Craft button (switch craftButton): crafts the top skill-up or profitable recipe the planned number of times
  f.craft = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.craft:SetSize(200, 24)
  f.craft:SetPoint("BOTTOMRIGHT", -14, 14)
  f.craft:SetScript("OnClick", function() P:CraftTop() end)
  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.hint:SetPoint("BOTTOMLEFT", 14, 46)
  f.hint:SetPoint("RIGHT", -14, 0)
  f.hint:SetJustifyH("LEFT")
  f:Hide()
  return f
end

function P:CraftEnabled() return FlipForeverDB.settings.craftButton ~= false end

-- the profession whose window is open right now (nil when none)
function P:OpenProfession()
  if not professionFrame() then return nil end
  local TS = C_TradeSkillUI
  local info = TS and TS.GetBaseProfessionInfo and TS.GetBaseProfessionInfo()
  return info and plain(info.professionName)
end

-- what the Craft button makes: recipe, planned count, profession (top entry of the current mode)
function P:CraftTarget()
  if (self.mode or FlipForeverDB.settings.profMode) == "profit" then
    local open = self:OpenProfession()
    for _, e in ipairs(self:ProfitList()) do
      if e.prof == open then return e.recipe, e.crafts, e.prof end
    end
    return nil
  end
  local recs = self:Plan(self.current or "")
  local r = recs and recs[1]
  if not r or r.learnable then return nil end
  return r.recipe, r.crafts, self.current
end

-- how many you can make now from your bags (the game's count), capped at the plan
function P:CraftCount(recipe, planned)
  local TS = C_TradeSkillUI
  local info = TS and TS.GetRecipeInfo and TS.GetRecipeInfo(recipe.id)
  local can = info and plain(info.numAvailable) or 0
  return math.min(planned or 1, can)
end

function P:CraftTop()
  if not self:CraftEnabled() then return false end
  local recipe, planned, prof = self:CraftTarget()
  if not recipe then FF:Print(FF:T("Nothing to craft from the plan right now.")) return false end
  if self:OpenProfession() ~= prof then
    FF:Print(FF:T("Open your %s window to craft."):format(prof or "?")) return false
  end
  local n = self:CraftCount(recipe, planned)
  if n <= 0 then
    FF:Print(FF:T("You don't have the materials for %s - buy them first."):format(recipe.name)) return false
  end
  local TS = C_TradeSkillUI
  if not (TS and TS.CraftRecipe) then return false end
  TS.CraftRecipe(recipe.id, n)
  FF:Print(FF:T("Crafting %dx %s."):format(n, recipe.name))
  return true
end

function P:RefreshCraft()
  local b = frame and frame.craft
  if not b then return end
  if not self:CraftEnabled() then b:Hide() return end
  b:Show()
  local recipe, planned, prof = self:CraftTarget()
  if not recipe then
    b:SetText(FF:T("Nothing to craft"))
    b:SetEnabled(false)
  elseif self:OpenProfession() ~= prof then
    b:SetText(FF:T("Open %s to craft"):format(prof or "?"))
    b:SetEnabled(false)
  else
    local n = self:CraftCount(recipe, planned)
    b:SetText(FF:T("Craft %dx %s"):format(n, recipe.name))
    b:SetEnabled(n > 0)
  end
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

function P:SetMode(mode)
  self.mode = mode
  FlipForeverDB.settings.profMode = mode
  self:Refresh()
end

-- Profit mode: every profession you've opened, best total profit first
function P:RefreshProfit()
  frame.h1:SetText(FF:T("Crafts that sell for more than their materials"))
  frame.h2:SetText(FF:T("Materials for the top craft"))
  frame.mode:SetText(FF:T("Show skill-ups"))
  frame.buy:SetText(FF:T("Buy mats for the top craft"))
  local list = self:ProfitList()
  frame.prof:SetText((#list > 0 and FF:T("%d profitable craft%s across your professions"):format(#list, FF:Plural(#list))
    or "No profitable fast-selling crafts right now.") .. P:EstimateNote())
  for i, fs in ipairs(frame.rows) do
    local e = list[i]
    if e then
      fs:SetText(FF:T("%dx %s  |cff33ff99+%s|r each (%d%%)  ·  sells ~%s a day"):format(e.crafts, e.recipe.name, FF:Money(e.profit),
        math.floor(e.margin * 100 + 0.5), e.perDay >= 10 and ("%d"):format(math.floor(e.perDay + 0.5)) or ("%.1f"):format(e.perDay)))
    else
      fs:SetText(i == 1 and "Open each profession window once so FlipForever knows your recipes; prices come from your scans." or "")
    end
  end
  local top = list[1]
  if top then self:Plan(top.prof) end
  local missing = top and self:Missing({ recipe = top.recipe, crafts = top.crafts }) or {}
  for i, fs in ipairs(frame.mats) do
    local m = missing[i]
    if m then
      local color = m.missing > 0 and "|cffff8080" or "|cff80ff80"
      fs:SetText(FF:T("%s%s  %s%d / %d|r  %s each%s"):format(m.via and "   - " or "", FF:ItemName(m.id), color, m.have, m.need,
        m.unit and FF:Money(m.unit) or "?", m.source == "vendor" and " |cff888888(vendor)|r" or ""))
    else
      fs:SetText(FF:T(""))
    end
  end
  frame.hint:SetText(FF:T("Profit after the 5% auction cut and the deposit. Only crafts that sell at least 3 a day, in amounts that sell within about two days."))
end

function P:QueueProfitMats()
  local list = self:ProfitBuyList(nil, 1)
  if #list == 0 then
    FF:Print(FF:T("Nothing to buy for the top craft (you have the materials, or they come from a vendor)."))
    return
  end
  self.pendingMats = list
  FF:Print(FF:T("%d material%s queued for crafting. At the auction house, click |cffffd200Buy profession mats|r on the FlipForever panel."):format(#list, FF:Plural(#list)))
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() then self:BuyPending() end
  if FF.UI then FF.UI:Refresh() end
end

function P:Refresh()
  if not (frame and frame:IsShown()) then return end
  frame.title:SetText(FF:T("|cff33ff99Flip|rForever Profession planner"))
  self.mode = self.mode or FlipForeverDB.settings.profMode or "skill"
  if self.mode == "profit" then self:RefreshProfit() return self:RefreshCraft() end
  frame.h1:SetText(FF:T("Cheapest skill-ups"))
  frame.h2:SetText(FF:T("Materials for the top skill-up"))
  frame.mode:SetText(FF:T("Show profitable crafts"))
  frame.buy:SetText(FF:T("Buy missing mats at the AH"))
  if not self.current then
    for name in pairs(self:Store()) do self.current = name break end
  end
  local recs, data = self:Plan(self.current or "")
  if not data then
    frame.prof:SetText(FF:T("Open a profession window once - FlipForever reads its recipes."))
    for _, fs in ipairs(frame.rows) do fs:SetText(FF:T("")) end
    for _, fs in ipairs(frame.mats) do fs:SetText(FF:T("")) end
    frame.hint:SetText(FF:T(""))
    self:RefreshCraft()
    return
  end
  frame.prof:SetText(FF:T("%s  %d / %d  |cff888888(read %s)|r"):format(self.current, data.skill, data.max,
    date("%H:%M", data.t)) .. P:EstimateNote())
  for i, fs in ipairs(frame.rows) do
    local r = recs[i]
    if r then
      local cost = r.unknown and "|cff888888price unknown|r"
        or (r.perPoint <= 0 and ("|cff33ff99+" .. FF:Money(-r.perPoint) .. " profit|r") or (FF:Money(r.perPoint) .. " per skill-up"))
      fs:SetText(FF:T("%s%dx %s  %s  ·  %s"):format(r.learnable and "|cffffd200[trainer]|r " or "", r.crafts, r.recipe.name,
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
      if m.gather then src = src .. " |cff66ccff(you can gather this)|r" end
      local color = m.missing > 0 and "|cffff8080" or "|cff80ff80"
      fs:SetText(FF:T("%s%s  %s%d / %d|r  %s each%s"):format(m.via and "   - " or "", FF:ItemName(m.id), color, m.have, m.need,
        m.unit and FF:Money(m.unit) or "?", src))
    else
      fs:SetText(FF:T(""))
    end
  end
  frame.hint:SetText(FF:T("Orange always gives a point; yellow about 75% and green about 25% until FlipForever has seen the real chance. Prices come from your scans; vendor goods count at about 4x their sell price."))
  self:RefreshCraft()
end

function P:QueueMats()
  local list = self:BuyList(self.current, 1)
  if #list == 0 then
    FF:Print(FF:T("Nothing to buy at the auction house for the top craft (you have it all, or it's vendor goods)."))
    return
  end
  self.pendingMats = list
  FF:Print(FF:T("%d material%s queued. At the auction house, click |cffffd200Buy profession mats|r on the FlipForever panel."):format(#list, FF:Plural(#list)))
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

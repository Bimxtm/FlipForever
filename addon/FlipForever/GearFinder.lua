-- FlipForever gear finder: affordable auction house upgrades for the character you're playing.
--
-- Goes through every item in your latest scan, keeps gear your class can use at your level,
-- scores it with your class's stat weights, compares it with what you're wearing in that slot,
-- and lists real upgrades you can afford. Item data is loaded a few items at a time so the
-- game never stutters. Prices are from your scans; random-suffix greens ("of the Bear") are
-- scored by their base stats only.
local FF = FlipForever
local G = {}
FF.Gear = G

local S = {
  STR = "ITEM_MOD_STRENGTH_SHORT", AGI = "ITEM_MOD_AGILITY_SHORT", STA = "ITEM_MOD_STAMINA_SHORT",
  INT = "ITEM_MOD_INTELLECT_SHORT", SPI = "ITEM_MOD_SPIRIT_SHORT", AP = "ITEM_MOD_ATTACK_POWER_SHORT",
  SP = "ITEM_MOD_SPELL_POWER_SHORT", CRIT = "ITEM_MOD_CRIT_RATING_SHORT", HIT = "ITEM_MOD_HIT_RATING_SHORT",
  DPS = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", ARMOR = "RESISTANCE0_NAME",
}

-- approximate stat weights per class, following the stat priorities in the leveling guides
G.WEIGHTS = {
  WARRIOR = { DPS = 3.0, STR = 1.0, AGI = 0.6, STA = 0.6, AP = 0.5, CRIT = 0.8, HIT = 0.8, ARMOR = 0.02 },
  PALADIN = { DPS = 2.5, STR = 1.0, STA = 0.6, AP = 0.5, SP = 0.4, INT = 0.3, CRIT = 0.7, ARMOR = 0.02 },
  HUNTER  = { DPS = 2.0, AGI = 1.0, AP = 0.5, CRIT = 0.8, STR = 0.2, INT = 0.3, SPI = 0.1, STA = 0.4, ARMOR = 0.01 },
  ROGUE   = { DPS = 2.5, AGI = 1.0, CRIT = 0.8, AP = 0.5, STR = 0.4, STA = 0.4, HIT = 0.7, ARMOR = 0.01 },
  PRIEST  = { DPS = 0.8, INT = 1.0, SP = 1.0, STA = 0.5, SPI = 0.6, ARMOR = 0.005 },
  SHAMAN  = { DPS = 2.5, AGI = 1.0, STR = 0.8, STA = 0.5, INT = 0.4, AP = 0.4, CRIT = 0.6, ARMOR = 0.01 },
  MAGE    = { DPS = 0.8, INT = 1.0, SP = 1.0, STA = 0.5, SPI = 0.5, ARMOR = 0.005 },
  WARLOCK = { DPS = 1.0, SP = 1.0, INT = 0.6, SPI = 0.5, STA = 0.5, ARMOR = 0.005 },
  DRUID   = { DPS = 1.5, STR = 0.8, AGI = 0.8, AP = 0.4, STA = 0.5, INT = 0.4, SPI = 0.3, ARMOR = 0.01 },
}
-- caster builds of hybrid classes
G.BUILD_WEIGHTS = {
  ele_wct = { DPS = 0.5, INT = 1.0, SP = 1.0, STA = 0.5, SPI = 0.4, ARMOR = 0.005 },
  lvl_shadow = G.WEIGHTS.PRIEST,
}

-- armor: best type you can wear (mail/plate from level 40), plus shields
local ARMOR = { MAGE = 1, PRIEST = 1, WARLOCK = 1, ROGUE = 2, DRUID = 2, HUNTER = 3, SHAMAN = 3, WARRIOR = 4, PALADIN = 4 }
local SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
-- weapon subclasses each class can use (item class 2)
local WEAPONS = {
  WARRIOR = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }, PALADIN = { 0, 1, 4, 5, 6, 7, 8 },
  HUNTER = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18 }, ROGUE = { 2, 3, 4, 7, 13, 15, 16, 18 },
  PRIEST = { 4, 10, 15, 19 }, SHAMAN = { 0, 1, 4, 5, 10, 13, 15 }, MAGE = { 7, 10, 15, 19 },
  WARLOCK = { 7, 10, 15, 19 }, DRUID = { 4, 5, 6, 10, 13, 15 },
}
-- equip location -> inventory slot(s)
local SLOTS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16, 17 },
  INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
  INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}
G.SLOT_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
  [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket", [15] = "Back",
  [16] = "Main hand", [17] = "Off hand", [18] = "Ranged" }

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

local function classTag()
  local _, class = UnitClass("player")
  return class
end

function G:Weights()
  local cs = FF.Advisor and FF.Advisor.CharStore and FF.Advisor:CharStore()
  local build = cs and cs.build
  return (build and G.BUILD_WEIGHTS[build]) or G.WEIGHTS[classTag() or ""] or G.WEIGHTS.WARRIOR
end

local function itemStats(link)
  local fn = (C_Item and C_Item.GetItemStats) or GetItemStats
  if not (fn and link) then return nil end
  local ok, t = pcall(fn, link)
  return ok and t or nil
end

function G:Score(stats, weights)
  if not stats then return 0 end
  weights = weights or self:Weights()
  local score = 0
  for key, w in pairs(weights) do
    local v = stats[S[key]]
    if v then score = score + (plain(v) or 0) * w end
  end
  return score
end

-- can this class wear/wield it at this level?
function G:Usable(classID, subID, equipLoc, level)
  local class = classTag()
  if not SLOTS[equipLoc] then return false end
  if classID == 4 then -- armor
    if subID == 6 then return SHIELD[class] or false end
    if subID == 0 or equipLoc == "INVTYPE_CLOAK" then return true end -- jewelry, cloaks, misc
    local best = ARMOR[class] or 1
    if best >= 3 and (level or 1) < 40 then best = best - 1 end -- mail/plate only from level 40
    return subID == best  -- the best type you can wear (lighter armor isn't worth buying)
  elseif classID == 2 then
    for _, w in ipairs(WEAPONS[class] or {}) do if w == subID then return true end end
  end
  return false
end

-- what you have on in this slot (for rings/trinkets the weaker one; for two-handers both hands)
function G:EquippedScore(equipLoc, weights)
  local slots = SLOTS[equipLoc]
  if not slots then return 0, nil end
  local function slotScore(slot)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    return link and self:Score(itemStats(link), weights) or 0
  end
  if equipLoc == "INVTYPE_2HWEAPON" then return slotScore(16) + slotScore(17), 16 end
  if #slots == 2 then
    local a, b = slotScore(slots[1]), slotScore(slots[2])
    if a <= b then return a, slots[1] end
    return b, slots[2]
  end
  return slotScore(slots[1]), slots[1]
end

-- Search -----------------------------------------------------------------------------------------------
G.results, G.pending, G.running = {}, nil, false
local BATCH = 150

-- budget for one piece: a share of your gold (default 25%)
function G:Budget()
  local share = FlipForeverDB.settings.gearShare or 0.25
  return math.floor((GetMoney and GetMoney() or 0) * share)
end

function G:Check(id, price, level, weights, budget, minLevelFloor)
  local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
  if not instant then return "skip" end
  local _, _, _, equipLoc, _, classID, subID = instant(id)
  if not (equipLoc and SLOTS[equipLoc] and (classID == 2 or classID == 4)) then return "skip" end
  if not self:Usable(classID, subID, equipLoc, level) then return "skip" end
  if price > budget then return "skip" end
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local name, link, quality, _, minLevel = info(id)
  if not link then
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return "retry"
  end
  minLevel = plain(minLevel) or 1
  if minLevel > level or minLevel < minLevelFloor then return "skip" end
  local score = self:Score(itemStats(link), weights)
  local cur, slot = self:EquippedScore(equipLoc, weights)
  local gain = score - cur
  if gain <= 0.5 then return "skip" end
  return { id = id, name = plain(name) or FF:ItemName(id), link = link, quality = plain(quality) or 1, minLevel = minLevel,
    price = price, score = score, current = cur, gain = gain, slot = slot, equipLoc = equipLoc,
    pct = cur > 0 and gain / cur or nil }
end

-- start a search over the latest scan (runs in the background, a batch per frame)
function G:Search(onDone)
  local model = FF.Planner and FF.Planner:Model() or {}
  local queue = {}
  for id, m in pairs(model) do queue[#queue + 1] = { id = id, price = m.cur_min } end
  table.sort(queue, function(a, b) return a.id < b.id end)
  local level = UnitLevel("player") or 1
  local weights, budget = self:Weights(), self:Budget()
  local floorLevel = math.max(1, level - 10)
  local found, retries, pos = {}, {}, 1
  self.running = true
  local function step()
    local n = 0
    while pos <= #queue and n < BATCH do
      local q = queue[pos]
      local ok, r = pcall(self.Check, self, q.id, q.price, level, weights, budget, floorLevel)
      if ok and type(r) == "table" then found[#found + 1] = r
      elseif ok and r == "retry" then retries[#retries + 1] = q end
      pos, n = pos + 1, n + 1
    end
    if pos > #queue and #retries > 0 and not self.retried then
      -- second pass for items the game had to load first
      self.retried = true
      for _, q in ipairs(retries) do queue[#queue + 1] = q end
      retries = {}
    end
    if pos <= #queue then
      C_Timer.After(0.05, step)
      return
    end
    self.retried = nil
    -- best upgrade per slot first, then by gain per gold
    table.sort(found, function(a, b)
      if a.gain ~= b.gain then return a.gain > b.gain end
      return a.price < b.price
    end)
    local perSlot, list = {}, {}
    -- what you already carry comes first: it's free
    local okB, bagList = pcall(self.BagUpgrades, self)
    for _, r in ipairs(okB and bagList or {}) do
      perSlot[r.slot] = (perSlot[r.slot] or 0) + 1
      list[#list + 1] = r
    end
    for _, r in ipairs(found) do
      perSlot[r.slot] = (perSlot[r.slot] or 0) + 1
      if perSlot[r.slot] <= 3 then list[#list + 1] = r end
    end
    self.results, self.running, self.searched = list, false, time()
    if onDone then onDone(list) end
    if FF.Hub and FF.Hub.RefreshGear then FF.Hub:RefreshGear() end
    if #list > 0 and FF.Advisor and FF.Advisor.Refresh then pcall(FF.Advisor.Refresh, FF.Advisor) end
  end
  step()
end

-- Gear already in your bags that beats what you wear (green-quality drops you forgot to equip)
function G:BagUpgrades()
  local C = C_Container
  if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return {} end
  local level = UnitLevel("player") or 1
  local weights = self:Weights()
  local out = {}
  for bag = 0, 4 do
    for slot = 1, C.GetContainerNumSlots(bag) or 0 do
      local info = C.GetContainerItemInfo(bag, slot)
      local id = info and info.itemID
      if id then
        local ok, r = pcall(self.Check, self, id, 0, level, weights, math.huge, 1)
        if ok and type(r) == "table" then
          r.bag, r.price = true, 0
          out[#out + 1] = r
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.gain > b.gain end)
  return out
end

-- buy one piece at the auction house (same price-limit rules as the shopping list);
-- for gear already in your bags: put it on
function G:Buy(r)
  if not r then return end
  if r.bag then
    if InCombatLockdown() then FF:Print("Can't change gear during a fight.") return end
    if EquipItemByName and r.link then EquipItemByName(r.link) end
    FF:Print(("Equipped %s."):format(r.name))
    return
  end
  FF.Trader:StartBuying({ { id = r.id, qty = 1, max = math.floor(r.price * 1.15) } }, "gear upgrade")
end

-- the top upgrade, in words (the Advisor shows it)
function G:TopStep()
  local r = self.results and self.results[1]
  if not r then return nil end
  if r.bag then return ("Equip %s from your bags (%s)"):format(r.name, G.SLOT_NAMES[r.slot] or "") end
  return ("Auction house upgrade: %s (%s) for %s"):format(r.name, G.SLOT_NAMES[r.slot] or "", FF:Money(r.price))
end

-- search on its own: after login, after a level-up, and after every new scan
local function later(sec) C_Timer.After(sec, function() if not G.running then pcall(G.Search, G) end end) end
FF:On("PLAYER_LOGIN", function() later(12) end)
FF:On("PLAYER_LEVEL_UP", function() later(3) end)

-- bags change often: refresh only the "in your bags" part (cheap), at most every 5 seconds
function G:RefreshBags()
  if self.running or not self.searched then return end
  local list = {}
  local okB, bagList = pcall(self.BagUpgrades, self)
  for _, r in ipairs(okB and bagList or {}) do list[#list + 1] = r end
  for _, r in ipairs(self.results or {}) do if not r.bag then list[#list + 1] = r end end
  self.results = list
  if FF.Hub and FF.Hub.RefreshGear then FF.Hub:RefreshGear() end
end
local bagPending = false
FF:On("BAG_UPDATE_DELAYED", function()
  if bagPending then return end
  bagPending = true
  C_Timer.After(5, function() bagPending = false pcall(G.RefreshBags, G) end)
end)
FF:On("PLAYER_EQUIPMENT_CHANGED", function() C_Timer.After(1, function() pcall(G.RefreshBags, G) end) end)

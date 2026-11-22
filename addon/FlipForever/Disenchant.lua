-- FlipForever: disenchant values (switch disenchant).
-- What a green, blue or purple weapon or armor piece gives when disenchanted, valued at your
-- scanned auction prices, against what the item itself sells for. Own tables by item level band.
local FF = FlipForever
local D = {}
FF.Disenchant = D

-- materials
local STRANGE, SOUL, VISION, DREAM, ILLUSION = 10940, 11083, 11137, 11176, 16204
local LMAGIC, GMAGIC, LASTRAL, GASTRAL, LMYSTIC, GMYSTIC = 10938, 10939, 10998, 11082, 11134, 11135
local LNETHER, GNETHER, LETERNAL, GETERNAL = 11174, 11175, 16202, 16203
local SGLIM, LGLIM, SGLOW, LGLOW, SRAD, LRAD, SBRIL, LBRIL, NEXUS = 10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344, 20725

-- green (uncommon) armor: { max item level, { item, chance, average count }, ... }
-- weapons give the same materials with dust and essence chances swapped
local GREEN = {
  { 15, { STRANGE, 0.80, 1.5 }, { LMAGIC, 0.20, 1.5 } },
  { 20, { STRANGE, 0.75, 2.5 }, { GMAGIC, 0.20, 1.5 }, { SGLIM, 0.05, 1 } },
  { 25, { STRANGE, 0.75, 5 }, { LASTRAL, 0.15, 1.5 }, { SGLIM, 0.10, 1 } },
  { 30, { SOUL, 0.75, 1.5 }, { GASTRAL, 0.20, 1.5 }, { LGLIM, 0.05, 1 } },
  { 35, { SOUL, 0.75, 3.5 }, { LMYSTIC, 0.20, 1.5 }, { SGLOW, 0.05, 1 } },
  { 40, { VISION, 0.75, 1.5 }, { GMYSTIC, 0.20, 1.5 }, { LGLOW, 0.05, 1 } },
  { 45, { VISION, 0.75, 3.5 }, { LNETHER, 0.20, 1.5 }, { SRAD, 0.05, 1 } },
  { 50, { DREAM, 0.75, 1.5 }, { GNETHER, 0.20, 1.5 }, { LRAD, 0.05, 1 } },
  { 55, { DREAM, 0.75, 3.5 }, { LETERNAL, 0.20, 1.5 }, { SBRIL, 0.05, 1 } },
  { 60, { ILLUSION, 0.75, 1.5 }, { GETERNAL, 0.20, 1.5 }, { LBRIL, 0.05, 1 } },
  { 999, { ILLUSION, 0.75, 3.5 }, { GETERNAL, 0.20, 2.5 }, { LBRIL, 0.05, 1 } },
}
local BLUE = {
  { 25, { SGLIM, 1, 1 } }, { 30, { LGLIM, 1, 1 } }, { 35, { SGLOW, 1, 1 } }, { 40, { LGLOW, 1, 1 } },
  { 45, { SRAD, 1, 1 } }, { 50, { LRAD, 1, 1 } }, { 55, { SBRIL, 1, 1 } }, { 999, { LBRIL, 1, 1 } },
}
local PURPLE = {
  { 45, { SRAD, 1, 3 } }, { 50, { LRAD, 1, 3 } }, { 55, { SBRIL, 1, 3 } }, { 60, { NEXUS, 1, 1 } }, { 999, { NEXUS, 1, 1.5 } },
}
D.MATS = { STRANGE, SOUL, VISION, DREAM, ILLUSION, LMAGIC, GMAGIC, LASTRAL, GASTRAL, LMYSTIC, GMYSTIC, LNETHER, GNETHER,
  LETERNAL, GETERNAL, SGLIM, LGLIM, SGLOW, LGLOW, SRAD, LRAD, SBRIL, LBRIL, NEXUS }

function D:Enabled() return FlipForeverDB.settings.disenchant ~= false end

-- the outcome table for an item: list of { item, chance, count }, or nil when it can't be disenchanted
function D:Outcomes(itemID)
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not info then return nil end
  local _, _, quality, ilvl, _, _, _, _, _, _, _, classID = info(itemID)
  if not (quality and ilvl and classID) or (classID ~= 2 and classID ~= 4) or ilvl < 5 then return nil end
  local tbl = quality == 2 and GREEN or quality == 3 and BLUE or quality == 4 and PURPLE or nil
  if not tbl then return nil end
  if quality == 3 and ilvl < 11 then return nil end
  if quality == 4 and ilvl < 40 then return nil end
  for _, band in ipairs(tbl) do
    if ilvl <= band[1] then
      local out = {}
      for i = 2, #band do
        local m = band[i]
        local chance = m[2]
        if quality == 2 and classID == 2 and i <= 3 then chance = band[i == 2 and 3 or 2][2] end -- weapons: swap
        out[#out + 1] = { id = m[1], chance = chance, count = m[3] }
      end
      return out
    end
  end
end

-- expected value at your scanned prices; nil when the item can't be disenchanted or a main material has no price
function D:Value(itemID)
  local outs = self:Outcomes(itemID)
  if not outs then return nil end
  local total, best, bestShare = 0, nil, 0
  for _, o in ipairs(outs) do
    local p = FF:PriceOf(o.id)
    if not p then
      if o.chance >= 0.5 then return nil end
    else
      local v = o.chance * o.count * p
      total = total + v
      if v > bestShare then best, bestShare = o.id, v end
    end
  end
  if total <= 0 then return nil end
  return math.floor(total), best
end

-- items in your last scan listed below their disenchant value (after a margin): best first
function D:BuyList(margin)
  margin = margin or 0.15
  local list = {}
  for id in pairs(FF:ScannedPrices()) do
    local value = self:Value(id)
    local min = value and FF:MinPriceOf(id)
    if min and min > 0 and min < value * (1 - margin) then
      list[#list + 1] = { id = id, qty = 1, max = math.floor(value * (1 - margin)), value = value, min = min }
    end
  end
  table.sort(list, function(a, b) return (a.value - a.min) > (b.value - b.min) end)
  return list
end

-- /ff disenchant: show the list and queue it for buying at the auction house
function D:Command()
  if not self:Enabled() then
    FF:Print(FF:T("Disenchant values are off (Settings, Features).")) return
  end
  local list = self:BuyList()
  if #list == 0 then
    FF:Print(FF:T("Nothing in your last scan sells below its disenchant value. Scan again later.")) return
  end
  FF:Print(FF:T("%d item%s sell below their disenchant value:"):format(#list, FF:Plural(#list)))
  for i = 1, math.min(8, #list) do
    local e = list[i]
    FF:Print(FF:T("  %s: listed %s, disenchants for ~%s"):format(FF:ItemName(e.id), FF:Money(e.min), FF:Money(e.value)))
  end
  self.pending = list
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
    self.pending = nil
    FF.Trader:StartBuying(list, "disenchant list")
  else
    FF:Print(FF:T("Open the auction house and type /ff disenchant again to buy them."))
  end
end

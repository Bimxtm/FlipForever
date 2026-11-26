-- FlipForever: price lines in item tooltips (like Auctionator's), so you see at a glance
-- what an item usually goes for and whether it's on your shopping or sell list.
-- Read-only: it only adds lines to Blizzard's tooltip.
local FF = FlipForever
local TT = {}
FF.Tooltip = TT

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

-- index the current character's shopping list by item (rebuilt when the list changes)
local index, indexGen = {}, nil
local function planIndex()
  local plan = FF:Plan()
  local gen = plan and plan.generated or 0
  if gen ~= indexGen then
    indexGen, index = gen, {}
    if plan then
      for _, b in ipairs(plan.buy or {}) do index[b.id] = index[b.id] or {} index[b.id].buy = b end
      for _, s in ipairs(plan.sell or {}) do index[s.id] = index[s.id] or {} index[s.id].sell = s end
    end
  end
  return index
end

function TT:Enabled()
  return FlipForeverDB and FlipForeverDB.settings.tooltips ~= false
end

-- the lines for one item (also used by the tests)
function TT:Lines(itemID)
  local out = {}
  if not itemID then return out end
  local price = FF:PriceOf(itemID)
  if price then out[#out + 1] = { FF:T("|cff33ff99FlipForever|r typical price"), FF:Money(price) }
  else
    -- new realm without scans yet: the other realm's price, clearly marked (switch headStart)
    local est, realm = FF:EstimateOf(itemID)
    if est then
      out[#out + 1] = { FF:T("|cff33ff99FlipForever|r estimate"), "~" .. FF:Money(est) }
      out[#out + 1] = { FF:T("  |cffff8800from %s, until you scan here|r"):format(realm or "?"), "" }
    end
  end
  -- things you can craft: what the materials cost (switch craftCostTooltip)
  if FF.Professions and FF.Professions.CraftCostOf then
    local ok, cost, _, _, unknown = pcall(FF.Professions.CraftCostOf, FF.Professions, itemID)
    if ok and cost then
      local text = (unknown and ">" or "") .. FF:Money(cost)
      local worth = price or FF:EstimateOf(itemID)
      if worth then
        local net = math.floor(worth * 0.95) - cost
        if net > 0 and not unknown then text = text .. FF:T(" |cff33ff99(%s profit)|r"):format(FF:Money(net))
        elseif net <= 0 then text = text .. FF:T(" |cffff8800(cheaper to buy)|r") end
      end
      out[#out + 1] = { FF:T("  crafting cost"), text }
    end
  end
  -- how many of it your characters hold (switch altCounts)
  if FF.AltCounts then
    local ok, l = pcall(FF.AltCounts.TooltipLine, FF.AltCounts, itemID)
    if ok and l then out[#out + 1] = l end
  end
  if FF.ExpirySaver then
    local ok, lines = pcall(FF.ExpirySaver.TooltipLines, FF.ExpirySaver, itemID)
    for _, l in ipairs(ok and lines or {}) do out[#out + 1] = l end
  end
  -- at the auction house: what posting one costs in deposit for 12, 24 and 48 hours (switch depositTooltip)
  if #out > 0 and TT:AHOpen() then   -- only for items FlipForever knows something about
    local ok, l = pcall(TT.DepositLine, TT, itemID)
    if ok and l then out[#out + 1] = l end
  end
  local perDay = FF.Planner and FF.Planner:SellsPerDay(itemID)
  if perDay then
    local speed = perDay >= 10 and FF:T("|cff33ff99fast|r") or perDay >= 3 and FF:T("|cffffd200ok|r") or FF:T("|cffff8800slow|r")
    out[#out + 1] = { FF:T("  sells on the AH"), FF:T("~%s/day (%s)"):format(perDay >= 10 and ("%d"):format(math.floor(perDay + 0.5)) or ("%.1f"):format(perDay), speed) }
  end
  local DE = FF.Disenchant
  if DE and DE:Enabled() then
    local value = DE:Value(itemID)
    if value then
      local worth = price and (value > price and FF:T(" |cff33ff99(more than the item)|r") or FF:T(" |cff888888(less than the item)|r")) or ""
      out[#out + 1] = { FF:T("  disenchants for"), "~" .. FF:Money(value) .. worth }
    end
  end
  local entry = planIndex()[itemID]
  if entry and entry.buy then
    local b = entry.buy
    out[#out + 1] = { FF:T("  on your shopping list"), b.gap and FF:T("price checked live") or FF:T("max %s"):format(FF:Money(b.max)) }
  end
  local best = FF.BestPostHours and FF:BestPostHours(itemID)
  if best and best.own then
    out[#out + 1] = { FF:T("  your sales peak"), best.text }
  end
  -- sell-now signal (switch sellNow): you hold it and it is listed well above usual right now
  local okS, above = pcall(function() return FF.Planner and FF.Planner:SellNow(itemID) end)
  if okS and above then
    out[#out + 1] = { FF:T("  |cff33ff99sell now|r"), FF:T("listed %d%% above usual"):format(math.floor(above * 100 + 0.5)) }
  end
  -- falling price warning (switch fallingPrice): you hold it and its price dropped lately
  local okF, trend = pcall(function() return not above and FF.Planner and FF.Planner:Falling(itemID) end)
  if okF and trend then
    out[#out + 1] = { FF:T("  |cffff8800price falling|r"), FF:T("-%d%% in 3 days, sell soon"):format(math.floor(-trend * 100 + 0.5)) }
  end
  -- your own note for it (switch itemNotes)
  if FF.Notes then
    local okN, nl = pcall(FF.Notes.TooltipLine, FF.Notes, itemID)
    if okN and nl then out[#out + 1] = nl end
  end
  -- your last sale of it on this realm (switch lastSale)
  local okL, sale = pcall(TT.LastSaleLine, TT, itemID)
  if okL and sale then out[#out + 1] = sale end
  if entry and entry.sell then
    out[#out + 1] = { FF:T("  you post at"), FF:T("%s (never below %s)"):format(FF:Money(entry.sell.normal), FF:Money(entry.sell.floor)) }
  end
  -- gear: is this better than what you wear? (same stat weights as the Gear tab)
  local up = FlipForeverDB.settings.gearTooltip ~= false and TT:Upgrade(itemID)
  if up then
    out[#out + 1] = up
    if up.diff and up.diff ~= "" then out[#out + 1] = { " ", up.diff } end
  end
  return out
end

-- Your last sale (switch lastSale) ---------------------------------------------------------
-- From the sale mails in this realm's log: when you last sold the item and for how much each
-- (before the auction house cut). The index is rebuilt only when the log grows.
local sales, salesLog, salesN = {}, nil, -1
function TT:LastSaleEnabled() return FlipForeverDB ~= nil and FlipForeverDB.settings.lastSale ~= false end

function TT:LastSale(itemID)
  local log = FF:DB().log or {}
  if log ~= salesLog or #log ~= salesN then
    sales, salesLog, salesN = {}, log, #log
    for _, e in ipairs(log) do
      if e.e == "invoice" and (e.gross or 0) > 0 then
        local key = e.id or e.name
        local old = key and sales[key]
        if key and (not old or (e.t or 0) >= (old.t or 0)) then sales[key] = e end
      end
    end
  end
  local e = sales[itemID]
  local name = FF:ItemName(itemID)
  local byName = name and sales[name]
  if byName and (not e or (byName.t or 0) > (e.t or 0)) then e = byName end
  return e
end

function TT:Ago(t, now)
  local s = math.max(0, (now or time()) - (t or 0))
  if s < 3600 then return FF:T("%d min ago"):format(math.max(1, math.floor(s / 60))) end
  if s < 2 * 86400 then return FF:T("%d h ago"):format(math.floor(s / 3600)) end
  return FF:T("%d days ago"):format(math.floor(s / 86400))
end

function TT:LastSaleLine(itemID, now)
  if not self:LastSaleEnabled() then return nil end
  local e = self:LastSale(itemID)
  if not e then return nil end
  local each = math.floor((e.gross or 0) / math.max(1, e.q or 1))
  local qty = (e.q or 1) > 1 and (" x" .. e.q) or ""
  return { FF:T("  your last sale"), FF:T("%s each%s, %s"):format(FF:Money(each), qty, self:Ago(e.t, now)) }
end

-- Deposit in tooltips ----------------------------------------------------------------------
local ahShown = false
FF:On("AUCTION_HOUSE_SHOW", function() ahShown = true end)
FF:On("AUCTION_HOUSE_CLOSED", function() ahShown = false end)

function TT:AHOpen()
  if AuctionHouseFrame and AuctionHouseFrame.IsShown then return AuctionHouseFrame:IsShown() and true or false end
  return ahShown
end

function TT:DepositEnabled() return FlipForeverDB ~= nil and FlipForeverDB.settings.depositTooltip ~= false end

local MULT = { 1, 2, 4 }   -- the deposit doubles with each longer duration (12h, 24h, 48h)

-- deposit for one unit per duration: your own last posting of it, else the game's figure for
-- commodities, else the usual 15% of the merchant price per 12 hours. Returns {d12, d24, d48}, source
function TT:Deposits(itemID)
  local log = FF:DB().log or {}
  for i = #log, 1, -1 do
    local e = log[i]
    if e.e == "post" and e.id == itemID and (e.dep or 0) > 0 and (e.q or 0) > 0 then
      local base = e.dep / e.q / (MULT[e.dur or 2] or 2)
      return { math.ceil(base), math.ceil(base * 2), math.ceil(base * 4) }, "own"
    end
  end
  local AH = C_AuctionHouse
  if AH and AH.CalculateCommodityDeposit then
    local out = {}
    for d = 1, 3 do
      local ok, dep = pcall(AH.CalculateCommodityDeposit, itemID, d, 1)
      if ok and type(dep) == "number" and dep > 0 then out[d] = dep end
    end
    if out[1] and out[2] and out[3] then return out, "game" end
  end
  local vendor = FF:VendorPrice(itemID)
  if not vendor or vendor <= 0 then return nil end
  local base = vendor * 0.15
  return { math.ceil(base), math.ceil(base * 2), math.ceil(base * 4) }, "vendor"
end

function TT:DepositLine(itemID)
  if not self:DepositEnabled() then return nil end
  local d = self:Deposits(itemID)
  if not d then return nil end
  return { FF:T("  deposit 12/24/48h (each)"), ("%s / %s / %s"):format(FF:Money(d[1]), FF:Money(d[2]), FF:Money(d[3])) }
end

function TT:Upgrade(itemID)
  local G = FF.Gear
  if not (G and G.Check) then return nil end
  local level = UnitLevel and UnitLevel("player") or 1
  local ok, r = pcall(G.Check, G, itemID, 0, level, G:Weights(), math.huge, 1)
  if not (ok and type(r) == "table") then return nil end
  local slot = G.SLOT_NAMES and G.SLOT_NAMES[r.slot] or ""
  local gain = r.pct and ("+%d%%"):format(math.floor(r.pct * 100 + 0.5)) or ("+%.1f"):format(r.gain)
  local diff = ""
  if FlipForeverDB.settings.gearStats ~= false and G.StatDiffText then
    local okD, d = pcall(G.StatDiffText, G, r, 4)
    diff = okD and d or ""
  end
  return { FF:T("  upgrade for you"), ("|cff33ff99%s|r %s"):format(gain, FF:T(slot)), diff = diff }
end

local function addTo(tooltip, itemID)
  if not TT:Enabled() then return end
  local lines = TT:Lines(itemID)
  if #lines == 0 then return end
  for _, l in ipairs(lines) do tooltip:AddDoubleLine(l[1], l[2], 0.8, 0.8, 0.8, 1, 1, 1) end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    local id = data and plain(data.id)
    if type(id) == "number" then pcall(addTo, tooltip, id) end
  end)
end

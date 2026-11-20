-- FlipForever: buying and posting.
-- Blizzard requires a real key press / click for every purchase and every post, so this
-- works as a state machine: searches happen automatically, and each buy / confirm / post
-- waits for you to press the action button (or your bound key).
local FF = FlipForever
local AH = C_AuctionHouse
local T = { mode = nil, state = "idle" }
FF.Trader = T

local SEARCH_TIMEOUT = 8

local function plan() return FF:Plan() end
local function owned(row) return row.containsOwnerItem or row.containsAccountItem end

local function durationSetting()
  local p = plan()
  return (p and p.duration) or 2 -- 1 = 12h, 2 = 24h, 3 = 48h
end

function T:Refresh()
  if FF.UI then FF.UI:Refresh() end
end

function T:Stop(msg)
  if self.state == "quoting" or self.state == "confirm_commodity" then pcall(AH.CancelCommoditiesPurchase) end
  self.mode, self.state, self.target, self.pending = nil, "idle", nil, nil
  self.custom = false
  FF:SetStatus(msg or "Stopped.")
  self:Refresh()
end

function T:PlanOK()
  local p = plan()
  if not p or not p.buy then
    return false, ("No shopping list for %s. In the app, pick this character, click Build shopping list, then /reload."):format(UnitName("player") or "?")
  end
  if p.realm and p.realm ~= FF:RealmKey() then
    return false, ("This shopping list was made for %s, you are on %s. Pick the right realm in the app."):format(p.realm, FF:RealmKey())
  end
  return true
end

-- Searching ---------------------------------------------------------------------------
function T:Search(id)
  self.searchID, self.isCommodity = id, nil
  self.state = "searching"
  self:Refresh()
  local function send()
    if self.searchID ~= id or self.state ~= "searching" then return end
    if AH.IsThrottledMessageSystemReady and not AH.IsThrottledMessageSystemReady() then
      C_Timer.After(0.3, send) return
    end
    local sorts = {}
    if Enum and Enum.AuctionHouseSortOrder then
      sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
    end
    local ok, err = FF:Own(AH.SendSearchQuery, AH.MakeItemKey(id), sorts, true)
    if not ok then FF:SetStatus("Search failed: " .. tostring(err)) end
    local token = {}
    self.searchToken = token
    C_Timer.After(SEARCH_TIMEOUT, function()
      if self.searchToken == token and self.state == "searching" then
        FF:SetStatus("No answer from the auction house, skipping " .. FF:ItemName(id) .. ".")
        self:Advance()
      end
    end)
  end
  C_Timer.After(0.15, send)
end

function T:CommodityRows(id)
  local rows = {}
  local n = AH.GetNumCommoditySearchResults(id) or 0
  for i = 1, n do
    local r = AH.GetCommoditySearchResultInfo(id, i)
    if r then rows[#rows + 1] = r end
  end
  return rows
end

function T:ItemRows(key)
  local rows = {}
  local n = AH.GetNumItemSearchResults(key) or 0
  for i = 1, n do
    local r = AH.GetItemSearchResultInfo(key, i)
    if r and r.buyoutAmount and r.buyoutAmount > 0 then
      r.unitPrice = math.floor(r.buyoutAmount / math.max(1, r.quantity or 1))
      rows[#rows + 1] = r
    end
  end
  table.sort(rows, function(a, b) return a.unitPrice < b.unitPrice end)
  return rows
end

FF:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID)
  if T.state == "searching" and itemID == T.searchID then
    T.searchToken = nil
    T.isCommodity = true
    T:OnResults(T:CommodityRows(itemID))
  end
end)

FF:On("ITEM_SEARCH_RESULTS_UPDATED", function(itemKey)
  if T.state == "searching" and itemKey and itemKey.itemID == T.searchID then
    T.searchToken = nil
    T.isCommodity = false
    T.searchKey = itemKey
    T:OnResults(T:ItemRows(itemKey))
  end
end)

function T:OnResults(rows)
  if self.mode == "buy" then self:EvaluateBuy(rows)
  elseif self.mode == "sell" then self:EvaluateSell(rows) end
end

function T:Advance()
  if self.mode == "buy" then self:NextBuyTarget()
  elseif self.mode == "sell" then self:NextSellTarget() end
end

-- BUYING ------------------------------------------------------------------------------------
function T:Remaining(entry)
  if self.custom then return (entry.qty or 0) - (entry.got or 0) end
  if FF.Hub and FF.Hub.Skipped and FF.Hub:Skipped()[entry.id] then return 0 end -- ticked "Skip" in the list
  return (entry.qty or 0) - (FF:Progress().bought[entry.id] or 0)
end

-- list (optional): buy from this list instead of the shopping list, e.g. profession mats
-- { {id=, qty=, max=}, ... }. Same rules: one key press per purchase, never above max.
function T:StartBuying(list, label)
  if list then
    self.custom, self.list, self.customLabel = true, list, label or "list"
  else
    self.custom, self.list = false, nil
    local ok, err = self:PlanOK()
    if not ok then FF:Print(err) FF:SetStatus(err) return end
  end
  self.mode, self.idx = "buy", 0
  self:NextBuyTarget()
end

function T:NextBuyTarget()
  local list = self.custom and self.list or plan().buy
  repeat self.idx = self.idx + 1 until self.idx > #list or self:Remaining(list[self.idx]) > 0
  if self.idx > #list then
    if self.custom then
      self:Stop(("Done with the %s - everything affordable under the price limits is bought."):format(self.customLabel))
    else
      self:Stop("Shopping list done. Switch to Sell, or rescan later for new deals.")
    end
    return
  end
  self.target = list[self.idx]
  self.target.liveMax, self.target.liveExp = nil, nil
  FF:SetStatus(("Checking %d/%d: %s (%s)"):format(self.idx, #list, FF:ItemName(self.target.id),
    self.target.gap and "price checked live" or ("max " .. FF:Money(self.target.max))))
  self:Search(self.target.id)
end

function T:BudgetLeft()
  if self.custom then return math.huge end -- mats lists: limited by your gold and each item's max price
  local b = plan() and plan().budget
  if not b then return math.huge end
  return math.max(0, b - (FF:Progress().spent or 0))
end

-- Live "normal price" from the listings themselves: the price at which 30% of all
-- units (not counting yours) are listed. A few cheap stacks below that wall are a deal.
local function ladderReference(rows)
  local total = 0
  for _, r in ipairs(rows) do
    if not owned(r) then total = total + r.quantity end
  end
  if total < 10 then return nil end
  local acc = 0
  for _, r in ipairs(rows) do
    if not owned(r) then
      acc = acc + r.quantity
      if acc >= total * 0.30 then return r.unitPrice end
    end
  end
end

-- the price limit for this target: fixed from the app, or worked out live (first-scan mode)
function T:LimitFor(t, rows)
  if not t.gap then return t.max, t.exp end
  if not self.isCommodity then return nil end
  local ref = ladderReference(rows)
  if not ref then return nil end
  local cut = plan().cut or 0.05
  local live = math.floor(ref * (1 - cut) / (1 + t.gap))
  if t.max then live = math.min(live, t.max) end
  return live, ref
end

function T:EvaluateBuy(rows)
  local t = self.target
  local want = self:Remaining(t)
  local money = math.min(GetMoney(), self:BudgetLeft())
  if money <= 0 then
    self:Stop("Budget for this shopping list is used up. Post your items, then build a new list.")
    return
  end
  local limit, expected = self:LimitFor(t, rows)
  if not limit then self:NextBuyTarget() return end
  t.liveMax, t.liveExp = limit, expected
  if self.isCommodity then
    local qty, cost = 0, 0
    for _, r in ipairs(rows) do
      if r.unitPrice > limit then break end
      if not owned(r) then
        local take = math.min(r.quantity, want - qty)
        if cost + take * r.unitPrice > money then
          take = math.floor((money - cost) / r.unitPrice)
        end
        if take <= 0 then break end
        qty, cost = qty + take, cost + take * r.unitPrice
        if qty >= want then break end
      end
    end
    if qty > 0 then
      self.pending = { id = t.id, qty = qty, cost = cost }
      self.state = "ready_commodity"
      FF:SetStatus(("Deal: %d x %s, avg %s each (max %s%s)."):format(qty, FF:ItemName(t.id), FF:Money(cost / qty),
        FF:Money(limit), t.gap and (", normal " .. FF:Money(expected)) or ""))
      self:DealAlert()
      self:Refresh()
      return
    end
  else
    for _, r in ipairs(rows) do
      if r.unitPrice > limit then break end
      if not owned(r) and r.buyoutAmount <= money and (r.quantity or 1) <= want then
        self.pending = { id = t.id, auctionID = r.auctionID, buyout = r.buyoutAmount, qty = r.quantity or 1, unit = r.unitPrice }
        self.state = "ready_item"
        FF:SetStatus(("Deal: %s for %s (max %s)."):format(FF:ItemName(t.id), FF:Money(r.buyoutAmount), FF:Money(limit * (r.quantity or 1))))
        self:DealAlert()
        self:Refresh()
        return
      end
    end
  end
  self:NextBuyTarget()
end

function T:RecordBuy(qty, unit)
  local t = self.target
  if self.custom then
    t.got = (t.got or 0) + qty
    FF:Log({ e = "buy", id = t.id, name = FF:ItemName(t.id), q = qty, p = math.floor(unit), kind = "mats" })
    FF:Print(("Bought %d x %s at %s each."):format(qty, FF:ItemName(t.id), FF:Money(unit)))
    return
  end
  local prog = FF:Progress()
  prog.bought[t.id] = (prog.bought[t.id] or 0) + qty
  prog.spent = (prog.spent or 0) + math.floor(qty * unit)
  FF:Log({ e = "buy", id = t.id, name = FF:ItemName(t.id), q = qty, p = math.floor(unit), exp = t.liveExp or t.exp })
  FF:Print(("Bought %d x %s at %s each."):format(qty, FF:ItemName(t.id), FF:Money(unit)))
end

FF:On("COMMODITY_PRICE_UPDATED", function(unitPrice, totalPrice)
  if T.state ~= "quoting" or not T.pending then return end
  local p = T.pending
  if unitPrice <= (T.target.liveMax or T.target.max) and totalPrice <= T:BudgetLeft() then
    p.quoteUnit, p.quoteTotal = unitPrice, totalPrice
    T.state = "confirm_commodity"
    FF:SetStatus(("Confirm %d x %s for %s total (avg %s)."):format(p.qty, FF:ItemName(p.id), FF:Money(totalPrice), FF:Money(unitPrice)))
  else
    pcall(AH.CancelCommoditiesPurchase)
    FF:SetStatus("Price moved above your max, re-checking.")
    T:Search(T.target.id)
  end
  T:Refresh()
end)

FF:On("COMMODITY_PRICE_UNAVAILABLE", function()
  if T.state == "quoting" then
    FF:SetStatus("Listings changed, re-checking.")
    T:Search(T.target.id)
  end
end)

FF:On("COMMODITY_PURCHASE_SUCCEEDED", function()
  if T.state ~= "purchasing" or not T.pending then return end
  T:RecordBuy(T.pending.qty, T.pending.quoteUnit or (T.pending.cost / T.pending.qty))
  T.pending = nil
  if T:Remaining(T.target) > 0 then T:Search(T.target.id) else T:NextBuyTarget() end
end)

FF:On("COMMODITY_PURCHASE_FAILED", function()
  if T.state ~= "purchasing" then return end
  FF:SetStatus("Purchase failed (someone was faster?), re-checking.")
  T.pending = nil
  T:Search(T.target.id)
end)

FF:On("AUCTION_HOUSE_PURCHASE_COMPLETED", function(auctionID)
  if T.state ~= "purchasing" or not T.pending or T.pending.auctionID ~= auctionID then return end
  T:RecordBuy(T.pending.qty, T.pending.unit)
  T.pending = nil
  if T:Remaining(T.target) > 0 then T:Search(T.target.id) else T:NextBuyTarget() end
end)

-- SELLING -------------------------------------------------------------------------------------
local function bagSlots()
  local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
  return 0, last
end

function T:FindInBags(id)
  local first, last = bagSlots()
  for bag = first, last do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID == id and not info.isBound then
        local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
        local valid = true
        if AH.IsSellItemValid then valid = AH.IsSellItemValid(loc, false) end
        if valid then return loc, info.stackCount or 1 end
      end
    end
  end
end

function T:StartSelling()
  local ok, err = self:PlanOK()
  if not ok then FF:Print(err) FF:SetStatus(err) return end
  self.mode, self.sidx = "sell", 0
  self.sellList = self:BuildSellList()
  self:NextSellTarget()
end

-- What you paid per unit for recent purchases (last 14 days), from the trade log.
function T:CostBasis(id)
  local qty, cost, expQty, exp = 0, 0, 0, 0
  local since = time() - 14 * 86400
  local me = UnitName("player")
  for _, e in ipairs(FF:DB().log) do
    if e.e == "buy" and e.id == id and (e.t or 0) >= since and e.q and e.p and (e.char == nil or e.char == me) then
      qty, cost = qty + e.q, cost + e.q * e.p
      if e.exp then expQty, exp = expQty + e.q, exp + e.q * e.exp end
    end
  end
  if qty > 0 then return cost / qty, expQty > 0 and (exp / expQty) or nil end
end

-- Things you just bought come first (even if the app hasn't seen them yet), then the app's list.
function T:BuildSellList()
  local list, seen = {}, {}
  local sell = plan().sell or {}
  local byId = {}
  for _, s in ipairs(sell) do byId[s.id] = s end
  for id in pairs(FF:Progress().bought) do
    local cost, expected = self:CostBasis(id)
    if cost and not seen[id] then
      -- price it at the normal price seen when buying, never capped below that
      local normal = math.floor(math.max(expected or 0, cost * 1.35))
      local ceil = math.floor(math.max(normal * 1.6, cost * 2.2))
      local rule = byId[id]
      local s = { id = id, floor = rule and rule.floor or 0,
                  normal = math.max(normal, rule and rule.normal or 0),
                  ceil = math.max(ceil, rule and rule.ceil or 0) }
      list[#list + 1] = s
      seen[id] = true
    end
  end
  for _, s in ipairs(sell) do
    if not seen[s.id] then list[#list + 1] = s seen[s.id] = true end
  end
  return list
end

local function bagItemSet()
  local set = {}
  local first, last = bagSlots()
  for bag = first, last do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID and not info.isBound then set[info.itemID] = true end
    end
  end
  return set
end

function T:NextSellTarget()
  local list = self.sellList or plan().sell or {}
  local inBags = bagItemSet()
  while true do
    self.sidx = self.sidx + 1
    local s = list[self.sidx]
    if not s then
      self:Stop("Nothing (else) to post right now.")
      return
    end
    if inBags[s.id] and self:FindInBags(s.id) then
      self.target = s
      FF:SetStatus(("Pricing %s..."):format(FF:ItemName(s.id)))
      self:Search(s.id)
      return
    end
  end
end

-- Which competitor price to undercut. A tiny lot (<= 5% of what others list) priced 30%+ below the
-- next listing is a dump: it sells within minutes and isn't the market, so we price against the
-- next real listing instead (at most the 2 cheapest lots are skipped). Returns anchor, ignoredPrice.
function T:UndercutAnchor(rows)
  local others, total = {}, 0
  for _, r in ipairs(rows) do
    if not owned(r) then
      others[#others + 1] = r
      total = total + (r.quantity or 1)
    end
  end
  if #others == 0 then return nil end
  local skip = 0
  while skip < 2 and skip < #others - 1 do
    local r, nxt = others[skip + 1], others[skip + 2]
    local tiny = (r.quantity or 1) <= math.max(1, total * 0.05)
    if tiny and r.unitPrice < nxt.unitPrice * 0.7 then skip = skip + 1 else break end
  end
  return others[skip + 1].unitPrice, skip > 0 and others[1].unitPrice or nil
end

function T:EvaluateSell(rows)
  local s = self.target
  local lowestOwn
  for _, r in ipairs(rows) do
    if owned(r) then lowestOwn = lowestOwn or r.unitPrice end
  end
  local lowestOther, ignored = self:UndercutAnchor(rows)
  if ignored then FF:Print(("%s: ignoring a tiny dumped lot at %s - pricing against %s."):format(
    FF:ItemName(s.id), FF:Money(ignored), FF:Money(lowestOther))) end
  local price
  if lowestOther then
    price = lowestOther - 1
    if lowestOwn and lowestOwn <= lowestOther then price = lowestOwn end
  else
    price = s.normal
  end
  price = math.min(price, s.ceil or (s.normal * 2))
  if FlipForeverDB.settings.silverOnly and self.isCommodity then
    price = math.floor(price / 100) * 100
  end
  -- never sell a flip at a loss: floor covers what you paid + the AH cut
  local floor = s.floor or 0
  local cost = self:CostBasis(s.id)
  if cost then floor = math.max(floor, math.ceil(cost * 1.02 / (1 - (plan().cut or 0.05)))) end
  if price < floor then
    FF:Print(("Holding %s: market %s is below your floor %s."):format(FF:ItemName(s.id), FF:Money(lowestOther or 0), FF:Money(floor)))
    FF:Log({ e = "hold", id = s.id, name = FF:ItemName(s.id), p = lowestOther or 0 })
    self:NextSellTarget()
    return
  end
  local loc, stack = self:FindInBags(s.id)
  if not loc then self:NextSellTarget() return end
  local qty
  if self.isCommodity then
    qty = C_Item.GetItemCount(s.id, false, false) or stack
    if s.maxQty then qty = math.min(qty, s.maxQty) end
  else
    qty = stack
  end
  self.pending = { id = s.id, loc = loc, qty = qty, unit = price, commodity = self.isCommodity }
  self.state = "ready_post"
  FF:SetStatus(("Post %d x %s at %s each%s."):format(qty, FF:ItemName(s.id), FF:Money(price),
    lowestOther and (" (lowest other " .. FF:Money(lowestOther) .. ")") or " (no competition)"))
  self:Refresh()
end

function T:Deposit(p)
  local d = durationSetting()
  local ok, dep
  if p.commodity then
    ok, dep = pcall(AH.CalculateCommodityDeposit, p.id, d, p.qty)
  else
    ok, dep = pcall(AH.CalculateItemDeposit, p.loc, d, p.qty)
  end
  return ok and dep or 0
end

function T:DoPost(confirm)
  local p, d = self.pending, durationSetting()
  p.dep = p.dep or self:Deposit(p)
  local fn
  if p.commodity then
    fn = confirm and AH.ConfirmPostCommodity or AH.PostCommodity
    self.state = "posting"
    local ok, err = pcall(fn, p.loc, d, p.qty, p.unit)
    if not ok then FF:SetStatus("Post failed: " .. tostring(err)) self.state = "ready_post" end
  else
    fn = confirm and AH.ConfirmPostItem or AH.PostItem
    self.state = "posting"
    local ok, err = pcall(fn, p.loc, d, p.qty, nil, p.unit * p.qty)
    if not ok then FF:SetStatus("Post failed: " .. tostring(err)) self.state = "ready_post" end
  end
  self:Refresh()
end

FF:On("AUCTION_HOUSE_AUCTION_CREATED", function()
  if T.state ~= "posting" or not T.pending then return end
  local p = T.pending
  FF:Log({ e = "post", id = p.id, name = FF:ItemName(p.id), q = p.qty, p = p.unit, dep = p.dep or 0, dur = durationSetting() })
  T.pending = nil
  -- non-commodity items post one stack at a time; keep going while more remain
  if not p.commodity and T:FindInBags(p.id) then
    T:Search(p.id)
  else
    T:NextSellTarget()
  end
end)

FF:On("AUCTION_HOUSE_POST_WARNING", function()
  if T.state == "posting" then
    T.state = "confirm_post"
    FF:SetStatus("The auction house wants a confirmation for this post. Press again to confirm.")
    T:Refresh()
  end
end)

FF:On("AUCTION_HOUSE_POST_ERROR", function()
  if T.state == "posting" then
    if T.pending and T.pending.commodity and not FlipForeverDB.settings.silverOnly then
      FlipForeverDB.settings.silverOnly = true
      FF:Print("Post rejected - switching commodity prices to whole silver.")
      T:Search(T.target.id)
    else
      FF:SetStatus("Post rejected by the auction house, skipping.")
      T:NextSellTarget()
    end
  end
end)

FF:On("UI_ERROR_MESSAGE", function(_, msg)
  if T.state == "purchasing" or T.state == "posting" then
    FF:SetStatus("Auction house error: " .. tostring(msg))
    local id = T.target and T.target.id
    T.pending = nil
    if id then T:Search(id) end
  end
end)

FF:On("AUCTION_HOUSE_CLOSED", function()
  if T.mode then T:Stop("Auction house closed.") end
end)

-- The one button / key --------------------------------------------------------------------------
-- Must only be called from a click or key press.
function T:Primary()
  local s = self.state
  if s == "idle" then
    if (plan() and plan().buy and #plan().buy > 0) then self:StartBuying() else self:StartSelling() end
  elseif s == "ready_commodity" then
    local p = self.pending
    self.state = "quoting"
    AH.StartCommoditiesPurchase(p.id, p.qty)
    FF:SetStatus("Getting the final price...")
  elseif s == "confirm_commodity" then
    local p = self.pending
    self.state = "purchasing"
    AH.ConfirmCommoditiesPurchase(p.id, p.qty)
    FF:SetStatus("Buying...")
  elseif s == "ready_item" then
    local p = self.pending
    self.state = "purchasing"
    AH.PlaceBid(p.auctionID, p.buyout)
    FF:SetStatus("Buying...")
  elseif s == "ready_post" then
    self:DoPost(false)
  elseif s == "confirm_post" then
    self:DoPost(true)
  end
  self:Refresh()
end

-- a deal (or a confirmation) is waiting for your key press
function T:WaitingForUser()
  local s = self.state
  return s == "ready_commodity" or s == "confirm_commodity" or s == "ready_item"
end

-- sound + raid warning + taskbar flash, once per deal (the panel keeps flashing)
function T:DealAlert()
  local p = self.pending
  if not p or not FF.Alert then return end
  local key = (p.id or 0) .. ":" .. (p.qty or 0) .. ":" .. (p.auctionID or p.cost or 0)
  if self.lastAlert == key then return end
  self.lastAlert = key
  local key2 = FlipForeverDB.settings.key
  FF:Alert(("FLIP FOUND: %d x %s - press %s to buy"):format(p.qty or 1, FF:ItemName(p.id),
    key2 and key2 or "the FlipForever button"))
end

function T:Skip()
  if self.state == "quoting" or self.state == "confirm_commodity" then pcall(AH.CancelCommoditiesPurchase) end
  self.pending = nil
  if self.mode then self:Advance() end
end

function T:ButtonText()
  local s, p = self.state, self.pending
  if s == "idle" then return FF:T("Start") end
  if s == "searching" then return FF:T("Searching...") end
  if s == "ready_commodity" then return ("BUY %d x %s"):format(p.qty, FF:ItemName(p.id)) end
  if s == "quoting" then return FF:T("Getting price...") end
  if s == "confirm_commodity" then return ("CONFIRM %s"):format(FF:Money(p.quoteTotal or p.cost)) end
  if s == "ready_item" then return ("BUY %s"):format(FF:Money(p.buyout)) end
  if s == "purchasing" then return FF:T("Buying...") end
  if s == "ready_post" then return ("POST %d x %s"):format(p.qty, FF:ItemName(p.id)) end
  if s == "confirm_post" then return FF:T("CONFIRM POST") end
  if s == "posting" then return FF:T("Posting...") end
  return s
end

function T:ButtonEnabled()
  local s = self.state
  return s == "idle" or s == "ready_commodity" or s == "confirm_commodity" or s == "ready_item"
    or s == "ready_post" or s == "confirm_post"
end

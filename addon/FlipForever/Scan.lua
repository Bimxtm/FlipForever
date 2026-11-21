-- FlipForever: price scanning, built to share the auction house with other addons.
--  * Full scans use C_AuctionHouse.ReplicateItems. That has a 15-minute cooldown shared by
--    EVERY addon on the account (Auctioneer, Auctionator, ...), starting at the request.
--    We never request one while the slot is taken, and when another addon runs one we read
--    the same data (read-only) instead of asking again.
--  * The data can take minutes to arrive and grows while it loads, so we wait until the
--    auction count has stopped changing before reading it.
--  * Browse scan (manual fallback) and passive capture of anything browsed.
local FF = FlipForever
local Scan = {}
FF.Scan = Scan

local AH = C_AuctionHouse
local COOLDOWN = 15 * 60 + 5
local STABLE_SECONDS = 8
local REPLICATE_TIMEOUT = 600

-- Run one of our own auction house calls, flagged so the activity hooks know it was us.
function FF:Own(fn, ...)
  self.ownCall = true
  local ok, err = pcall(fn, ...)
  self.ownCall = false
  return ok, err
end

-- raw[id] = { {unitPrice, qty}, ... }  ->  { min, p25, qty, n }
local function summarize(raw)
  local out = {}
  for id, list in pairs(raw) do
    table.sort(list, function(a, b) return a[1] < b[1] end)
    local total = 0
    for _, e in ipairs(list) do total = total + e[2] end
    local target, acc, p25 = total * 0.25, 0, list[1][1]
    for _, e in ipairs(list) do
      acc = acc + e[2]
      if acc >= target then p25 = e[1] break end
    end
    out[id] = { min = list[1][1], p25 = p25, qty = total, n = #list }
  end
  return out
end

-- Shared cooldown ------------------------------------------------------------------------
function Scan:LastReplicateRequest()
  local t = FlipForeverDB and FlipForeverDB.lastReplicate or 0
  if type(AucAdvancedData) == "table" then
    t = math.max(t, tonumber(AucAdvancedData.ForeverReplicateRequested) or 0)
  end
  return t
end

function Scan:ReplicateReadyIn()
  return math.max(0, self:LastReplicateRequest() + COOLDOWN - time())
end

-- Watch every ReplicateItems call, ours or another addon's.
if AH and AH.ReplicateItems then
  hooksecurefunc(AH, "ReplicateItems", function()
    if FlipForeverDB then FlipForeverDB.lastReplicate = time() end
    Scan:WatchReplicate(FF.ownCall)
  end)
end

function Scan:WatchReplicate(own)
  if self.busy == "processing" then return end
  self.busy = own and "replicate" or "external"
  local w = { started = time(), own = own, initial = AH.GetNumReplicateItems() or 0, last = -1, stable = 0, gotEvent = false }
  self.watch = w
  FF:SetStatus(own and "Full scan requested, waiting for the server (can take a few minutes)..."
    or "Another addon is running a full scan - FlipForever will read the same data.")
  if self.poller then self.poller:Cancel() end
  self.poller = C_Timer.NewTicker(2, function()
    if self.watch ~= w then return end
    local n = AH.GetNumReplicateItems() or 0
    local fresh = w.gotEvent or n ~= w.initial
    if n > 0 and fresh then
      if n == w.last then w.stable = w.stable + 2 else w.stable = 0 end
      w.last = n
      if self.busy ~= "processing" then
        FF:SetStatus(("Full scan arriving: %d auctions so far..."):format(n))
      end
      if w.stable >= STABLE_SECONDS then
        self.poller:Cancel()
        self:ProcessReplicate(w)
      end
    elseif time() - w.started > REPLICATE_TIMEOUT then
      self.poller:Cancel()
      self.watch, self.busy = nil, nil
      if w.own then
        FF:Print("The full scan never arrived from the server.")
        if FF.Auto then FF.Auto:ScanFailed("no data from the server") end
      end
    end
  end)
end

FF:On("REPLICATE_ITEM_LIST_UPDATE", function()
  if Scan.watch then Scan.watch.gotEvent = true end
end)

function Scan:ProcessReplicate(w)
  self.busy = "processing"
  local total = AH.GetNumReplicateItems() or 0
  local raw, i = {}, 0
  local function step()
    local stop = math.min(i + 400, total)
    while i < stop do
      local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = AH.GetReplicateItemInfo(i)
      if itemID and buyout and buyout > 0 and count and count > 0 then
        local list = raw[itemID]
        if not list then list = {} raw[itemID] = list end
        list[#list + 1] = { math.floor(buyout / count), count }
        if name and name ~= "" then FF:SetName(itemID, name) end
      end
      i = i + 1
    end
    FF:SetStatus(("Reading full scan... %d / %d auctions"):format(i, total))
    if i < total then
      C_Timer.After(0, step)
    else
      local summary = summarize(raw)
      Scan:QueueNames(summary)
      local n = FF:AddScan("full", summary)
      self.busy, self.watch = nil, nil
      local who = w.own and "Full scan" or "Full scan (shared from another addon's scan)"
      FF:Print(("%s saved: %d auctions, %d items. /reload or log out so the app can import it."):format(who, total, n))
      FF:SetStatus(("%s done: %d items."):format(who, n))
      if FF.Auto then FF.Auto:ScanDone(true) end
      FF:ScanFinished(n)
    end
  end
  step()
end

-- Start a scan. auto=true: never fall back to browsing (it would change what you see in
-- the Buy tab) - just report when the shared slot frees up.
-- Returns started(bool), secondsUntilPossible
function Scan:StartFull(auto)
  if self.busy then
    if not auto then FF:Print("A scan is already running.") end
    return false, 30
  end
  if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
    if not auto then FF:Print("Open the auction house first.") end
    return false, 30
  end
  if not auto and FF.Auto then FF.Auto.scanBlocked = false end
  local wait = self:ReplicateReadyIn()
  if not AH.ReplicateItems then wait = math.huge end
  if wait > 0 then
    if auto then return false, wait end
    if wait < math.huge then
      FF:Print(("Full scan is on the shared 15-min cooldown (%d:%02d left - also used by Auctioneer/Auctionator). Doing a browse scan instead.")
        :format(math.floor(wait / 60), wait % 60))
    end
    return self:StartBrowse(), 0
  end
  local ok, err = FF:Own(AH.ReplicateItems)
  if not ok then
    FF:Print("Full scan request failed: " .. tostring(err))
    return false, 60
  end
  return true, 0
end

-- Prices for other modules (Gathering, Advisor): typical unit price (25th percentile)
-- from the newest scan that has the item. Parsed once per new scan.
local priceCache, priceCacheKey = {}, nil
local function rebuildPrices()
  local scans = FF:DB().scans
  local key = #scans .. ":" .. ((scans[#scans] or {}).t or 0)
  if key == priceCacheKey then return end
  priceCacheKey, priceCache = key, {}
  for i = 1, #scans do -- oldest first, so newer scans overwrite
    for id, _, p25 in (scans[i].d or ""):gmatch("(%d+):(%d+):(%d+):%d+:%d+") do
      priceCache[tonumber(id)] = tonumber(p25)
    end
  end
end

function FF:PriceOf(id)
  if not FlipForeverDB then return nil end
  rebuildPrices()
  return priceCache[id]
end

function FF:HasPrices()
  return FlipForeverDB ~= nil and #FF:DB().scans > 0
end

-- how old the newest scan is; prices older than 6 hours are flagged
function FF:ScanAgeLine()
  local scans = FF:DB().scans
  local last = scans[#scans]
  if not (last and last.t) then return FF:T("Last scan: none yet") end
  local mins = math.max(0, math.floor((time() - last.t) / 60))
  local age
  if mins < 60 then age = FF:T("%d min ago"):format(mins)
  elseif mins < 48 * 60 then age = FF:T("%d h ago"):format(math.floor(mins / 60))
  else age = FF:T("%d days ago"):format(math.floor(mins / 1440)) end
  if mins >= 6 * 60 then
    return FF:T("Last scan: |cffff8800%s|r - prices may have moved, scan again"):format(age)
  end
  return FF:T("Last scan: %s"):format(age)
end

-- Names: the client only knows an item's name once its data is loaded. After each scan,
-- ask for the missing ones a few at a time and store them as they arrive.
Scan.nameQueue = {}
function Scan:QueueNames(ids)
  local names = FF:DB().names
  for id in pairs(ids) do
    if not names[id] then table.insert(self.nameQueue, id) end
  end
  if not self.resolving then self:ResolveNames() end
end

function Scan:ResolveNames()
  self.resolving = true
  local names = FF:DB().names
  for _ = 1, 50 do
    local id = table.remove(self.nameQueue)
    if not id then self.resolving = false return end
    local name = C_Item.GetItemNameByID(id)
    if name then
      names[id] = name
    elseif C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(id)
    end
  end
  C_Timer.After(0.2, function() Scan:ResolveNames() end)
end

FF:On("ITEM_DATA_LOAD_RESULT", function(itemID, success)
  if success and itemID then
    local name = C_Item.GetItemNameByID(itemID)
    if name then FF:DB().names[itemID] = name end
  end
end)

-- Browse results (manual fallback scan + passive capture) -----------------------------------
Scan.browse = {}      -- keyString -> {id, min, qty}
Scan.browseCount = 0

local function ingestRow(row)
  local key = row and row.itemKey
  if not key or not key.itemID or not row.minPrice or row.minPrice <= 0 then return end
  local ks = key.itemID .. ":" .. (key.itemLevel or 0) .. ":" .. (key.itemSuffix or 0)
  if not Scan.browse[ks] then Scan.browseCount = Scan.browseCount + 1 end
  Scan.browse[ks] = { id = key.itemID, min = row.minPrice, qty = row.totalQuantity or 1 }
end

function Scan:FlushBrowse(src)
  if self.browseCount == 0 then return 0 end
  local agg = {}
  for _, r in pairs(self.browse) do
    local a = agg[r.id]
    if not a then
      agg[r.id] = { min = r.min, p25 = r.min, qty = r.qty, n = 1 }
    else
      a.min = math.min(a.min, r.min); a.p25 = a.min
      a.qty = a.qty + r.qty; a.n = a.n + 1
    end
  end
  self.browse, self.browseCount = {}, 0
  self:QueueNames(agg)
  return FF:AddScan(src, agg)
end

function Scan:StartBrowse()
  if self.busy then return false end
  local query = { searchString = "", sorts = {}, filters = {}, itemClassFilters = {} }
  if Enum and Enum.AuctionHouseSortOrder then
    query.sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
  end
  self:FlushBrowse("browse")
  self.busy = "browse"
  local ok, err = FF:Own(AH.SendBrowseQuery, query)
  if not ok then
    self.busy = nil
    FF:Print("Browse scan failed: " .. tostring(err))
    return false
  end
  FF:SetStatus("Browse scan running...")
  return true
end

local function continueBrowse()
  if Scan.busy ~= "browse" then return end
  FF:SetStatus(("Browse scan: %d item groups so far..."):format(Scan.browseCount))
  if AH.HasFullBrowseResults and AH.HasFullBrowseResults() then
    local n = Scan:FlushBrowse("full-browse")
    Scan.busy = nil
    FF:Print(("Browse scan saved: %d items."):format(n))
    FF:SetStatus(("Browse scan done: %d items."):format(n))
    if FF.Auto then FF.Auto:ScanDone(true) end
    FF:ScanFinished(n)
  else
    C_Timer.After(0.4, function()
      if Scan.busy == "browse" then FF:Own(AH.RequestMoreBrowseResults) end
    end)
  end
end

FF:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function()
  local results = AH.GetBrowseResults and AH.GetBrowseResults()
  if results then for _, row in ipairs(results) do ingestRow(row) end end
  continueBrowse()
end)

FF:On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function(added)
  if added then for _, row in ipairs(added) do ingestRow(row) end end
  continueBrowse()
end)

FF:On("AUCTION_HOUSE_CLOSED", function()
  if Scan.busy == "browse" then Scan.busy = nil end
  -- the server drops the replicate list when the AH closes; stop waiting for it
  if Scan.watch and Scan.busy ~= "processing" then
    if Scan.poller then Scan.poller:Cancel() end
    Scan.watch, Scan.busy = nil, nil
  end
  -- keep what was browsed passively as a partial snapshot (prices only)
  if Scan.browseCount > 0 then Scan:FlushBrowse("partial") end
end)

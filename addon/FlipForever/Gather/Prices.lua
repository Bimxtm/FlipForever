-- FlipForever Gathering module (was the separate Ore Farmer addon).
if select(2, ...).skipGather then return end
-- Ore Farmer: prices. Ore Farmer doesn't scan the auction house itself.
-- It asks, in order:
--   1. a price you set yourself with /ore price
--   2. Auctionator, if installed
--   3. TradeSkillMaster, if installed
--   4. the vendor price
local _, ns = ...

function ns.TrackItem(id)
  ns.db.tracked = ns.db.tracked or {}
  ns.db.tracked[id] = true
end

local function getItemInfo(id)
  if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
  if GetItemInfo then return GetItemInfo(id) end
end

local function vendorPrice(id)
  local p = select(11, getItemInfo(id))
  if type(p) == "number" and p > 0 then return p end
  return nil
end

local function auctionatorPrice(id)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if not (api and api.GetAuctionPriceByItemID) then return nil end
  local ok, p = pcall(api.GetAuctionPriceByItemID, "OreFarmer", id)
  if ok and type(p) == "number" and p > 0 then return p end
  return nil
end

local function tsmPrice(id)
  if not (TSM_API and TSM_API.GetCustomPriceValue) then return nil end
  for _, source in ipairs({ "dbminbuyout", "dbmarket" }) do
    local ok, p = pcall(TSM_API.GetCustomPriceValue, source, "i:" .. id)
    if ok and type(p) == "number" and p > 0 then return p end
  end
  return nil
end

local function auctioneerPrice(id)
  local api = AucAdvanced and AucAdvanced.API
  if not (api and api.GetMarketValue) then return nil end
  local link = select(2, getItemInfo(id))
  if type(link) ~= "string" or ns.IsSecret(link) then return nil end
  local ok, p = pcall(api.GetMarketValue, link)
  if ok and type(p) == "number" and p > 0 then return p end
  return nil
end

local function flipForeverPrice(id)
  local ff = FlipForever
  if not (ff and ff.PriceOf) then return nil end
  local ok, p = pcall(ff.PriceOf, ff, id)
  if ok and type(p) == "number" and p > 0 then return p end
  return nil
end

-- Returns copper, source ("manual" / "FlipForever" / "Auctionator" / "Auctioneer" / "TSM" / "vendor"), or 0, nil.
function ns.PriceOf(id)
  local m = ns.db and ns.db.prices[id]
  if m and m.p then return m.p, "manual" end
  local p = flipForeverPrice(id)
  if p then return p, "FlipForever" end
  p = auctionatorPrice(id)
  if p then return p, "Auctionator" end
  p = auctioneerPrice(id)
  if p then return p, "Auctioneer" end
  p = tsmPrice(id)
  if p then return p, "TSM" end
  p = vendorPrice(id)
  if p then return p, "vendor" end
  return 0, nil
end

function ns.PriceSourceName()
  if FlipForever and FlipForever.HasPrices and FlipForever:HasPrices() then return "FlipForever" end
  if Auctionator and Auctionator.API and Auctionator.API.v1 then return "Auctionator" end
  if AucAdvanced and AucAdvanced.API and AucAdvanced.API.GetMarketValue then return "Auctioneer" end
  if TSM_API and TSM_API.GetCustomPriceValue then return "TSM" end
  return nil
end

-- /ore price <item link or ID> <gold>   (e.g. /ore price 2772 0.45, or 0 to clear)
function ns.SetManualPrice(arg)
  local id = tonumber(arg:match("item:(%d+)")) or tonumber(arg:match("^%s*(%d+)%s"))
  local gold = tonumber(arg:match("([%d%.]+)%s*$"))
  if not id or not gold then
    ns.Print("usage: /ore price <item link or item ID> <gold>, e.g. /ore price 2772 0.45 (0 clears it)")
    return
  end
  if gold <= 0 then
    ns.db.prices[id] = nil
    ns.Print("manual price cleared for item " .. id .. ".")
  else
    ns.db.prices[id] = { p = math.floor(gold * 10000 + 0.5), t = time() }
    ns.Print(string.format("item %d priced at %s.", id, ns.FormatMoney(ns.db.prices[id].p)))
  end
  ns.MarkDirty()
end

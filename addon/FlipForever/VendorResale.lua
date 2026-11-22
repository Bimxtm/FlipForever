-- Vendor resale finder (switch vendorResale): merchants you visit are remembered with their spot on the
-- map and their limited-supply items (recipes and other items in stock). Items that sell for clearly more
-- on the auction house (your scanned prices) are named at the merchant, and /ff vendors lists the best
-- known spots and pins them on the map.
local FF = FlipForever
local V = {}
FF.VendorResale = V

V.MARGIN = 0.2       -- auction price after the 5% cut must beat the vendor price by this much
V.MIN_PROFIT = 50    -- and by at least 50 copper

function V:Enabled() return FlipForeverDB.settings.vendorResale ~= false end

function V:Spots()
  local db = FF:DB()
  db.vendorSpots = db.vendorSpots or {}
  return db.vendorSpots
end

local function playerSpot()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local m = C_Map.GetBestMapForUnit("player")
  local pos = m and C_Map.GetPlayerMapPosition(m, "player")
  if not pos then return m end
  local x, y = pos:GetXY()
  return m, x, y
end

-- remember the open merchant's limited-supply items (numAvailable >= 0; -1 = unlimited)
function V:Record()
  if not (GetMerchantNumItems and GetMerchantItemInfo and GetMerchantItemLink) then return nil end
  local npc = UnitName("npc")
  if not npc then return nil end
  local items = {}
  for i = 1, GetMerchantNumItems() or 0 do
    local _, _, price, quantity, numAvailable = GetMerchantItemInfo(i)
    local link = GetMerchantItemLink(i)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id and price and price > 0 and numAvailable and numAvailable >= 0 then
      items[id] = { price = math.floor(price / math.max(1, quantity or 1)), stock = numAvailable }
    end
  end
  local spots = self:Spots()
  local m, x, y = playerSpot()
  local s = spots[npc] or {}
  s.map, s.x, s.y, s.t = m or s.map, x or s.x, y or s.y, time()
  s.items = items
  spots[npc] = next(items) and s or nil
  return spots[npc]
end

-- resale profit per unit of a vendor item, or nil when it doesn't pay
function V:Profit(id, price)
  local ah = FF:PriceOf(id)
  if not ah then return nil end
  local net = math.floor(ah * 0.95)
  local profit = net - price
  if profit >= self.MIN_PROFIT and net >= price * (1 + self.MARGIN) then return profit, ah end
  return nil
end

-- profitable items of one spot: { id, price, ah, profit, stock }, best first
function V:Deals(spot)
  local out = {}
  for id, e in pairs(spot and spot.items or {}) do
    local profit, ah = self:Profit(id, e.price)
    if profit then out[#out + 1] = { id = id, price = e.price, ah = ah, profit = profit, stock = e.stock } end
  end
  table.sort(out, function(a, b) if a.profit ~= b.profit then return a.profit > b.profit end return a.id < b.id end)
  return out
end

-- all known spots with deals: { npc, spot, deals, total }, best total first
function V:Best()
  local list = {}
  for npc, s in pairs(self:Spots()) do
    local deals = self:Deals(s)
    if #deals > 0 then
      local total = 0
      for _, d in ipairs(deals) do total = total + d.profit * math.max(1, d.stock or 1) end
      list[#list + 1] = { npc = npc, spot = s, deals = deals, total = total }
    end
  end
  table.sort(list, function(a, b) if a.total ~= b.total then return a.total > b.total end return a.npc < b.npc end)
  return list
end

local function dealText(d)
  return FF:T("%s: %s here, ~%s on the auction house (%d in stock)"):format(FF:ItemName(d.id), FF:Money(d.price),
    FF:Money(d.ah), d.stock or 0)
end

function V:OnMerchant()
  if not self:Enabled() then return end
  local s = self:Record()
  local deals = self:Deals(s)
  if #deals == 0 then return end
  FF:Print(FF:T("Resale: %d item%s here can sell for more on the auction house:"):format(#deals, FF:Plural(#deals)))
  for i = 1, math.min(4, #deals) do FF:Print("  " .. dealText(deals[i])) end
end

-- /ff vendors: best known merchants for resale, pinned on the map
function V:Command()
  if not self:Enabled() then FF:Print(FF:T("Vendor resale finder is off (Settings, Features).")) return end
  local best = self:Best()
  if #best == 0 then
    FF:Print(FF:T("No vendor resale found yet. Visit merchants (recipe vendors sell limited items) and scan the auction house."))
    return
  end
  local QH = FF.QuestHelper
  for i = 1, math.min(5, #best) do
    local b = best[i]
    FF:Print(FF:T("%s: %d item%s, up to %s profit"):format(b.npc, #b.deals, FF:Plural(#b.deals), FF:Money(b.total)))
    FF:Print("  " .. dealText(b.deals[1]))
    local s = b.spot
    if s.map and s.x and QH and QH.PinsEnabled and QH:PinsEnabled() and QH.TogglePin and not QH:IsPinned(s.map, s.x, s.y, b.npc) then
      pcall(QH.TogglePin, QH, s.map, s.x, s.y, b.npc, FF:T("Vendor resale: ") .. FF:ItemName(b.deals[1].id))
    end
  end
end

FF:On("MERCHANT_SHOW", function() pcall(V.OnMerchant, V) end)

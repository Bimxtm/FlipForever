-- Watch list price alerts (switch watchList): /ff watch <item> <price> keeps a list per realm.
-- During scans and while you browse the auction house, one chat line and a sound when a watched
-- item is listed at or below its price. Read only: nothing is bought for you.
local FF = FlipForever
local W = {}
FF.WatchList = W

local QUIET = 10 * 60 -- the same item is announced again after 10 minutes at the earliest
local told = {}

function W:Enabled() return FlipForeverDB ~= nil and FlipForeverDB.settings.watchList ~= false end

function W:List()
  local db = FF:DB()
  db.watch = db.watch or {}
  return db.watch
end

-- "1.5", "20g", "50s", "1g50s" -> copper (nil if not a price)
function W:ParseMoney(text)
  text = (text or ""):lower():gsub("%s+", "")
  if text == "" then return nil end
  local g, s = text:match("^(%d+)g(%d+)s?$")
  if g then return tonumber(g) * 10000 + tonumber(s) * 100 end
  local num, unit = text:match("^(%d*%.?%d+)([gsc]?)$")
  if not num then return nil end
  local mult = (unit == "s" and 100) or (unit == "c" and 1) or 10000
  local v = math.floor(tonumber(num) * mult + 0.5)
  return v > 0 and v or nil
end

-- an item link, an item ID or a known item name -> id
function W:ItemOf(text)
  text = text or ""
  local id = tonumber(text:match("item:(%d+)")) or tonumber(text:match("^(%d+)$"))
  if id then return id end
  local name = text:match("^%s*(.-)%s*$")
  if name ~= "" then
    local found = FF:IdFromName(name)
    if found then return found end
    local lower = name:lower()
    for i, n in pairs(FF:DB().names or {}) do
      if type(n) == "string" and n:lower() == lower then return i end
    end
  end
end

-- Sell alerts (switch watchSell): /ff watch sell <item> <price>. When the cheapest listing is at or
-- above your price, the item sells well right now: one chat line and a sound (same 10-minute quiet).
function W:SellEnabled() return FlipForeverDB ~= nil and FlipForeverDB.settings.watchSell ~= false end

function W:SellList()
  local db = FF:DB()
  db.watchSell = db.watchSell or {}
  return db.watchSell
end

function W:SeenSell(id, price, now)
  if not (self:SellEnabled() and id and price and price > 0) then return nil end
  local limit = self:SellList()[id]
  if not limit or price < limit then return nil end
  now = now or ((GetTime and GetTime()) or time())
  local key = "sell" .. id
  if told[key] and now - told[key] < QUIET then return nil end
  told[key] = now
  local have = GetItemCount and GetItemCount(id, true) or 0
  local line = FF:T("Sell alert: %s now sells at %s (your sell price %s)."):format(FF:ItemName(id), FF:Money(price), FF:Money(limit))
  if have and have > 0 then line = line .. " " .. FF:T("You have %d."):format(have) end
  local say = FF.Loud or FF.Print
  say(FF, "|cffffd200" .. line .. "|r")
  if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.AUCTION_WINDOW_OPEN or 5274, "Master") end
  return line
end

function W:SellCommand(rest)
  local list = self:SellList()
  if rest == "" then
    local rows = {}
    for id, limit in pairs(list) do rows[#rows + 1] = { FF:ItemName(id), limit } end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    if #rows == 0 then
      FF:Print(FF:T("No sell alerts. Add: /ff watch sell <item> <price>, for example /ff watch sell [Linen Cloth] 2g."))
    else
      FF:Print(FF:T("Sell alerts (%d): when the cheapest listing is at or above the price. Remove: /ff watch sell remove <item>."):format(#rows))
      for _, r in ipairs(rows) do FF:Print(("  %s: %s"):format(r[1], FF:Money(r[2]))) end
    end
    return
  end
  local removeArg = rest:match("^remove%s+(.+)$")
  if removeArg then
    local id = self:ItemOf(removeArg)
    if id and list[id] then
      list[id] = nil
      FF:Print(FF:T("Removed the sell alert for %s."):format(FF:ItemName(id)))
    else
      FF:Print(FF:T("That item has no sell alert."))
    end
    return
  end
  local itemText, priceText = rest:match("^(.-)%s+(%S+)$")
  local price = self:ParseMoney(priceText)
  local id = price and self:ItemOf(itemText)
  if not id then
    FF:Print(FF:T("Use /ff watch sell <item> <price>: shift-click the item (or type its name or ID), then the price like 2g, 1.5 or 50s."))
    return
  end
  list[id] = price
  told["sell" .. id] = nil
  FF:Print(FF:T("Sell alert for %s: you'll hear when it's listed at %s or more."):format(FF:ItemName(id), FF:Money(price)))
end

-- a price seen on the auction house; returns the alert line when it fires
function W:Seen(id, price, now)
  if id and price and price > 0 then pcall(self.SeenSell, self, id, price, now) end
  if not (self:Enabled() and id and price and price > 0) then return nil end
  local limit = self:List()[id]
  if not limit or price > limit then return nil end
  now = now or ((GetTime and GetTime()) or time())
  if told[id] and now - told[id] < QUIET then return nil end
  told[id] = now
  local line = FF:T("Watch list: %s is listed at %s (your price %s)."):format(FF:ItemName(id), FF:Money(price), FF:Money(limit))
  local say = FF.Loud or FF.Print
  say(FF, "|cff33ff99" .. line .. "|r")
  if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.AUCTION_WINDOW_OPEN or 5274, "Master") end
  return line
end

function W:Reset() told = {} end

function W:Command(rest)
  rest = rest or ""
  local list = self:List()
  local sellArg = rest:match("^sell%s*(.-)$")
  if sellArg and self:SellEnabled() then return self:SellCommand(sellArg) end
  if rest == "" then
    local rows = {}
    for id, limit in pairs(list) do rows[#rows + 1] = { FF:ItemName(id), limit } end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    if #rows == 0 then
      FF:Print(FF:T("Watch list is empty. Add: /ff watch <item> <price>, for example /ff watch [Linen Cloth] 50s."))
    else
      FF:Print(FF:T("Watch list (%d): alert when listed at or below the price. Remove: /ff watch remove <item>."):format(#rows))
      for _, r in ipairs(rows) do FF:Print(("  %s: %s"):format(r[1], FF:Money(r[2]))) end
    end
    return
  end
  local removeArg = rest:match("^remove%s+(.+)$")
  if removeArg then
    local id = self:ItemOf(removeArg)
    if id and list[id] then
      list[id] = nil
      FF:Print(FF:T("Removed %s from the watch list."):format(FF:ItemName(id)))
    else
      FF:Print(FF:T("That item is not on the watch list."))
    end
    return
  end
  -- the price is the last word, the item is everything before it
  local itemText, priceText = rest:match("^(.-)%s+(%S+)$")
  local price = self:ParseMoney(priceText)
  local id = price and self:ItemOf(itemText)
  if not id then
    FF:Print(FF:T("Use /ff watch <item> <price>: shift-click the item (or type its name or ID), then the price like 2g, 1.5 or 50s."))
    return
  end
  list[id] = price
  told[id] = nil
  FF:Print(FF:T("Watching %s: you'll hear about listings at or below %s."):format(FF:ItemName(id), FF:Money(price)))
end

-- full scans: check the cheapest listing of every watched item
local baseAddScan = FF.AddScan
function FF:AddScan(src, items)
  local n = baseAddScan(self, src, items)
  if W:Enabled() and type(items) == "table" then
    for id in pairs(W:List()) do
      local a = items[id]
      if a and a.min then pcall(W.Seen, W, id, a.min) end
    end
  end
  if W:SellEnabled() and type(items) == "table" then
    for id in pairs(W:SellList()) do
      local a = items[id]
      if a and a.min then pcall(W.SeenSell, W, id, a.min) end
    end
  end
  return n
end

local baseSlash = SlashCmdList.FLIPFOREVER
SlashCmdList.FLIPFOREVER = function(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
  if (cmd or ""):lower() == "watch" then
    FF.inSlash = true
    local ok, err = pcall(W.Command, W, rest)
    FF.inSlash = false
    if not ok then error(err, 0) end
    return
  end
  return baseSlash(msg)
end

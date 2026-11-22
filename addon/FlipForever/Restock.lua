-- Restock reminders for crafters (switch restock): items you craft (from your saved recipes) and
-- posted in the last 14 days, with none left on the auction house and none in your bags, get one
-- reminder per item and day when the auction house shows your auctions: craft and post again.
local FF = FlipForever
local R = {}
FF.Restock = R

local DAY = 86400

function R:Enabled() return FlipForeverDB.settings.restock ~= false end

-- item IDs your learned recipes make
function R:Crafted()
  local out = {}
  local P = FF.Professions
  if not (P and FF.Advisor and FF.Advisor.CharStore) then return out end
  local ok, store = pcall(P.Store, P)
  for _, prof in pairs(ok and store or {}) do
    for _, r in ipairs(prof.recipes or {}) do
      if r.learned and r.out then out[r.out] = true end
    end
  end
  return out
end

-- posted and sold counts per item in the last `days` days for this character
function R:Activity(days)
  local since, me = time() - (days or 14) * DAY, UnitName("player")
  local posted, sold = {}, {}
  local log = FF:DB().log
  for i = #log, 1, -1 do
    local e = log[i]
    if (e.t or 0) < since then break end
    if e.id and (e.char == nil or e.char == me) then
      if e.e == "post" then posted[e.id] = (posted[e.id] or 0) + (e.q or 1)
      elseif e.e == "sold" or e.e == "invoice" then sold[e.id] = (sold[e.id] or 0) + (e.q or 1) end
    end
  end
  return posted, sold
end

-- crafted items you sell that are gone: { id, name, sold }, most sold first
function R:Gone(owned)
  local crafted = self:Crafted()
  local posted, sold = self:Activity(14)
  local up = {}
  for _, a in ipairs(owned or {}) do up[a.id] = true end
  local out = {}
  for id in pairs(posted) do
    local inBags = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, false) or 0
    if crafted[id] and not up[id] and inBags == 0 then
      out[#out + 1] = { id = id, name = FF:ItemName(id), sold = sold[id] or 0 }
    end
  end
  table.sort(out, function(a, b) if a.sold ~= b.sold then return a.sold > b.sold end return a.id < b.id end)
  return out
end

-- one chat reminder per item and day
function R:Remind(owned)
  if not self:Enabled() then return 0 end
  local db = FF:DB()
  db.restockSeen = db.restockSeen or {}
  local today, n = math.floor(time() / DAY), 0
  for _, g in ipairs(self:Gone(owned)) do
    if db.restockSeen[g.id] ~= today then
      db.restockSeen[g.id] = today
      n = n + 1
      if n <= 3 then
        FF:Print(FF:T("Restock: %s is sold out (%d sold in the last 2 weeks) - craft and post it again."):format(g.name, g.sold))
      end
    end
  end
  if n > 3 then FF:Print(FF:T("Restock: %d more crafted items are sold out."):format(n - 3)) end
  return n
end

local asked = false
FF:On("AUCTION_HOUSE_SHOW", function()
  if not R:Enabled() then return end
  asked = true
  -- the undercut check asks for your auctions too; ask here when it is off
  if FlipForeverDB.settings.undercutCheck == false and C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
    pcall(C_AuctionHouse.QueryOwnedAuctions, {})
  end
end)
FF:On("OWNED_AUCTIONS_UPDATED", function()
  if not asked then return end
  asked = false
  if FF.Auctions then pcall(function() R:Remind(FF.Auctions:Owned()) end) end
end)

-- Your auctions: when the auction house opens, check which of your own listings are no
-- longer the cheapest in your newest scan, and say so once in chat (and on the Overview).
-- Nothing is cancelled here: the Trader (Trader.lua, "undercut fix") checks each one live and
-- offers a cancel only when reposting pays, one key press each.
local FF = FlipForever
local A = {}
FF.Auctions = A

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

-- owned auctions as { id, name, unit, qty } (unit price; the game reports commodities per unit)
function A:Owned()
  local AH = C_AuctionHouse
  if not (AH and AH.GetNumOwnedAuctions and AH.GetOwnedAuctionInfo) then return {} end
  local out = {}
  for i = 1, AH.GetNumOwnedAuctions() or 0 do
    local info = AH.GetOwnedAuctionInfo(i)
    local key = info and info.itemKey
    local id = key and plain(key.itemID)
    local unit = info and plain(info.buyoutAmount)
    -- status 1 = sold (waiting in the mail); only active listings count
    if id and unit and unit > 0 and plain(info.status) ~= 1 then
      out[#out + 1] = { id = id, name = FF:ItemName(id), unit = unit, qty = plain(info.quantity) or 1,
                        auctionID = plain(info.auctionID), timeLeft = plain(info.timeLeftSeconds) }
    end
  end
  return out
end

-- which of them the newest scan shows a cheaper listing for
function A:Check()
  local model = FF.Planner and FF.Planner:Model() or {}
  local owned = self:Owned()
  local under = {}
  for _, a in ipairs(owned) do
    local m = model[a.id]
    if m and m.cur_min and m.cur_min > 0 and m.cur_min < a.unit then
      under[#under + 1] = { id = a.id, name = a.name, mine = a.unit, now = m.cur_min, qty = a.qty,
                            auctionID = a.auctionID, timeLeft = a.timeLeft }
    end
  end
  table.sort(under, function(x, y) return (x.mine - x.now) * x.qty > (y.mine - y.now) * y.qty end)
  self.owned, self.undercut, self.checked = #owned, under, time()
  return under, #owned
end

function A:Line()
  if not self.owned then return nil end
  if self.owned == 0 then return FF:T("Your auctions: none up") end
  local n = #(self.undercut or {})
  if n == 0 then return FF:T("Your auctions: %d up, all still the cheapest"):format(self.owned) end
  return FF:T("Your auctions: %d up, |cffff8800%d undercut|r"):format(self.owned, n)
end

function A:Report()
  local under, total = self:Check()
  if #under == 0 then return end
  local first = under[1]
  local more = #under > 1 and (" " .. FF:T("(+%d more)"):format(#under - 1)) or ""
  FF:Print(FF:T("%d of your %d auctions are undercut. Biggest: %s (yours %s, now %s)."):format(
    #under, total, first.name, FF:Money(first.mine), FF:Money(first.now)) .. more)
  if FF.Trader and FF.Trader.UndercutOn and FF.Trader:UndercutOn() then
    FF:Print(FF:T("Press the FlipForever button: it checks each one live and offers to cancel and repost only where that pays after the deposit."))
  end
end

local asked = false
FF:On("AUCTION_HOUSE_SHOW", function()
  if FlipForeverDB.settings.undercutCheck == false then return end -- switched off in Settings
  asked = true
  if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
    pcall(C_AuctionHouse.QueryOwnedAuctions, {})
  end
end)
FF:On("OWNED_AUCTIONS_UPDATED", function()
  if not asked then return end
  asked = false -- one line per visit
  pcall(A.Report, A)
  -- the Advisor saves the result for the app with its next check
  if FF.Advisor and FF.Advisor.Refresh then pcall(FF.Advisor.Refresh, FF.Advisor) end
  if FF.Hub and FF.Hub.RefreshOverview then pcall(FF.Hub.RefreshOverview, FF.Hub) end
end)

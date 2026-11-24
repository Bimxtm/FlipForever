-- Expiry saver (switch expirySaver): an item whose auctions expired twice or more in a row (no sale
-- in between) isn't simply posted again at a loss. Before posting it, FlipForever compares what the
-- auction would bring (after the cut and the deposit) with what a merchant pays and what
-- disenchanting gives; when one of those pays as much, the item is held with a chat line saying
-- what to do instead. Tooltips show the streak and the options.
local FF = FlipForever
local X = {}
FF.ExpirySaver = X

X.STREAK = 2

function X:Enabled() return FlipForeverDB.settings.expirySaver ~= false end

-- auctions of this item that expired since its last sale (newest log entries first)
function X:Streak(id)
  if not id then return 0 end
  local log = FF:DB().log
  local name = FF.ItemName and FF:ItemName(id)
  local n = 0
  for i = #log, 1, -1 do
    local e = log[i]
    if e.id == id or (e.id == nil and name and e.name == name) then
      if e.e == "sold" or e.e == "invoice" then break end
      if e.e == "expired" then n = n + 1 end
    end
  end
  return n
end

-- what else the item is worth: merchant price and disenchant value (either can be nil)
function X:Options(id)
  local vendor = FF:VendorPrice(id)
  local de = FF.Disenchant and FF.Disenchant:Enabled() and FF.Disenchant:Value(id) or nil
  return vendor, de
end

-- Called before posting. price = the planned unit price, qty, deposit for the whole post, cut.
-- Returns true when the item should be held (a chat line says what to do instead).
function X:Check(id, price, qty, deposit, cut)
  if not self:Enabled() then return false end
  local streak = self:Streak(id)
  if streak < self.STREAK then return false end
  qty = math.max(1, qty or 1)
  local net = price * (1 - (cut or 0.05)) - (deposit or 0) / qty   -- per unit, if it sells this time
  local vendor, de = self:Options(id)
  local best, how = 0, nil
  if vendor and vendor > best then best, how = vendor, "vendor" end
  if de and de > best then best, how = de, "disenchant" end
  local item = FF:ItemName(id)
  if how and best >= net then
    if how == "vendor" then
      FF:Print(FF:T("Expiry saver: %s expired %d times in a row. A merchant pays %s, as much as posting it at %s would bring - sell it to a merchant."):format(
        item, streak, FF:Money(best), FF:Money(price)))
    else
      FF:Print(FF:T("Expiry saver: %s expired %d times in a row. Disenchanting gives ~%s, more than posting it at %s - disenchant it (or have it disenchanted)."):format(
        item, streak, FF:Money(best), FF:Money(price)))
    end
    FF:Log({ e = "hold", id = id, name = item, p = price, why = "expiry" })
    return true
  end
  FF:Print(FF:T("Expiry saver: %s expired %d times in a row - posting it at %s (the market price now)%s."):format(
    item, streak, FF:Money(price), how and (FF:T(", still more than the %s value of %s")):format(
      how == "vendor" and FF:T("merchant") or FF:T("disenchant"), FF:Money(best)) or ""))
  return false
end

-- tooltip lines: { left, right } (nothing below the streak)
function X:TooltipLines(id)
  if not self:Enabled() then return {} end
  local streak = self:Streak(id)
  if streak < self.STREAK then return {} end
  local vendor, de = self:Options(id)
  local opts = {}
  if vendor then opts[#opts + 1] = FF:T("merchant %s"):format(FF:Money(vendor)) end
  if de then opts[#opts + 1] = FF:T("disenchant ~%s"):format(FF:Money(de)) end
  return { { FF:T("  |cffff8800expired %d times in a row|r"):format(streak),
             #opts > 0 and table.concat(opts, ", ") or FF:T("try another price") } }
end

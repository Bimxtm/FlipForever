-- Auction session summary (switch ahSummary): when you close the auction house, one short summary of
-- what you bought, posted and sold while it was open, and how your gold changed. Read from the trade log.
local FF = FlipForever
local S = {}
FF.Session = S

function S:Enabled() return FlipForeverDB.settings.ahSummary ~= false end

function S:Start()
  local log = FF:DB().log
  self.t0, self.gold0, self.mark = time(), GetMoney and GetMoney() or 0, log[#log]
end

-- totals from the log since t0 (after the last entry before the auction house opened) for this character
function S:Totals(t0, mark)
  local me, r = UnitName("player"), { bought = 0, spent = 0, posted = 0, postValue = 0, sold = 0, cancelled = 0 }
  local log = FF:DB().log
  for i = #log, 1, -1 do
    local e = log[i]
    if e == mark or (e.t or 0) < t0 then break end
    if e.char == me then
      local q = e.q or 1
      if e.e == "buy" then r.bought, r.spent = r.bought + q, r.spent + q * (e.p or 0)
      elseif e.e == "post" then r.posted, r.postValue = r.posted + q, r.postValue + q * (e.p or 0)
      elseif e.e == "sold" then r.sold = r.sold + 1
      elseif e.e == "cancel" then r.cancelled = r.cancelled + 1 end
    end
  end
  return r
end

-- the summary line, or nil when nothing happened
function S:Text(r, change)
  if r.bought + r.posted + r.sold + r.cancelled == 0 then return nil end
  local parts = {}
  if r.bought > 0 then parts[#parts + 1] = FF:T("bought %d for %s"):format(r.bought, FF:Money(r.spent)) end
  if r.posted > 0 then parts[#parts + 1] = FF:T("posted %d worth %s"):format(r.posted, FF:Money(r.postValue)) end
  if r.sold > 0 then parts[#parts + 1] = FF:T("%d auction%s sold"):format(r.sold, FF:Plural(r.sold)) end
  if r.cancelled > 0 then parts[#parts + 1] = FF:T("%d cancelled"):format(r.cancelled) end
  local gold = change >= 0 and ("+" .. FF:Money(change)) or ("-" .. FF:Money(-change))
  return FF:T("Auction house session: %s. Gold: %s."):format(table.concat(parts, ", "), gold)
end

function S:Finish()
  local t0 = self.t0
  self.t0 = nil
  if not t0 or not self:Enabled() then return nil end
  local text = self:Text(self:Totals(t0, self.mark), (GetMoney and GetMoney() or 0) - (self.gold0 or 0))
  if text then FF:Print(text) end
  return text
end

FF:On("AUCTION_HOUSE_SHOW", function() S:Start() end)
FF:On("AUCTION_HOUSE_CLOSED", function() pcall(S.Finish, S) end)

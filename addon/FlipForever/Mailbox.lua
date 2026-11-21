-- Mailbox: "Open all mail" takes the gold and the items from every mail in one click, one at a time
-- (the server has to answer each one). Mail with cash on delivery is skipped, and it stops when
-- your bags are full. Setting: mailOpenAll (the button, on by default).
local FF = FlipForever
local MB = {}
FF.Mailbox = MB

local ATTACH_MAX = 16 -- attachments a mail can carry
local button, run

function MB:Enabled() return FlipForeverDB.settings.mailOpenAll ~= false end

local function header(i)
  local _, _, _, _, money, cod, _, itemCount = GetInboxHeaderInfo(i)
  return money or 0, cod or 0, itemCount or 0
end

local function freeSlots()
  local C = C_Container
  if not (C and C.GetContainerNumFreeSlots) then return 99 end
  local n = 0
  for bag = 0, 4 do n = n + (C.GetContainerNumFreeSlots(bag) or 0) end
  return n
end

-- what can be taken: list of mails with gold or items and no cash on delivery
function MB:Open()
  local n = GetInboxNumItems and GetInboxNumItems() or 0
  local mails, gold, items = 0, 0, 0
  for i = 1, n do
    local money, cod, count = header(i)
    if cod == 0 and (money > 0 or count > 0) then
      mails, gold, items = mails + 1, gold + money, items + count
    end
  end
  return mails, gold, items
end

function MB:Refresh()
  if not button then return end
  if not self:Enabled() then button:Hide() return end
  button:Show()
  local mails, gold, items = self:Open()
  if run then
    button:SetText(FF:T("Opening..."))
    button:SetEnabled(false)
  elseif mails > 0 then
    button:SetText(FF:T("Open all mail (%d)"):format(mails))
    button:SetEnabled(true)
  else
    button:SetText(FF:T("No mail to open"))
    button:SetEnabled(false)
  end
end

local function finish(reason)
  local r = run
  run = nil
  if r and (r.gold > 0 or r.items > 0) then
    FF:Print(FF:T("Opened mail: %s and %d item%s."):format(FF:Money(r.gold), r.items, FF:Plural(r.items)))
  end
  if reason then FF:Print(reason) end
  MB:Refresh()
end

-- one step: wait for the last request to land, then take the next gold or item
function MB:Step()
  local r = run
  if not r then return end
  local w = r.wait
  if w then
    local n = GetInboxNumItems()
    local money, _, count = 0, 0, 0
    if n == w.num then money, _, count = header(w.i) end
    local landed = n ~= w.num or money ~= w.money or count ~= w.count
    if not landed and w.tries < 15 then
      w.tries = w.tries + 1
      C_Timer.After(0.25, function() MB:Step() end)
      return
    end
    r.wait = nil
    if landed then
      if w.kind == "money" then r.gold = r.gold + w.money else r.items = r.items + 1 end
    else
      r.skip[w.i .. ":" .. w.kind .. ":" .. w.money .. ":" .. w.count] = true -- the server refused: don't retry it
    end
  end
  for i = GetInboxNumItems(), 1, -1 do
    local money, cod, count = header(i)
    if cod == 0 then
      local key = i .. ":"
      if money > 0 and not r.skip[key .. "money:" .. money .. ":" .. count] then
        r.wait = { i = i, kind = "money", money = money, count = count, num = GetInboxNumItems(), tries = 0 }
        TakeInboxMoney(i)
        C_Timer.After(0.25, function() MB:Step() end)
        return
      end
      if count > 0 and not r.skip[key .. "item:" .. money .. ":" .. count] then
        if freeSlots() == 0 then return finish(FF:T("Your bags are full - the rest of the mail stays in the mailbox.")) end
        for a = 1, ATTACH_MAX do
          if GetInboxItem(i, a) then
            r.wait = { i = i, kind = "item", money = money, count = count, num = GetInboxNumItems(), tries = 0 }
            TakeInboxItem(i, a)
            C_Timer.After(0.25, function() MB:Step() end)
            return
          end
        end
      end
    end
  end
  finish()
end

function MB:OpenAll()
  if run or not (GetInboxNumItems and GetInboxHeaderInfo and TakeInboxMoney and TakeInboxItem) then return end
  run = { gold = 0, items = 0, skip = {} }
  self:Refresh()
  self:Step()
end

FF:On("MAIL_SHOW", function()
  if not button then
    button = CreateFrame("Button", "FlipForeverOpenAllButton", MailFrame or UIParent, "UIPanelButtonTemplate")
    button:SetSize(190, 24)
    button:SetPoint("TOPLEFT", MailFrame or UIParent, "TOPRIGHT", 4, -58)
    button:SetScript("OnClick", function() MB:OpenAll() end)
  end
  MB:Refresh()
end)
FF:On("MAIL_INBOX_UPDATE", function() MB:Refresh() end)
FF:On("MAIL_CLOSED", function() if run then finish() end end)

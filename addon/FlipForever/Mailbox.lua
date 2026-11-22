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

-- Send to alt (switch sendToAlt): one click mails crafting materials and flip stock (up to 12 stacks
-- per mail) to a character of yours on this realm and faction. Right-click picks the next character.
local SEND_MAX = 12 -- attachments per sent mail
local altButton, sending

function MB:AltEnabled() return FlipForeverDB.settings.sendToAlt ~= false end

-- your other characters here (same realm and faction), sorted
function MB:Alts()
  local me, list = UnitName("player"), {}
  for name in pairs(FF:DB().chars or {}) do
    if name ~= me then list[#list + 1] = name end
  end
  table.sort(list)
  return list
end

-- the chosen character (kept per realm), or the first one
function MB:Alt()
  local alts, r = self:Alts(), FF:DB()
  for _, n in ipairs(alts) do if n == r.sendAlt then return n end end
  return alts[1]
end

function MB:NextAlt()
  local alts, cur = self:Alts(), self:Alt()
  if #alts == 0 then return nil end
  local pick = alts[1]
  for i, n in ipairs(alts) do if n == cur then pick = alts[i % #alts + 1] end end
  FF:DB().sendAlt = pick
  self:RefreshAlt()
  return pick
end

-- flip stock: items on this character's sell list or bought by FlipForever
local function stockIds()
  local ids = {}
  local plan = FF:Plan()
  for _, e in ipairs(plan and plan.sell or {}) do if e.id then ids[tonumber(e.id) or e.id] = true end end
  local prog = FF.Progress and FF:Progress()
  for id in pairs(prog and prog.bought or {}) do ids[tonumber(id) or id] = true end
  return ids
end

-- bag stacks to send: trade goods (crafting materials) and flip stock, never soulbound items
function MB:AltItems()
  local C, out, stock = C_Container, {}, stockIds()
  if not (C and C.GetContainerItemInfo) then return out end
  for bag = 0, 4 do
    for slot = 1, (C.GetContainerNumSlots and C.GetContainerNumSlots(bag) or 0) do
      local info = C.GetContainerItemInfo(bag, slot)
      local id = info and info.itemID
      if id and not info.isBound then
        local classID = select(6, C_Item.GetItemInfoInstant(id))
        if classID == 7 or stock[id] then out[#out + 1] = { bag = bag, slot = slot, id = id } end
      end
    end
  end
  return out
end

function MB:RefreshAlt()
  if not altButton then return end
  if not self:AltEnabled() then altButton:Hide() return end
  altButton:Show()
  local alt, n = self:Alt(), #self:AltItems()
  if sending then
    altButton:SetText(FF:T("Sending..."))
    altButton:SetEnabled(false)
  elseif not alt then
    altButton:SetText(FF:T("Send to alt: no other character yet"))
    altButton:SetEnabled(false)
  elseif n == 0 then
    altButton:SetText(FF:T("Nothing to send to %s"):format(alt))
    altButton:SetEnabled(false)
  else
    altButton:SetText(FF:T("Send to %s (%d)"):format(alt, n))
    altButton:SetEnabled(true)
  end
end

-- one mail with up to 12 stacks; the next click sends the rest after the server confirms
function MB:SendToAlt()
  local alt = self:Alt()
  if sending or not alt or not (SendMail and ClickSendMailItemButton and C_Container.PickupContainerItem) then return false end
  local items = self:AltItems()
  if #items == 0 then return false end
  if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, 2) end
  if ClearSendMail then ClearSendMail() end
  local n = math.min(SEND_MAX, #items)
  for i = 1, n do
    C_Container.PickupContainerItem(items[i].bag, items[i].slot)
    ClickSendMailItemButton(i)
  end
  sending = { alt = alt, n = n, rest = #items - n }
  SendMail(alt, FF:T("FlipForever: materials and stock"), "")
  self:RefreshAlt()
  return true
end

local function sent(ok)
  local s = sending
  if not s then return end
  sending = nil
  if ok then
    FF:Print(FF:T("Sent %d stack%s to %s."):format(s.n, FF:Plural(s.n), s.alt)
      .. (s.rest > 0 and (" " .. FF:T("Click again to send the rest (%d)."):format(s.rest)) or ""))
  else
    FF:Print(FF:T("The mail to %s was not sent."):format(s.alt))
  end
  MB:RefreshAlt()
end

FF:On("MAIL_SHOW", function()
  if not button then
    button = CreateFrame("Button", "FlipForeverOpenAllButton", MailFrame or UIParent, "UIPanelButtonTemplate")
    button:SetSize(190, 24)
    button:SetPoint("TOPLEFT", MailFrame or UIParent, "TOPRIGHT", 4, -58)
    button:SetScript("OnClick", function() MB:OpenAll() end)
  end
  if not altButton then
    altButton = CreateFrame("Button", "FlipForeverSendAltButton", MailFrame or UIParent, "UIPanelButtonTemplate")
    altButton:SetSize(190, 24)
    altButton:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -4)
    altButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    altButton:SetScript("OnClick", function(_, mouse)
      if mouse == "RightButton" then MB:NextAlt() else MB:SendToAlt() end
    end)
    altButton:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(FF:T("Send to alt"))
      GameTooltip:AddLine(FF:T("Mails crafting materials and flip stock (up to 12 stacks per click). Right-click: next character."), 1, 1, 1, true)
      GameTooltip:Show()
    end)
    altButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  MB:Refresh()
  MB:RefreshAlt()
end)
FF:On("MAIL_INBOX_UPDATE", function() MB:Refresh() end)
FF:On("BAG_UPDATE_DELAYED", function() if altButton and altButton:IsVisible() then MB:RefreshAlt() end end)
FF:On("MAIL_SEND_SUCCESS", function() sent(true) end)
FF:On("MAIL_FAILED", function() sent(false) end)
FF:On("MAIL_CLOSED", function() if run then finish() end if sending then sent(false) end end)

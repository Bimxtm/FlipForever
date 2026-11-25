-- Alt item counts in tooltips (switch altCounts): how many of an item each of your characters on
-- this realm holds in bags, bank and mail. Bags are read as they change, the bank when you open
-- it, the mailbox when you look at it; each character's numbers stay from its last visit.
local FF = FlipForever
local A = {}
FF.AltCounts = A

function A:Enabled() return FlipForeverDB ~= nil and FlipForeverDB.settings.altCounts ~= false end

local function record()
  local name = UnitName and UnitName("player")
  if not name then return nil end
  local chars = FF:DB().chars
  chars[name] = chars[name] or {}
  local c = chars[name]
  c.items = c.items or {}
  return c.items
end

local function readContainers(list)
  local C = C_Container
  if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
  local out = {}
  for _, bag in ipairs(list) do
    local ok, slots = pcall(C.GetContainerNumSlots, bag)
    for slot = 1, (ok and slots or 0) do
      local okI, info = pcall(C.GetContainerItemInfo, bag, slot)
      local id = okI and info and info.itemID
      if id and not (issecretvalue and issecretvalue(id)) then
        out[id] = (out[id] or 0) + (info.stackCount or 1)
      end
    end
  end
  return out
end

function A:ReadBags()
  local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
  local list = {}
  for b = 0, last do list[#list + 1] = b end
  local got = readContainers(list)
  local r = record()
  if got and r then r.bags = got r.t = time() end
end

function A:ReadBank()
  local list = { BANK_CONTAINER or -1 }
  local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1
  for b = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do list[#list + 1] = b end
  if REAGENTBANK_CONTAINER then list[#list + 1] = REAGENTBANK_CONTAINER end
  local got = readContainers(list)
  local r = record()
  if got and r then r.bank = got end
end

function A:ReadMail()
  if not (GetInboxNumItems and GetInboxItem) then return end
  local out = {}
  for i = 1, GetInboxNumItems() do
    for j = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
      local ok, _, id, _, count = pcall(GetInboxItem, i, j)
      if ok and id and not (issecretvalue and issecretvalue(id)) then
        out[id] = (out[id] or 0) + (count or 1)
      end
    end
  end
  local r = record()
  if r then r.mail = out end
end

-- per character: { name, total, bags, bank, mail }, most first
function A:Counts(id)
  local out = {}
  for name, c in pairs(FF:DB().chars or {}) do
    local it = type(c) == "table" and c.items
    if it then
      local bags = it.bags and it.bags[id] or 0
      local bank = it.bank and it.bank[id] or 0
      local mail = it.mail and it.mail[id] or 0
      local total = bags + bank + mail
      if total > 0 then out[#out + 1] = { name = name, total = total, bags = bags, bank = bank, mail = mail } end
    end
  end
  table.sort(out, function(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.name < b.name
  end)
  return out
end

-- the tooltip line, nil when no character holds any
function A:TooltipLine(id)
  if not (self:Enabled() and id) then return nil end
  local list = self:Counts(id)
  if #list == 0 then return nil end
  local parts, sum = {}, 0
  for i, e in ipairs(list) do
    sum = sum + e.total
    if i <= 4 then
      local where = {}
      if e.bank > 0 then where[#where + 1] = FF:T("bank %d"):format(e.bank) end
      if e.mail > 0 then where[#where + 1] = FF:T("mail %d"):format(e.mail) end
      parts[#parts + 1] = e.name .. " " .. e.total .. (#where > 0 and (" (" .. table.concat(where, ", ") .. ")") or "")
    end
  end
  if #list > 4 then parts[#parts + 1] = FF:T("+%d more"):format(#list - 4) end
  return { FF:T("  you have %d"):format(sum), table.concat(parts, ", ") }
end

local pending = false
local function bagsSoon()
  if pending or not A:Enabled() then return end
  pending = true
  local function go() pending = false pcall(A.ReadBags, A) end
  if C_Timer and C_Timer.After then C_Timer.After(2, go) else go() end
end

local bankOpen = false
FF:On("PLAYER_LOGIN", bagsSoon)
FF:On("BAG_UPDATE_DELAYED", function()
  bagsSoon()
  if bankOpen and A:Enabled() then pcall(A.ReadBank, A) end
end)
FF:On("BANKFRAME_OPENED", function()
  bankOpen = true
  if A:Enabled() then pcall(A.ReadBank, A) end
end)
FF:On("PLAYERBANKSLOTS_CHANGED", function()
  if bankOpen and A:Enabled() then pcall(A.ReadBank, A) end
end)
FF:On("BANKFRAME_CLOSED", function() bankOpen = false end)
FF:On("MAIL_INBOX_UPDATE", function()
  if A:Enabled() then pcall(A.ReadMail, A) end
end)
FF:On("PLAYER_LOGOUT", function()
  if A:Enabled() then pcall(A.ReadBags, A) end
end)

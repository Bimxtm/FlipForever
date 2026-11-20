-- FlipForever: core (saved data, logging, sale/expiry tracking, slash commands)
local ADDON = ...

local FF = {}
_G.FlipForever = FF

FF.version = "1.0.0"
local MAX_SCANS = 60       -- scan snapshots kept in SavedVariables (app imports them)
local MAX_LOG = 5000       -- trade log entries kept

local frame = CreateFrame("Frame")
FF.eventFrame = frame
local handlers = {}

function FF:On(event, fn)
  handlers[event] = handlers[event] or {}
  table.insert(handlers[event], fn)
  frame:RegisterEvent(event)
end

frame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  for _, fn in ipairs(list) do
    local ok, err = pcall(fn, ...)
    if not ok then FF:Print("|cffff5555error in " .. event .. ":|r " .. tostring(err)) end
  end
end)

function FF:Print(...)
  print("|cff33ff99FlipForever|r:", ...)
end

-- Gold formatting -----------------------------------------------------------
function FF:Money(copper)
  copper = tonumber(copper) or 0
  if copper ~= copper or copper == math.huge or copper == -math.huge then return "-" end -- no limit / not a number
  copper = math.floor(copper)
  if GetCoinTextureString then return GetCoinTextureString(copper) end
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  if g > 0 then return ("%dg %ds %dc"):format(g, s, c) end
  if s > 0 then return ("%ds %dc"):format(s, c) end
  return ("%dc"):format(c)
end

-- Saved data -----------------------------------------------------------------
function FF:RealmKey()
  local realm = GetRealmName() or "Unknown"
  local faction = UnitFactionGroup("player") or "Neutral"
  return realm .. " - " .. faction
end

function FF:DB()
  local key = self:RealmKey()
  local realms = FlipForeverDB.realms
  realms[key] = realms[key] or {}
  local r = realms[key]
  r.scans = r.scans or {}
  r.log = r.log or {}
  r.names = r.names or {}
  r.charProgress = r.charProgress or {}
  r.chars = r.chars or {}
  return r
end

-- "Name @ Realm - Faction": how the app tells your characters apart
function FF:CharKey()
  return (UnitName("player") or "?") .. " @ " .. self:RealmKey()
end

-- The shopping list for the character you're playing (the app writes one per character)
function FF:Plan()
  local plans = _G.FlipForever_Plans
  if plans then return plans[self:CharKey()] end
  return _G.FlipForever_Plan
end

-- Remember each character's gold so the app can show it and size budgets
function FF:UpdateChar()
  local name = UnitName("player")
  if not name then return end
  local _, class = UnitClass("player")
  self:DB().chars[name] = { money = GetMoney(), level = UnitLevel("player"), class = class, t = time() }
end

function FF:Log(entry)
  entry.t = entry.t or time()
  entry.char = UnitName("player")
  local log = self:DB().log
  table.insert(log, entry)
  while #log > MAX_LOG do table.remove(log, 1) end
end

-- items[id] = { min=, p25=, qty=, n= }
function FF:AddScan(src, items)
  local parts, count = {}, 0
  for id, a in pairs(items) do
    count = count + 1
    parts[#parts + 1] = ("%d:%d:%d:%d:%d"):format(id, a.min, a.p25 or a.min, a.qty, a.n)
  end
  if count == 0 then return 0 end
  local scans = self:DB().scans
  table.insert(scans, { t = time(), src = src, n = count, d = table.concat(parts, ";") })
  while #scans > MAX_SCANS do table.remove(scans, 1) end
  return count
end

function FF:SetName(id, name)
  if id and name and name ~= "" then self:DB().names[id] = name end
end

function FF:ItemName(id)
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if name then self:SetName(id, name) return name end
  return self:DB().names[id] or ("item:" .. tostring(id))
end

function FF:IdFromName(name)
  for id, n in pairs(self:DB().names) do
    if n == name then return id end
  end
end

-- Progress on the current shopping list survives /reload
function FF:Progress()
  local db = self:DB()
  local plan = self:Plan()
  local gen = plan and plan.generated or 0
  local name = UnitName("player") or "?"
  local p = db.charProgress[name]
  if not p or p.gen ~= gen then
    p = { gen = gen, bought = {}, spent = 0 }
    db.charProgress[name] = p
  end
  return p
end

-- Status line shown on the panel (UI.lua overrides the sink) ----------------
FF.status = "Ready."
function FF:SetStatus(text)
  self.status = text
  -- a display problem must never break scanning/buying
  if self.OnStatus then pcall(self.OnStatus, self, text) end
end

-- Sale / expiry tracking -----------------------------------------------------
local function formatToPattern(fmt)
  if not fmt then return nil end
  local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  p = p:gsub("%%%%s", "(.+)")
  p = p:gsub("%%%%%d%%%$s", "(.+)") -- positional "%1$s" (escaped as "%%1%$s")
  return "^" .. p .. "$"
end

local SOLD = formatToPattern(_G.ERR_AUCTION_SOLD_S)
local EXPIRED = formatToPattern(_G.ERR_AUCTION_EXPIRED_S)

FF:On("CHAT_MSG_SYSTEM", function(msg)
  if not msg then return end
  local name = SOLD and msg:match(SOLD)
  if name then
    FF:Log({ e = "sold", name = name, id = FF:IdFromName(name) })
    return
  end
  name = EXPIRED and msg:match(EXPIRED)
  if name then
    FF:Log({ e = "expired", name = name, id = FF:IdFromName(name) })
  end
end)

-- Mail invoices carry the exact sale price; record each once.
local function scanInvoices()
  if not GetInboxNumItems or not GetInboxInvoiceInfo then return end
  local seen = FlipForeverDB.seenInvoices
  local now = time()
  for i = 1, GetInboxNumItems() do
    local invoiceType, itemName, _, bid, _, deposit, consignment, _, _, _, count = GetInboxInvoiceInfo(i)
    if invoiceType == "seller" and itemName and bid then
      local daysLeft = select(7, GetInboxHeaderInfo(i)) or 30
      local received = now - math.floor((30 - daysLeft) * 86400)
      local hour = math.floor(received / 3600)
      local base = itemName .. "|" .. bid .. "|" .. (count or 1) .. "|"
      if not (seen[base .. hour] or seen[base .. (hour - 1)] or seen[base .. (hour + 1)]) then
        seen[base .. hour] = now
        FF:Log({
          e = "invoice", name = itemName, id = FF:IdFromName(itemName), q = count or 1,
          gross = bid, cut = consignment or 0, dep = deposit or 0, t = received,
        })
      end
    end
  end
  -- forget invoice keys older than 35 days
  for k, t in pairs(seen) do
    if now - t > 35 * 86400 then seen[k] = nil end
  end
end

FF:On("MAIL_INBOX_UPDATE", scanInvoices)

-- Startup ------------------------------------------------------------------------
FF:On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  FlipForeverDB = FlipForeverDB or {}
  FlipForeverDB.version = 1
  FlipForeverDB.realms = FlipForeverDB.realms or {}
  FlipForeverDB.seenInvoices = FlipForeverDB.seenInvoices or {}
  FlipForeverDB.settings = FlipForeverDB.settings or {}
end)

FF:On("PLAYER_LOGIN", function()
  FF:DB()
  FF:UpdateChar()
  local plan = FF:Plan()
  if plan and plan.buy then
    FF:Print(("Shopping list for %s loaded: %d to buy, %d to sell, budget %s. Open the auction house to start."):format(
      UnitName("player"), #plan.buy, #(plan.sell or {}), FF:Money(plan.budget or 0)))
  else
    FF:Print(("Loaded. No shopping list for %s yet - scan at the auction house, then pick this character in the app and build one."):format(UnitName("player") or "?"))
  end
end)

FF:On("PLAYER_MONEY", function() FF:UpdateChar() end)
FF:On("PLAYER_LOGOUT", function() FF:UpdateChar() end)

-- Slash commands ------------------------------------------------------------------
SLASH_FLIPFOREVER1 = "/ff"
SLASH_FLIPFOREVER2 = "/flipforever"
SlashCmdList.FLIPFOREVER = function(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "scan" then
    FF.Scan:StartFull()
  elseif cmd == "buy" then
    FF.Trader:StartBuying()
  elseif cmd == "sell" then
    FF.Trader:StartSelling()
  elseif cmd == "stop" then
    FF.Trader:Stop()
  elseif cmd == "guide" or cmd == "advisor" or cmd == "next" then
    FF.Advisor:Toggle()
  elseif cmd == "combat" then
    FF.Combat:Toggle()
  elseif cmd == "combatkey" then
    FF.Combat:SetKey(rest ~= "" and rest:upper() or nil)
  elseif cmd == "combatmode" then
    FF.Combat:ToggleBlizzard()
  elseif cmd == "gather" or cmd == "ore" then
    local ns = FF.gatherNS
    if ns and ns.ToggleMain and not ns.skipGather then ns.ToggleMain() else FF:Print("Gathering is off (the old Ore Farmer addon is still enabled).") end
  elseif cmd == "auto" then
    FF.Auto:SetEnabled(not FF.Auto:Enabled())
  elseif cmd == "key" then
    FF:SetActionKey(rest ~= "" and rest:upper() or nil)
  elseif cmd == "reset" then
    FF:ResetProgress()
  elseif cmd == "" or cmd == "show" or cmd == "options" or cmd == "settings" then
    if FF.Hub then FF.Hub:Toggle() end
  else
    FF:Print("/ff opens the FlipForever window (or click the gold coin on the minimap). Commands: guide | combat | combatkey <KEY> | combatmode | gather | scan | buy | sell | stop | auto | key <KEY> | reset")
  end
end

-- Shared by the window and the commands ------------------------------------------------------------
-- The auction house action key (the big button); returns true when it was set.
function FF:SetActionKey(key)
  local clash = key and (FF:KeyConflict(key) or (key == FlipForeverDB.settings.combatKey and "FlipForever's combat helper key"))
  if clash then
    FF:Print(("|cffff5555%s is already used by %s|r - pick another key, e.g. CTRL-SPACE"):format(key, clash))
    return false
  end
  FlipForeverDB.settings.key = key
  FF:Print(key and ("Action key set to |cffffff00" .. key .. "|r (only active while the auction house is open).")
    or "Action key cleared.")
  if FF.UI then FF.UI:ApplyKey() end
  if FF.Hub then FF.Hub:Refresh() end
  return true
end

-- Today's trading for the character you're playing (since local midnight)
function FF:Today()
  local d = date("*t")
  local start = time({ year = d.year, month = d.month, day = d.day, hour = 0 })
  local me = UnitName("player")
  local r = { sold = 0, sales = 0, spent = 0, buys = 0 }
  for _, e in ipairs(self:DB().log) do
    if (e.t or 0) >= start and (e.char == nil or e.char == me) then
      if e.e == "invoice" then
        r.sold = r.sold + (e.gross or 0) - (e.cut or 0)
        r.sales = r.sales + 1
      elseif e.e == "buy" then
        r.spent = r.spent + (e.q or 0) * (e.p or 0)
        r.buys = r.buys + 1
      end
    end
  end
  return r
end

function FF:TodayLine()
  local t = self:Today()
  if t.sales == 0 and t.buys == 0 then return "Today: no trades yet" end
  return ("Today: sold %s (%d)  ·  bought %s (%d)"):format(self:Money(t.sold), t.sales, self:Money(t.spent), t.buys)
end

function FF:ResetProgress()
  FF:DB().charProgress[UnitName("player") or "?"] = nil
  FF:Print("Shopping list progress reset - every item on the list will be checked again.")
end

-- Is this key already used at the auction house by another addon (or a normal binding)?
function FF:KeyConflict(key)
  local cfg = _G.AUCTIONATOR_CONFIG
  if type(cfg) == "table" then
    for name, value in pairs(cfg) do
      if type(name) == "string" and name:find("shortcut") and type(value) == "string" and value:upper() == key then
        return "Auctionator (" .. name:gsub("_", " ") .. ")"
      end
    end
  end
  -- another addon holding this key right now (e.g. Schmendrick's one-key fishing, EllesmereUI Quickdraw)
  if GetBindingAction then
    local okO, over = pcall(GetBindingAction, key, true)
    local okN, normal = pcall(GetBindingAction, key)
    if okO and over and over ~= "" and over ~= (okN and normal or "") and not over:find("FlipForever") then
      return "another addon (" .. over .. ")"
    end
  end
  local action = GetBindingAction and GetBindingAction(key)
  if action and action ~= "" then
    -- normal game bindings are only overridden while the AH is open; allow, but say so
    FF:Print(("Note: %s normally does '%s'; while the auction house is open it will press the FlipForever button instead."):format(key, action))
  end
  return nil
end

-- A key saved before this check existed might clash: drop it at login.
FF:On("PLAYER_LOGIN", function()
  local key = FlipForeverDB.settings.key
  if key and FF:KeyConflict(key) then
    FF:Print(("Your action key %s clashes with %s - cleared. Pick another: /ff key CTRL-SPACE"):format(key, FF:KeyConflict(key)))
    FlipForeverDB.settings.key = nil
  end
end)

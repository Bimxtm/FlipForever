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
    if not ok then
      FF:Print("|cffff5555error in " .. event .. ":|r " .. tostring(err))
      FF:RecordError(event, err)
    end
  end
end)

-- the last 20 errors, kept for bug reports (the app's "Copy bug report info" reads them)
function FF:RecordError(where, err)
  if type(FlipForeverDB) ~= "table" then return end
  local list = FlipForeverDB.errors or {}
  FlipForeverDB.errors = list
  local meta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  local version = meta and meta("FlipForever", "Version") or "?"
  table.insert(list, { t = time and time() or 0, v = version, where = tostring(where), msg = tostring(err):sub(1, 300) })
  while #list > 20 do table.remove(list, 1) end
end

function FF:Print(...)
  print("|cff33ff99FlipForever|r:", ...)
end

-- the random-stat suffix of an item link ("of the Bear"), 0 when it has none
function FF:LinkSuffix(link)
  if type(link) ~= "string" then return 0 end
  local s = select(7, link:match("item:(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*)"))
  return tonumber(s) or 0
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

-- The shopping list the app wrote for the character you're playing (one per character)
function FF:FilePlan()
  local plans = _G.FlipForever_Plans
  if plans then return plans[self:CharKey()] end
  return _G.FlipForever_Plan
end

-- The list in use: the in-game planner's (Planner.lua) when it's newer than the app's
function FF:Plan()
  local file = self:FilePlan()
  local live = self.livePlan
  if live and live.key == self:CharKey() and (not file or (live.generated or 0) > (file.generated or 0)) then
    return live
  end
  return file
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

-- what a merchant pays for one (nil if unknown or not sellable)
function FF:VendorPrice(id)
  local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not (fn and id) then return nil end
  local res = { pcall(fn, id) }
  if not res[1] then return nil end
  local p = res[12]                    -- 11th return value: sell price
  if issecretvalue and p ~= nil and issecretvalue(p) then return nil end
  return (type(p) == "number" and p > 0) and p or nil
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
        FF.mailNew = FF.mailNew or { n = 0, gold = 0 }
        FF.mailNew.n = FF.mailNew.n + 1
        FF.mailNew.gold = FF.mailNew.gold + bid - (consignment or 0)
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

-- one summary line per mailbox visit: what sold since you last looked
local summaryQueued = false
local function mailSummary()
  summaryQueued = false
  local m = FF.mailNew
  if m and m.n > 0 then
    FF:Print(("|cffffd200Mail:|r %d auction%s sold since your last visit, |cff33ff99+%s|r after the AH cut."):format(
      m.n, m.n > 1 and "s" or "", FF:Money(m.gold)))
  end
  FF.mailNew = nil
end

FF:On("MAIL_INBOX_UPDATE", function()
  scanInvoices()
  if FF.mailNew and not summaryQueued then
    summaryQueued = true
    C_Timer.After(1.5, mailSummary) -- the inbox fills in a few updates; summarise once
  end
end)
FF:On("MAIL_SHOW", function() FF.mailNew, summaryQueued = nil, false end)

-- Collect auction gold: takes the money from sale invoices, one mail at a time.
-- Mail with items or COD (won auctions, expired items, letters) is never touched.
local collecting, mailButton

local function isSaleMail(i)
  if GetInboxInvoiceInfo(i) ~= "seller" then return false end
  local _, _, _, _, money, cod, _, itemCount = GetInboxHeaderInfo(i)
  return (money or 0) > 0 and (cod or 0) == 0 and (itemCount or 0) == 0, money or 0
end

function FF:SaleMail()
  local n, gold = 0, 0
  if not GetInboxNumItems then return n, gold end
  for i = 1, GetInboxNumItems() do
    local ok, money = isSaleMail(i)
    if ok then n, gold = n + 1, gold + money end
  end
  return n, gold
end

function FF:UpdateMailButton()
  if not mailButton then return end
  local n, gold = FF:SaleMail()
  if collecting then
    mailButton:SetText(FF:T("Collecting..."))
    mailButton:SetEnabled(false)
  elseif n > 0 then
    mailButton:SetText(FF:T("Collect auction gold") .. " (" .. FF:Money(gold) .. ")")
    mailButton:SetEnabled(true)
  else
    mailButton:SetText(FF:T("No auction gold"))
    mailButton:SetEnabled(false)
  end
end

local function collectDone()
  local c = collecting
  collecting = nil
  if c and c.n > 0 then
    FF:Print(FF:T("Collected %s from %d sale mails."):format(FF:Money(c.gold), c.n))
  end
  FF:UpdateMailButton()
end

local function collectNext()
  local c = collecting
  if not c then return end
  local w = c.wait
  if w then
    -- wait until the server has handed over the money before taking the next one
    local still = GetInboxNumItems() == w.num and isSaleMail(w.i)
    if still and w.tries < 15 then
      w.tries = w.tries + 1
      C_Timer.After(0.2, collectNext)
      return
    end
    c.wait = nil
    if not still then c.n, c.gold = c.n + 1, c.gold + w.money end
  end
  for i = GetInboxNumItems(), 1, -1 do
    local ok, money = isSaleMail(i)
    if ok and not c.tried[i .. ":" .. money] then
      c.tried[i .. ":" .. money] = true
      c.wait = { i = i, money = money, num = GetInboxNumItems(), tries = 0 }
      TakeInboxMoney(i)
      C_Timer.After(0.2, collectNext)
      return
    end
  end
  collectDone()
end

function FF:CollectAuctionGold()
  if collecting then return end
  collecting = { n = 0, gold = 0, tried = {} }
  FF:UpdateMailButton()
  collectNext()
end

FF:On("MAIL_SHOW", function()
  if not mailButton then
    mailButton = CreateFrame("Button", "FlipForeverMailButton", MailFrame or UIParent, "UIPanelButtonTemplate")
    mailButton:SetSize(190, 24)
    mailButton:SetPoint("TOPLEFT", MailFrame or UIParent, "TOPRIGHT", 4, -30)
    mailButton:SetScript("OnClick", function() FF:CollectAuctionGold() end)
  end
  mailButton:Show()
  FF:UpdateMailButton()
end)
FF:On("MAIL_INBOX_UPDATE", function() FF:UpdateMailButton() end)
FF:On("MAIL_CLOSED", function()
  if collecting then collectDone() end
end)

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
  elseif cmd == "errors" then
    local list = FlipForeverDB.errors or {}
    if #list == 0 then
      FF:Print("No errors recorded.")
    else
      FF:Print(("Last %d errors (newest first):"):format(math.min(5, #list)))
      for i = #list, math.max(1, #list - 4), -1 do
        local e = list[i]
        FF:Print(("  %s  v%s  %s: %s"):format(date("%H:%M", e.t or 0), e.v or "?", e.where or "?", e.msg or ""))
      end
    end
  elseif cmd == "spells" and FF.Spells then
    local bad, n = FF.Spells:Check()
    if #bad == 0 then
      FF:Print(("All %d spell IDs match their names."):format(n))
    else
      FF:Print(("%d of %d spell IDs name a different spell:"):format(#bad, n))
      for _, line in ipairs(bad) do FF:Print("  " .. line) end
    end
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
function FF:Today(days)
  local d = date("*t")
  local start = time({ year = d.year, month = d.month, day = d.day, hour = 0 }) - ((days or 1) - 1) * 86400
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

-- this week (today and the 6 days before): sales after the AH cut minus what was spent buying
function FF:WeekLine()
  local t = self:Today(7)
  if t.sales == 0 and t.buys == 0 then return FF:T("This week: no trades yet") end
  local net = t.sold - t.spent
  local color = net >= 0 and "|cff33ff99+" or "|cffff5555-"
  return FF:T("This week: %s%s|r  (sold %s, bought %s)"):format(color, self:Money(math.abs(net)), self:Money(t.sold), self:Money(t.spent))
end

-- Reload the UI from a button: the game saves FlipForever's data (scans, trades) for the app
-- and loads the newest shopping list. Not during combat or while a purchase is waiting.
function FF:ReloadForSync()
  if InCombatLockdown() then FF:Print("Can't reload during a fight - try again after.") return end
  if FF.Trader and FF.Trader.state ~= "idle" then FF:Print("Finish or stop the current buy/post first.") return end
  if FF.Scan and FF.Scan.busy then FF:Print("A scan is still running - reload when it's done, or the scan is lost.") return end
  ReloadUI()
end

-- A full scan finished: tell the player (sound, raid warning, flashing Reload) and pause
-- autopilot until the reload, so it doesn't keep buying from a list made with old prices.
-- The reload saves the scan for the app, which builds the new shopping list.
function FF:ScanFinished(items)
  if self.Gear and not self.Gear.running then C_Timer.After(2, function() pcall(self.Gear.Search, self.Gear, nil, true) end) end
  -- Beta 4: rebuild the list in game from the new scan - no reload needed
  local live = self.Planner and self.Planner:Rebuild()
  if live then
    self.needReload = nil
    if self.Alert then
      self:Alert(("Shopping list updated from the new scan: %d to buy, %d to sell."):format(#live.buy, #live.sell),
        SOUNDKIT and SOUNDKIT.READY_CHECK)
    end
    if self.UI then self.UI:Refresh() end
    return
  end
  if FlipForeverDB.settings.reloadAfterScan == false then return end
  self.needReload = true
  if self.Alert then
    self:Alert(("Scan saved (%d items) - click Reload so the app can build your new shopping list."):format(items or 0),
      SOUNDKIT and SOUNDKIT.READY_CHECK)
  end
  if self.UI then self.UI:Refresh() end
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

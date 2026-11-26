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
      (FF.Loud or FF.Print)(FF, FF:T("|cffff5555error in ") .. event .. ":|r " .. tostring(err))
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

-- an action the game blocked ("Interface action failed because of an AddOn"): keep which
-- function it was and whether a fight was on, so a bug report shows the cause
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("ADDON_ACTION_BLOCKED")
  f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
  f:SetScript("OnEvent", function(_, event, addon, func)
    if addon ~= "FlipForever" then return end
    local fight = InCombatLockdown and InCombatLockdown() and " (in combat)" or ""
    FF:RecordError(event, "blocked: " .. tostring(func) .. fight)
  end)
end

function FF:Print(...)
  print("|cff33ff99FlipForever|r:", ...)
end

-- names shown in the game's Key Bindings menu (Bindings.xml)
BINDING_HEADER_FLIPFOREVER = "FlipForever"
BINDING_NAME_FLIPFOREVER_ADVISOR = "Open or close the Advisor"
BINDING_NAME_FLIPFOREVER_HUB = "Open or close the FlipForever window"
BINDING_NAME_FLIPFOREVER_NEXT_SPOT = "Arrow: next Advisor pin or quest spot"
BINDING_NAME_FLIPFOREVER_ARROW_CLEAR = "Arrow: clear the point I set"
_G["BINDING_NAME_CLICK FlipForeverCombatButton:LeftButton"] = "Combat helper: next spell"
_G["BINDING_NAME_CLICK FlipForeverEmergencyButton:LeftButton"] = "Combat helper: emergency"

-- Controller support (switch: Settings, Features, "controller") ------------------------------------
-- Gamepad buttons are bound like keys (Key Bindings menu, or "Set key"); nothing here presses anything.
function FF:Controller()
  local s = FlipForeverDB and FlipForeverDB.settings
  return not (s and s.controller == false)
end

-- a key as the player reads it: gamepad buttons get the game's own name (PAD1 -> "A" or "Cross")
function FF:KeyLabel(key)
  if type(key) ~= "string" then return key end
  local base = key:match("([^%-]+)$") or key
  if self:Controller() and base:sub(1, 3) == "PAD" and GetBindingText then
    local ok, text = pcall(GetBindingText, key, "KEY_")
    if ok and type(text) == "string" and text ~= "" then return text end
  end
  return key
end

-- bigger click areas for the gamepad cursor (no layout change)
function FF:PadFriendly(...)
  if not self:Controller() then return end
  for i = 1, select("#", ...) do
    local b = select(i, ...)
    if b and b.SetHitRectInsets then b:SetHitRectInsets(-5, -5, -5, -5) end
  end
end

-- English plural "s"; translations use a neutral form, so other languages get ""
function FF:Plural(n)
  if FF.TRANSLATIONS and FF.Language and FF.TRANSLATIONS[FF:Language()] then return "" end
  return (n or 0) > 1 and "s" or ""
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
-- The realm name can come back empty on this client; then use the last one seen (or the only
-- realm already saved for this faction), so data never splits into a " - Horde" key.
function FF:RealmKey()
  local faction = UnitFactionGroup("player") or "Neutral"
  local realm = GetRealmName and GetRealmName() or ""
  if realm == "" and GetNormalizedRealmName then realm = GetNormalizedRealmName() or "" end
  -- WoW: Forever gives every realm the same name ("CAMWOW EU4 Realm 1 PvE"); the realms differ by
  -- their rules (PvP, RP, Hardcore), each with its own auction house. Those get their own key
  -- ("RPPvP - Horde"); the normal realm keeps its name, so its data stays where it is.
  local rules = self:Ruleset()
  if rules then realm = rules end
  local db = FlipForeverDB
  -- the realm is remembered per character: with characters on several realms, a moment without a
  -- realm name must never file one character's scans and trades under another character's realm
  local who = UnitName("player")
  local charKey = who and (who .. " - " .. faction)
  if realm ~= "" then
    if db then
      db.lastRealm = realm
      db.charRealms = db.charRealms or {}
      if charKey then db.charRealms[charKey] = realm end
    end
  elseif db and charKey and db.charRealms and db.charRealms[charKey] then
    realm = db.charRealms[charKey]
  else
    -- a character already saved on exactly one realm of this faction
    local found
    for key, r in pairs(db and db.realms or {}) do
      local name = key:match("^(.+) %- " .. faction .. "$")
      if name and name ~= "" and who and type(r) == "table" and r.chars and r.chars[who] then
        if found and found ~= name then found = nil break end
        found = name
      end
    end
    -- not known yet: saved under " - <faction>" and moved to the real realm at the next login (MergeEmptyRealm)
    realm = found or ""
    if db and found and charKey then db.charRealms = db.charRealms or {} db.charRealms[charKey] = found end
  end
  return realm .. " - " .. faction
end

-- The realm's rules on clients where realm names are shared ("RPPvP", "PvP", "RP", "Hardcore"),
-- or nil for a normal realm and for clients without them
function FF:Ruleset()
  if not (type(RegionalUniqueNamesEnabled) == "function" and type(C_GameRules) == "table"
          and type(C_GameRules.IsGameRuleActive) == "function" and type(Enum) == "table" and Enum.GameRule) then
    return nil
  end
  local okR, regional = pcall(RegionalUniqueNamesEnabled)
  if not (okR and regional) then return nil end
  local function on(rule)
    if rule == nil then return false end
    local ok, v = pcall(C_GameRules.IsGameRuleActive, rule)
    return ok and v and true or false
  end
  local pvp, rp = on(Enum.GameRule.PvPRuleset), on(Enum.GameRule.RPRuleset)
  if pvp and rp then return "RPPvP" end
  if pvp then return "PvP" end
  if rp then return "RP" end
  if on(Enum.GameRule.HardcoreRuleset) then return "Hardcore" end
  return nil
end

-- data saved under an empty realm name (" - Horde") goes back to the real realm
function FF:MergeEmptyRealm()
  local realms = FlipForeverDB and FlipForeverDB.realms
  if not realms then return end
  local faction = UnitFactionGroup("player") or "Neutral"
  local stray = realms[" - " .. faction]
  local key = self:RealmKey()
  if not stray or key == " - " .. faction then return end
  local target = realms[key] or {}
  realms[key] = target
  for k, v in pairs(stray) do
    local t = target[k]
    if t == nil then
      target[k] = v
    elseif type(t) == "table" and type(v) == "table" then
      if #v > 0 or #t > 0 then
        for _, e in ipairs(v) do t[#t + 1] = e end           -- lists (scans, log): keep both
        if k == "scans" or k == "log" then table.sort(t, function(a, b) return (a.t or 0) < (b.t or 0) end) end
      else
        for kk, vv in pairs(v) do                            -- maps: the newer character record wins
          local old = t[kk]
          if old == nil or (type(vv) == "table" and type(old) == "table" and (vv.t or 0) > (old.t or 0)) then
            if type(old) == "table" and type(vv) == "table" then for f, x in pairs(old) do if vv[f] == nil then vv[f] = x end end end
            t[kk] = vv
          end
        end
      end
    end
  end
  realms[" - " .. faction] = nil
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
  -- update in place: the record also holds the Advisor's build choice and next steps
  local chars = self:DB().chars
  local c = chars[name] or {}
  c.money, c.level, c.class, c.t = GetMoney(), UnitLevel("player"), class, time()
  chars[name] = c
end

-- Best time to post (switch bestPostTime): the 4-hour window of the day in which your auctions of
-- this item sold most (all items together when the item has fewer than 5 sales). Needs 5+ sales.
function FF:BestPostHours(itemID)
  if FlipForeverDB.settings.bestPostTime == false then return nil end
  local function count(filter)
    local hours, n = {}, 0
    for _, e in ipairs(self:DB().log or {}) do
      if e.e == "invoice" and e.t and (not filter or e.id == filter) then
        local h = tonumber(date("%H", e.t)) or 0
        hours[h] = (hours[h] or 0) + 1
        n = n + 1
      end
    end
    return hours, n
  end
  local hours, n = count(itemID)
  local own = n >= 5
  if not own then hours, n = count(nil) end
  if n < 5 then return nil end
  local bestStart, bestN = 0, -1
  for h = 0, 23 do
    local s = 0
    for k = 0, 3 do s = s + (hours[(h + k) % 24] or 0) end
    if s > bestN then bestStart, bestN = h, s end
  end
  return { from = bestStart, to = (bestStart + 4) % 24, share = bestN / n, own = own,
    text = ("%02d:00-%02d:00%s"):format(bestStart, (bestStart + 4) % 24, own and "" or FF:T(" (all your sales)")) }
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
  if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end  -- hidden text (e.g. in fights)
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
    FF:Print(FF:T("|cffffd200Mail:|r %d auction%s sold since your last visit, |cff33ff99+%s|r after the AH cut."):format(
      m.n, FF:Plural(m.n), FF:Money(m.gold)))
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
  if FlipForeverDB.settings.mailButton == false then -- switched off in Settings
    if mailButton then mailButton:Hide() end
    return
  end
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
  FF:MergeEmptyRealm()
  FF:DB()
  FF:UpdateChar()
  local plan = FF:Plan()
  if plan and plan.buy then
    FF:Print(FF:T("Shopping list for %s loaded: %d to buy, %d to sell, budget %s. Open the auction house to start."):format(
      UnitName("player"), #plan.buy, #(plan.sell or {}), FF:Money(plan.budget or 0)))
  else
    FF:Print(FF:T("Loaded. No shopping list for %s yet - scan at the auction house, then pick this character in the app and build one."):format(UnitName("player") or "?"))
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
  elseif cmd == "quest" or cmd == "quests" then
    FF.QuestHelper:Next()
  elseif cmd == "bug" or cmd == "suggest" or cmd == "suggestion" then
    local kind = cmd == "bug" and "bug" or "suggestion"
    if rest ~= "" then FF:SaveReport(kind, rest) else FF:AskReport(kind) end
  elseif cmd == "talents" or cmd == "talent" then
    FF.TalentOverlay:Open()
  elseif cmd == "fights" or (cmd == "combat" and (rest == "report" or rest == "learn")) then
    if FF.CombatLearn then FF.CombatLearn:Report() end
  elseif cmd == "combat" then
    FF.Combat:Toggle()
  elseif cmd == "emergencykey" then
    if FF.CombatGuide then FF.CombatGuide:SetKey((rest ~= "" and rest ~= "clear") and rest:upper() or nil) end
  elseif cmd == "combatkey" then
    FF.Combat:SetKey(rest ~= "" and rest:upper() or nil)
  elseif cmd == "combatmode" then
    FF.Combat:ToggleBlizzard()
  elseif cmd == "gather" or cmd == "ore" then
    local ns = FF.gatherNS
    if ns and not ns.db and not ns.skipGather and ns.Start then ns.Start() end
    if ns and ns.ToggleMain and not ns.skipGather and ns.db then ns.ToggleMain() else FF:Print(FF:GatherOffReason() or FF:T("Gathering didn't load.")) end
  elseif cmd == "auto" then
    FF.Auto:SetEnabled(not FF.Auto:Enabled())
  elseif cmd == "key" then
    FF:SetActionKey(rest ~= "" and rest:upper() or nil)
  elseif cmd == "disenchant" or cmd == "de" then
    if FF.Disenchant then FF.Disenchant:Command() end
  elseif cmd == "bags" then
    -- /ff bags <slots>: free bag slots auction buying keeps (switch bagSpace)
    local n = tonumber(rest)
    if n and n >= 0 and n <= 30 then FlipForeverDB.settings.bagKeepFree = math.floor(n) end
    FF:Print(FF:T("Bag space: buying keeps %d bag slot%s free. Change: /ff bags <slots>."):format(tonumber(FlipForeverDB.settings.bagKeepFree) or 2, FF:Plural(tonumber(FlipForeverDB.settings.bagKeepFree) or 2)))
  elseif cmd == "goal" then
    FF:GoalCommand(rest)
  elseif cmd == "vendors" then
    if FF.VendorResale then FF.VendorResale:Command() end
  elseif cmd == "reserve" then
    -- /ff reserve <percent> [min gold] | off
    local s = FlipForeverDB.settings
    if rest == "off" then
      s.goldReserve = false
    else
      -- minimum: gold (20, 1.5, 20g) or silver (50s)
      local pct, min = rest:match("^(%d+)%%?%s*(%S*)")
      if pct then
        s.goldReserve = true
        s.reservePct = math.min(90, tonumber(pct)) / 100
        local num, unit = min:lower():match("^(%d*%.?%d+)([gs]?)$")
        if num then s.reserveMin = math.floor(tonumber(num) * (unit == "s" and 100 or 10000) + 0.5) end
      end
    end
    if s.goldReserve == false then
      FF:Print(FF:T("Gold reserve is off: buying may spend all your gold."))
    else
      FF:Print(FF:T("Gold reserve: buying keeps %d%% of your gold, at least %s. Change: /ff reserve <percent> <gold, or silver like 50s>, or off."):format(
        math.floor((tonumber(s.reservePct) or 0.20) * 100 + 0.5), FF:Money(tonumber(s.reserveMin) or 200000)))
    end
  elseif cmd == "reset" then
    FF:ResetProgress()
  elseif cmd == "errors" then
    local list = FlipForeverDB.errors or {}
    if #list == 0 then
      FF:Print(FF:T("No errors recorded."))
    else
      FF:Print(FF:T("Last %d errors (newest first):"):format(math.min(5, #list)))
      for i = #list, math.max(1, #list - 4), -1 do
        local e = list[i]
        FF:Print(("  %s  v%s  %s: %s"):format(date("%H:%M", e.t or 0), e.v or "?", e.where or "?", e.msg or ""))
      end
    end
  elseif cmd == "spells" and FF.Spells then
    local bad, n = FF.Spells:Check()
    if #bad == 0 then
      FF:Print(FF:T("All %d spell IDs match their names."):format(n))
    else
      FF:Print(FF:T("%d of %d spell IDs name a different spell:"):format(#bad, n))
      for _, line in ipairs(bad) do FF:Print("  " .. line) end
    end
  elseif cmd == "" or cmd == "show" or cmd == "options" or cmd == "settings" then
    if FF.Hub then FF.Hub:Toggle() end
  else
    FF:Help()
  end
end

-- /ff help: every command, grouped
FF.HELP = {
  { "/ff", "open the FlipForever window (or click the gold coin on the minimap)" },
  { "Leveling", "guide (Advisor) | quest (arrow to the next quest spot) | talents | /ffway x y (arrow)" },
  { "Combat helper", "combat | combatkey <KEY> | combatmode | emergencykey <KEY> | fights" },
  { "Auction house", "scan | buy | sell | stop | auto | key <KEY> | reserve <percent> <gold> | goal day|week <gold> (profit goals) | bags <slots> (free bag slots kept while buying) | disenchant (buy items worth more disenchanted) | vendors (vendor items that resell for more) | watch <item> <price> (alert when listed at or below) | watch sell <item> <price> (alert when it sells at or above) | find <item> (which characters hold it) | note <item> <text> (your note in its tooltip) | reset" },
  { "Gathering", "gather" },
  { "Controller", "Key Bindings, FlipForever: combat helper, emergency, arrow (gamepad buttons work too)" },
  { "Reports", "bug <text> | suggest <text> | errors" },
  { "Chat", "log (messages kept by quiet chat on RP realms) | chattab (a FlipForever chat tab) | talk [troll|orc|dwarf|goblin|pirate|forsaken|tauren|nightelf|skyborne] [text] (speak in dialect; /fft <text> sends in your dialect)" },
}
function FF:Help()
  FF:Print(FF:T("Commands (type /ff and the word):"))
  for _, h in ipairs(self.HELP) do
    FF:Print(("  |cffffd200%s|r: %s"):format(FF:T(h[1]), FF:T(h[2])))
  end
end

-- Bug reports and suggestions ----------------------------------------------------------------------
-- Saved with the game data; the FlipForever app sends them after the next /reload or logout and
-- shows their status on its Community page. Attached to a bug report: version, class, level, zone
-- and the last FlipForever errors. No names.
function FF:SaveReport(kind, text)
  text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if #text < 5 then
    FF:Print(FF:T("Please write a bit more (at least a sentence)."))
    return false
  end
  local list = FlipForeverDB.reports or {}
  FlipForeverDB.reports = list
  local meta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  local r = { k = kind, t = text:sub(1, 1500), v = meta and meta("FlipForever", "Version") or "?", time = time() }
  if kind == "bug" then
    local _, class = UnitClass("player")
    r.class, r.level, r.zone = class, UnitLevel("player"), GetRealZoneText and GetRealZoneText() or nil
    local errs, all = {}, FlipForeverDB.errors or {}
    for i = #all, math.max(1, #all - 2), -1 do
      local e = all[i]
      errs[#errs + 1] = ("%s: %s"):format(e.where or "?", (e.msg or ""):sub(1, 120))
    end
    r.errors = table.concat(errs, " | ")
  end
  list[#list + 1] = r
  while #list > 20 do table.remove(list, 1) end
  FF:Print(kind == "bug" and FF:T("Bug report saved. The FlipForever app sends it after your next /reload or logout.")
    or FF:T("Suggestion saved. The FlipForever app sends it after your next /reload or logout."))
  return true
end

function FF:AskReport(kind)
  StaticPopupDialogs.FLIPFOREVER_REPORT = StaticPopupDialogs.FLIPFOREVER_REPORT or {
    button1 = OKAY, button2 = CANCEL, hasEditBox = true, editBoxWidth = 320, maxLetters = 500,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    OnAccept = function(self, data)
      local box = self.editBox or self.EditBox
      FF:SaveReport(data, box and box:GetText() or "")
    end,
    EditBoxOnEnterPressed = function(self)
      local p = self:GetParent()
      if FF:SaveReport(p.data, self:GetText()) then p:Hide() end
    end,
  }
  StaticPopupDialogs.FLIPFOREVER_REPORT.text = kind == "bug"
    and FF:T("Report a bug: what happened, and what did you do right before?")
    or FF:T("Suggest an idea for FlipForever:")
  local dlg = StaticPopup_Show("FLIPFOREVER_REPORT")
  if dlg then dlg.data = kind end
end

-- Shared by the window and the commands ------------------------------------------------------------
-- The auction house action key (the big button); returns true when it was set.
function FF:SetActionKey(key)
  local clash = key and (FF:KeyConflict(key) or (key == FlipForeverDB.settings.combatKey and "FlipForever's combat helper key"))
  if clash then
    FF:Print(FF:T("|cffff5555%s is already used by %s|r - pick another key, e.g. CTRL-SPACE"):format(key, clash))
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
  if t.sales == 0 and t.buys == 0 then return FF:T("Today: no trades yet") end
  return FF:T("Today: sold %s (%d)  ·  bought %s (%d)"):format(self:Money(t.sold), t.sales, self:Money(t.spent), t.buys)
end

-- this week (today and the 6 days before): sales after the AH cut minus what was spent buying
function FF:WeekLine()
  local t = self:Today(7)
  if t.sales == 0 and t.buys == 0 then return FF:T("This week: no trades yet") end
  local net = t.sold - t.spent
  local color = net >= 0 and "|cff33ff99+" or "|cffff5555-"
  return FF:T("This week: %s%s|r  (sold %s, bought %s)"):format(color, self:Money(math.abs(net)), self:Money(t.sold), self:Money(t.spent))
end

-- Gold goals (switch goldGoals): a daily and weekly profit goal in gold (/ff goal day|week <gold>),
-- progress = sales after the AH cut minus buying, like the week line. Returns "" when no goal is set.
function FF:GoalSuffix(kind)
  local s = FlipForeverDB.settings
  if s.goldGoals == false then return "" end
  local goal = tonumber(kind == "week" and s.goalWeek or s.goalDay)
  if not goal or goal <= 0 then return "" end
  local t = self:Today(kind == "week" and 7 or 1)
  local pct = math.floor(math.max(0, t.sold - t.spent) / (goal * 10000) * 100)
  local color = pct >= 100 and "|cff33ff99" or "|cffffd200"
  return ("  ·  " .. FF:T("goal %s%d%%|r of %dg")):format(color, pct, goal)
end

-- /ff goal day <gold> | week <gold> | off
function FF:GoalCommand(rest)
  local s = FlipForeverDB.settings
  local kind, n = (rest or ""):lower():match("^(%a*)%s*(%d*)")
  if kind == "off" then s.goalDay, s.goalWeek = nil, nil
  elseif (kind == "day" or kind == "week") and tonumber(n) then
    s[kind == "day" and "goalDay" or "goalWeek"] = tonumber(n) > 0 and tonumber(n) or nil
  end
  FF:Print(FF:T("Gold goals: today %s, this week %s. Change: /ff goal day <gold>, /ff goal week <gold>, /ff goal off."):format(
    s.goalDay and (s.goalDay .. "g") or "-", s.goalWeek and (s.goalWeek .. "g") or "-"))
  if self.Hub and self.Hub.Refresh then pcall(self.Hub.Refresh, self.Hub) end
end

-- Reload the UI from a button: the game saves FlipForever's data (scans, trades) for the app
-- and loads the newest shopping list. Not during combat or while a purchase is waiting.
function FF:ReloadForSync()
  if InCombatLockdown() then FF:Print(FF:T("Can't reload during a fight - try again after.")) return end
  if FF.Trader and FF.Trader.state ~= "idle" then FF:Print(FF:T("Finish or stop the current buy/post first.")) return end
  if FF.Scan and FF.Scan.busy then FF:Print(FF:T("A scan is still running - reload when it's done, or the scan is lost.")) return end
  ReloadUI()
end

-- A full scan finished: tell the player (sound, raid warning, flashing Reload) and pause
-- autopilot until the reload, so it doesn't keep buying from a list made with old prices.
-- The reload saves the scan for the app, which builds the new shopping list.
function FF:ScanFinished(items)
  if self.Gear and not self.Gear.running then C_Timer.After(2, function() pcall(self.Gear.Search, self.Gear, nil, true) end) end
  -- Beta 4: rebuild the list in game from the new scan - no reload needed
  local live = self.Planner and self.Planner:Rebuild()
  if self.Professions and self.Professions.ProfitAlert then pcall(self.Professions.ProfitAlert, self.Professions) end
  if live then
    self.needReload = nil
    if self.Alert then
      self:Alert(("Shopping list updated from the new scan: %d to buy, %d to sell."):format(#live.buy, #live.sell),
        SOUNDKIT and SOUNDKIT.READY_CHECK)
    end
    if self.Planner.FloodNote then self.Planner:FloodNote(live) end
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
  FF:Print(FF:T("Shopping list progress reset - every item on the list will be checked again."))
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
    FF:Print(FF:T("Note: %s normally does '%s'; while the auction house is open it will press the FlipForever button instead."):format(key, action))
  end
  return nil
end

-- A key saved before this check existed might clash: drop it at login.
FF:On("PLAYER_LOGIN", function()
  local key = FlipForeverDB.settings.key
  if key and FF:KeyConflict(key) then
    FF:Print(FF:T("Your action key %s clashes with %s - cleared. Pick another: /ff key CTRL-SPACE"):format(key, FF:KeyConflict(key)))
    FlipForeverDB.settings.key = nil
  end
end)

-- One window style for every FlipForever window: dark backdrop with the green border, dragging with the
-- position saved in settings[pos], kept on screen, Escape and a close button (unless turned off).
-- opts: pos (settings key), strata, alpha, default ({ point, x, y } to place it now), escape, close
FF.WINDOW_BACKDROP = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } }
-- Window size for every FlipForever window (Settings, Window size): 80% to 110%, default 90%.
FF.WINDOW_SCALES = { 0.8, 0.9, 1.0, 1.1 }
FF.windows = {}
function FF:WindowScale()
  local s = FlipForeverDB and FlipForeverDB.settings and tonumber(FlipForeverDB.settings.windowScale)
  return (s and s >= 0.5 and s <= 1.5) and s or 0.9
end
function FF:SetWindowScale(s)
  FlipForeverDB.settings.windowScale = s
  for _, w in ipairs(self.windows) do if w.SetScale then w:SetScale(s) end end
end

function FF:Window(name, width, height, opts)
  opts = opts or {}
  local f = CreateFrame("Frame", name, opts.parent or UIParent, "BackdropTemplate")
  f:SetSize(width, height)
  if not opts.parent and f.SetScale then
    f:SetScale(FF:WindowScale())
    FF.windows[#FF.windows + 1] = f
  end
  f:SetFrameStrata(opts.strata or "MEDIUM")
  f:SetClampedToScreen(true)
  if f.SetBackdrop then
    f:SetBackdrop(FF.WINDOW_BACKDROP)
    f:SetBackdropColor(0.05, 0.06, 0.08, opts.alpha or 0.96)
    f:SetBackdropBorderColor(0.2, 0.8, 0.5, 1)
  end
  if opts.pos then
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, _, relPoint, x, y = self:GetPoint()
      FlipForeverDB.settings[opts.pos] = { point, relPoint, x, y }
    end)
    if opts.default then
      local p = FlipForeverDB.settings[opts.pos]
      if p then f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else f:SetPoint(opts.default[1], opts.default[2], opts.default[3]) end
    end
  end
  if name and opts.escape ~= false then tinsert(UISpecialFrames, name) end
  if opts.close ~= false then
    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", 2, 2)
    FF:PadFriendly(f.close)
  end
  return f
end

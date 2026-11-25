"""Addon tests: loads every addon file in a real Lua VM (lupa) with a mocked WoW API.
Run: python tests/test_addon.py   (needs: pip install lupa)"""
"""Load the addon in a real Lua VM with a mocked WoW API and drive scan/buy/sell flows."""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent / "luapkg"))  # optional local copy: pip install --target tests/luapkg lupa
import lupa  # noqa: E402

ADDON = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent / "addon" / "FlipForever"
lua = lupa.LuaRuntime(unpack_returned_tuples=True)

MOCK = r"""
unpack = table.unpack
local timers = {}
NOW = 1800000000
function time(t) if t then return os.time(t) end return NOW end
function date(fmt, t) return os.date(fmt, t or NOW) end
TT_HOOKS = {}
Enum_TT = { Item = 0 }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) TT_HOOKS[kind] = fn end }
function GetTime() return NOW end
CLOCK = 0   -- mock time for C_Timer: timers keep their due time until it comes
C_Timer = { After = function(d, fn) table.insert(timers, {due = CLOCK + (d or 0), fn = fn}) end }
TICKERS = {}
function C_Timer.NewTicker(d, fn)
  local t = { fn = fn, cancelled = false }
  function t:Cancel() self.cancelled = true end
  table.insert(TICKERS, t)
  return t
end
-- fire every live ticker once (simulates `secs` seconds passing per call)
function RunTickers()
  for _, t in ipairs(TICKERS) do if not t.cancelled then t.fn() end end
end
function hooksecurefunc(tbl, name, hook)
  local orig = tbl[name]
  tbl[name] = function(...) local r = {orig(...)} hook(...) return table.unpack(r) end
end
function InCombatLockdown() return false end
function GetBindingAction(k) return "" end
SOUNDKIT = { RAID_WARNING = 8959, READY_CHECK = 8960 }
ALERTS = {}
function PlaySound(k) table.insert(ALERTS, "sound:" .. k) end
RaidWarningFrame = {}
ChatTypeInfo = { RAID_WARNING = {} }
function RaidNotice_AddMessage(f, text) table.insert(ALERTS, "rw:" .. text) end
function FlashClientIcon() table.insert(ALERTS, "flash") end
-- secure handler mock: compile the restricted snippet as plain Lua
WRAPS = {}
function SecureHandlerWrapScript(frame, script, header, body)
  local fn = assert(load("local self, button, down = ...; " .. body))
  WRAPS[frame] = WRAPS[frame] or {}
  WRAPS[frame][script] = fn
end
-- simulate a click: secure action, then the wrapped PostClick, then hooks
CASTS = {}
function ClickButton(frame, down)
  table.insert(CASTS, frame:GetAttribute("macrotext") or frame:GetAttribute("spell"))
  local w = WRAPS[frame] and WRAPS[frame].PostClick
  if w then w(frame, "LeftButton", down) end
  for _, h in ipairs(frame.hooks.PostClick or {}) do h(frame, "LeftButton", down) end
end
function GetCVarBool(name) return false end
TARGET = nil  -- {name=, ctype=, level=, class=, power=}
function UnitExists(u) return u == "target" and TARGET ~= nil or u == "player" end
function UnitCanAttack() return TARGET ~= nil end
function UnitCreatureType() return TARGET and TARGET.ctype end
function UnitClassification() return TARGET and TARGET.class or "normal" end
function UnitPowerType() return TARGET and TARGET.power or 1 end
COMBAT = false
function InCombatLockdown() return COMBAT end
function IsShiftKeyDown() return false end
C_Spell = { GetSpellTexture = function(name) return "icon:" .. tostring(name) end }
MODS = {}
function IsAltKeyDown() return MODS.alt end
function IsControlKeyDown() return MODS.ctrl end
function IsShiftKeyDown() return MODS.shift end
COMPARTMENT = {}
AddonCompartmentFrame = { RegisterAddon = function(self, info) table.insert(COMPARTMENT, info.text) end }
function RunTimers(maxd)
  local guard = 0
  -- run everything due within the next maxd seconds (including timers those schedule); later ones wait
  local limit = CLOCK + (maxd or 1e9)
  while guard < 10000 do
    guard = guard + 1
    table.sort(timers, function(a,b) return a.due < b.due end)
    local t = timers[1]
    if not t or t.due > limit then break end
    table.remove(timers, 1)
    if t.due > CLOCK then CLOCK = t.due end
    t.fn()
  end
  if maxd then CLOCK = limit end
end
function PendingTimers() return #timers end
function DropTimers() timers = {} end
printed = {}
function print(...) local p = {} for i=1,select('#',...) do p[#p+1]=tostring(select(i,...)) end table.insert(printed, table.concat(p," ")) end
function GetRealmName() return "Testrealm" end
function UnitFactionGroup() return "Horde" end
function UnitName() return "Tester" end
function UnitClass() return "Mage", "MAGE" end
PLEVEL = 22
function UnitLevel() return PLEVEL end
function UnitRace() return "Skyborne", "Skyborne" end
C_AddOns = { GetAddOnEnableState = function(name, char) return OREFARMER_ON and 2 or 0 end }
UISpecialFrames = {}
tinsert = table.insert
issecretvalue = function() return false end
-- spellbook (classic API)
KNOWN = { "Frostbolt", "Fireball", "Frost Nova" }
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo(t) return "General", nil, 0, #KNOWN end
function GetSpellBookItemName(i) return KNOWN[i] end
-- gear: slot -> {id, name, quality, ilvl}
GEAR = { [16] = {id=100, name="Apprentice's Staff", q=1} , [5] = {id=101, name="Robe", q=2} }
ITEMNAMES = { [100] = "Apprentice's Staff", [101] = "Robe" }
function GetInventoryItemID(u, s) return GEAR[s] and GEAR[s].id end
function GetInventoryItemQuality(u, s) return GEAR[s] and GEAR[s].q end
function GetInventoryItemLink(u, s) return nil end
-- talents (classic): tab, index -> name, icon, tier, col, rank, max
TALENTS = { {"Improved Frostbolt", 5, 5}, {"Precision", 3, 3}, {"Frostbite", 3, 3}, {"Ice Shards", 1, 3}, {"Ice Lance", 0, 1} }
function GetNumTalentTabs() return 1 end
function GetNumTalents(tab) return #TALENTS end
function GetTalentInfo(tab, i) local t = TALENTS[i] return t[1], nil, 1, 1, t[2], t[3] end
UNSPENT = 2
function UnitCharacterPoints() return UNSPENT end
-- professions
PROFS = {}
function GetProfessions() return PROFS[1], PROFS[2] end
function GetProfessionInfo(idx) local p = PROFS_INFO[idx] return p[1], nil, p[2], 300 end
PROFS_INFO = {}
QUESTS = {}
C_QuestLog = { GetNumQuestLogEntries = function() return #QUESTS end, GetInfo = function(i) return { title = QUESTS[i] } end }
function GetMoney() return 1000000 end
ERR_AUCTION_SOLD_S = "A buyer has been found for your auction of %s."
ERR_AUCTION_EXPIRED_S = "Your auction of %s has expired."
SlashCmdList = {}
Enum = { AuctionHouseSortOrder = { Price = 0 }, TooltipDataType = { Item = 0 } }
NUM_BAG_SLOTS = 4

local frames = {}
local function newFrame()
  local f = { events = {}, shown = true }
  function f:RegisterEvent(e) self.events[e] = true end
  function f:SetScript(k, fn) self[k] = fn end
  local noop = function() end
  setmetatable(f, { __index = function(t, k)
    if type(k) == "string" and k:match("^Create") and k ~= "CreateFontString" then
      return function() return newFrame() end
    end
    return function(self, ...) return nil end
  end })
  f.Show = function(self) self.shown = true end
  f.Hide = function(self) self.shown = false end
  f.IsShown = function(self) return self.shown end
  f.CreateFontString = function() return setmetatable({}, { __index = function() return function() end end }) end
  f.SetText = function(self, t) self.text = t end
  f.SetEnabled = function(self, e) self.enabled = e end
  f.attrs = {}
  f.SetAttribute = function(self, k, v) self.attrs[k] = v end
  f.GetAttribute = function(self, k) return self.attrs[k] end
  f.hooks = {}
  f.HookScript = function(self, script, fn) self.hooks[script] = self.hooks[script] or {} table.insert(self.hooks[script], fn) end
  f.SetTexture = function(self, t) self.texture = t end
  f.SetChecked = function(self, v) self.checked = v and true or false end
  f.GetChecked = function(self) return self.checked end
  f.SetScript = function(self, k, fn) self[k] = fn end
  f.GetWidth = function() return 140 end
  f.CreateTexture = function() return newFrame() end
  table.insert(frames, f)
  return f
end
function CreateFrame(kind, name, parent, template)
  local f = newFrame()
  if name then _G[name] = f end
  if parent then f.GetParent = function() return parent end end
  return f
end
UIParent = newFrame()
Minimap = newFrame()
AuctionHouseFrame = newFrame()
function ClearOverrideBindings() end
function SetOverrideBindingClick(...) LAST_BIND = {...} end
function Fire(event, ...)
  for _, f in ipairs(frames) do
    if f.events[event] and f.OnEvent then f.OnEvent(f, event, ...) end
  end
end

-- auction house mock
calls = {}
local function rec(name) return function(...) table.insert(calls, {name, ...}) end end
REPL = {}
COMMODITY = {}  -- itemID -> rows
C_AuctionHouse = {
  ReplicateItems = rec("ReplicateItems"),
  GetNumReplicateItems = function() return #REPL end,
  GetReplicateItemInfo = function(i)
    local r = REPL[i + 1]
    if not r then error("replicate index out of range " .. i) end
    return r.name, nil, r.count, 1, true, 1, 0, 0, 0, r.buyout, 0, false, nil, "x", "x", 0, r.id, true
  end,
  SendSearchQuery = function(key, sorts, sep) table.insert(calls, {"SendSearchQuery", key.itemID}) end,
  MakeItemKey = function(id) return { itemID = id, itemLevel = 0, itemSuffix = 0 } end,
  IsThrottledMessageSystemReady = function() return true end,
  GetNumCommoditySearchResults = function(id) return #(COMMODITY[id] or {}) end,
  GetCommoditySearchResultInfo = function(id, i) return COMMODITY[id][i] end,
  StartCommoditiesPurchase = rec("StartCommoditiesPurchase"),
  ConfirmCommoditiesPurchase = rec("ConfirmCommoditiesPurchase"),
  CancelCommoditiesPurchase = rec("CancelCommoditiesPurchase"),
  PlaceBid = rec("PlaceBid"),
  PostCommodity = rec("PostCommodity"),
  PostItem = rec("PostItem"),
  CalculateCommodityDeposit = function(id, d, q) return 15 * q end,
  IsSellItemValid = function() return true end,
  GetItemKeyInfo = function() return nil end,
}
C_Item = { GetItemNameByID = function(id) return ITEMNAMES and ITEMNAMES[id] end, GetItemCount = function(id) return BAGCOUNT[id] or 0 end }
BAGCOUNT = {}
BAGS = {}  -- [bag][slot] = {itemID=, stackCount=}
C_Container = {
  GetContainerNumSlots = function(bag) return 16 end,
  GetContainerItemInfo = function(bag, slot) return BAGS[bag] and BAGS[bag][slot] end,
}
ItemLocation = { CreateFromBagAndSlot = function(self, b, s) return { bag = b, slot = s } end }
function GetInboxNumItems() return #INBOX end
INBOX = {}
function GetInboxInvoiceInfo(i) local m = INBOX[i] if m.kind == "none" then return nil end return m.kind or "seller", m.name, "Buyer", m.bid, m.bid, m.dep, m.cut, 0, 0, 0, m.count end
function GetInboxHeaderInfo(i) local m = INBOX[i] return nil, nil, "AH", "Sold", m.money or (m.bid - (m.cut or 0)), m.cod or 0, m.daysLeft, m.items end
TAKEN = {}
-- the server hands the money over a moment later; the sale mail then disappears
function TakeInboxMoney(i) local m = INBOX[i] table.insert(TAKEN, m.name) C_Timer.After(0.3, function() for k, x in ipairs(INBOX) do if x == m then table.remove(INBOX, k) break end end end) end
"""
lua.execute(MOCK)
toc = (ADDON / "FlipForever.toc").read_text(encoding="utf-8").splitlines()
files = [l.strip() for l in toc if l.strip().endswith(".lua")]
print("load order from TOC:", files)
assert len(files) == len(set(f.lower() for f in files)), "a file is listed twice in the TOC (the game warns: Duplicate File Load)"
shared_ns = lua.table()   # WoW gives every file of one addon the same private table
for f in files:
    src = (ADDON / f.replace("\\", "/")).read_text(encoding="utf-8")
    fn = lua.eval("function(src, name) local f, err = load(src, '@'..name) if not f then error(err) end return f end")(src, f)
    fn("FlipForever", shared_ns)
print("all files compile and load")

L = lua.eval
lua.execute("""
Fire("ADDON_LOADED", "FlipForever")
AUTO_SHIPPED = FlipForever.Auto.AVAILABLE
FlipForever.Auto.AVAILABLE = true             -- the autopilot is off for players, but its code stays tested
FlipForeverDB.settings.livePlanning = false   -- in-game planning is tested on its own (Beta 4 block)
FlipForeverDB.settings.combatSmart = false    -- the step mode is tested first; smart mode has its own block
Fire("PLAYER_LOGIN")
Fire("AUCTION_HOUSE_SHOW")
""")

# --- full scan
lua.execute("""
REPL = {
  {name="Linen Cloth", id=2589, count=20, buyout=20*50},
  {name="Linen Cloth", id=2589, count=10, buyout=10*40},
  {name="Linen Cloth", id=2589, count=40, buyout=40*70},
  {name="Copper Ore", id=2770, count=5, buyout=5*100},
}
FlipForeverDB.lastReplicate = 0
FlipForever.Scan:StartFull()
Fire("REPLICATE_ITEM_LIST_UPDATE")
for i = 1, 6 do RunTickers() end
RunTimers(5)
""")
db = L("FlipForeverDB.realms['Testrealm - Horde']")
if not db.scans[1]:
    print("DEBUG busy:", L("FlipForever.Scan.busy"), "| status:", L("FlipForever.status"), "| printed:", list(L("printed").values()),
          "| watch:", L("FlipForever.Scan.watch and FlipForever.Scan.watch.stable"), "| tickers:", L("#TICKERS"))
print("scan:", db.scans[1].src, db.scans[1].d, "| names:", db.names[2589])
assert db.scans[1].src == "full"
assert "2589:40:50:70:3" in db.scans[1].d, db.scans[1].d

# --- buy flow (commodity)
lua.execute("""
FlipForever_Plan = { generated = 123, realm = "Testrealm - Horde", duration = 2,
  buy = { {id=2589, max=60, qty=25, exp=80}, {id=2770, max=50, qty=5, exp=90} },
  sell = { {id=2589, floor=60, normal=80, ceil=130} } }
COMMODITY[2589] = {
  {unitPrice=40, quantity=10, containsOwnerItem=false},
  {unitPrice=50, quantity=20, containsOwnerItem=false},
  {unitPrice=70, quantity=40, containsOwnerItem=false},
}
COMMODITY[2770] = { {unitPrice=100, quantity=5} }
calls = {}
FlipForever.Trader:Primary()      -- idle -> start buying -> search
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
""")
T = L("FlipForever.Trader")
print("after search:", T.state, T.pending.qty, T.pending.cost, "| button:", L("FlipForever.Trader:ButtonText()"))
assert T.state == "ready_commodity" and T.pending.qty == 25 and T.pending.cost == 10 * 40 + 15 * 50
lua.execute("""
FlipForever.Trader:Primary()                 -- start purchase
Fire("COMMODITY_PRICE_UPDATED", 46, 1150)
""")
print("quote:", T.state, L("FlipForever.Trader:ButtonText()"))
assert T.state == "confirm_commodity"
lua.execute("""
FlipForever.Trader:Primary()                 -- confirm
Fire("COMMODITY_PURCHASE_SUCCEEDED")
RunTimers(1)
""")
log = db.log
print("logged:", log[1].e, log[1].q, log[1].p, log[1].exp, "| state:", T.state, "searching for", T.searchID)
assert log[1].e == "buy" and log[1].q == 25 and log[1].p == 46
# second item: too expensive -> skipped, list done
lua.execute("""
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
""")
print("after copper:", T.state, L("FlipForever.status"))
assert T.state == "idle"

# --- sell flow
lua.execute("""
BAGS[0] = { [3] = {itemID=2589, stackCount=20}, [4] = {itemID=2589, stackCount=5} }
BAGCOUNT[2589] = 25
COMMODITY[2589] = {
  {unitPrice=75, quantity=10, containsOwnerItem=false},
  {unitPrice=90, quantity=20, containsOwnerItem=false},
}
calls = {}
FlipForever.Trader:StartSelling()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
""")
print("sell:", T.state, L("FlipForever.Trader:ButtonText()"), L("FlipForever.status"))
assert T.state == "ready_post" and T.pending.unit == 74 and T.pending.qty == 25
lua.execute("""
FlipForever.Trader:Primary()
Fire("AUCTION_HOUSE_AUCTION_CREATED", 99)
""")
c = L("calls[#calls]")
print("post call:", c[1], c[3], c[4], c[5], "| log:", db.log[2].e, db.log[2].q, db.log[2].p, db.log[2].dep)
assert c[1] == "PostCommodity" and c[4] == 25 and c[5] == 74 and db.log[2].dep == 375

# floor respected
lua.execute("""
COMMODITY[2589] = { {unitPrice=55, quantity=10, containsOwnerItem=false} }
FlipForever.Trader:StartSelling()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
""")
print("below floor:", T.state, db.log[3].e)
assert db.log[3].e == "hold"

# --- sold / expired chat + invoice
lua.execute("""
Fire("CHAT_MSG_SYSTEM", "A buyer has been found for your auction of Linen Cloth.")
Fire("CHAT_MSG_SYSTEM", "Your auction of Linen Cloth has expired.")
INBOX = { {name="Linen Cloth", bid=1850, dep=375, cut=92, count=25, daysLeft=29.9} }
Fire("MAIL_INBOX_UPDATE")
Fire("MAIL_INBOX_UPDATE")
""")
n = L("#FlipForeverDB.realms['Testrealm - Horde'].log")
kinds = [db.log[i].e for i in range(1, n + 1)]
print("log kinds:", kinds, "| sold id:", db.log[4].id)
assert kinds == ["buy", "post", "hold", "sold", "expired", "invoice"], kinds
assert db.log[4].id == 2589

# keybind + slash
lua.execute('SlashCmdList.FLIPFOREVER("key SPACE")')
print("bind:", L("LAST_BIND[3]"), L("LAST_BIND[4]"))
errors = [p for p in L("printed").values() if "error" in p.lower()]
print("addon errors printed:", errors)
assert not errors
# --- budget is a hard cap
lua.execute("""
FlipForever_Plan = { generated = 456, realm = "Testrealm - Horde", budget = 1000,
  buy = { {id=2589, max=60, qty=25, exp=80} }, sell = {} }
COMMODITY[2589] = {
  {unitPrice=40, quantity=10}, {unitPrice=50, quantity=20},
}
FlipForever.Trader:StartBuying()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
""")
print("budget:", T.state, T.pending.qty, T.pending.cost)
assert T.state == "ready_commodity" and T.pending.qty == 22 and T.pending.cost == 1000
lua.execute("""
FlipForever.Trader:Primary()
Fire("COMMODITY_PRICE_UPDATED", 45, 1000)
FlipForever.Trader:Primary()
Fire("COMMODITY_PURCHASE_SUCCEEDED")
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
""")
print("after budget spent:", T.state, "|", L("FlipForever.status"))
spent = L("FlipForeverDB.realms['Testrealm - Horde'].charProgress.Tester.spent")
print("spent:", spent, "of 1000")
assert T.state == "idle" and spent == 990
lua.execute("FlipForever.Trader:StartBuying() RunTimers(1) Fire('COMMODITY_SEARCH_RESULTS_UPDATED', 2589)")
print("restart with 10c left:", T.state, "|", L("FlipForever.status"))
assert T.state == "idle"
# --- gold reserve: 20% of the gold at the start, never below 20g; purchases sized to what is left
lua.execute("""
OLD_MONEY = GetMoney
GetMoney = function() return 300000 end   -- 30g: reserve = max(6g, min(20g, half = 15g)) = 15g, 15g spendable
FlipForever_Plan = { generated = 901, realm = "Testrealm - Horde", budget = 10000000,
  buy = { {id=2589, max=6000, qty=50, exp=8000} }, sell = {} }
COMMODITY[2589] = { {unitPrice=4000, quantity=40} }
FlipForever.Trader:StartBuying()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
""")
print("reserve:", T.state, T.pending and T.pending.qty, L("FlipForever.Trader.reserve"))
assert T.state == "ready_commodity" and T.pending.qty == 37 and L("FlipForever.Trader.reserve") == 150000
lua.execute("""
local T = FlipForever.Trader
-- little gold: the 20g minimum never takes more than half; 0.9g -> 0.45g kept; bigger gold: 20% wins
RSMALL = T:Reserve(9000) .. "," .. T:Reserve(2000000) .. "," .. T:Reserve(0)
-- Settings buttons step through shares and minimums and wrap around
local s = FlipForeverDB.settings
local p1, p2 = T:NextReservePct(), T:NextReservePct()
s.reservePct = 0.5
local p3 = T:NextReservePct()
local m1 = T:NextReserveMin()
s.reserveMin = 1000000
local m2 = T:NextReserveMin()
RSTEP = p1 .. "," .. p2 .. "," .. p3 .. "," .. m1 .. "," .. m2
s.reservePct, s.reserveMin = nil, nil
""")
print("reserve small/steps:", L("RSMALL"), L("RSTEP"))
assert L("RSMALL") == "4500,400000,0" and L("RSTEP") == "0.3,0.5,0,500000,0", (L("RSMALL"), L("RSTEP"))
lua.execute("""
GetMoney = function() return 150500 end
FlipForever.Trader.state = "idle"
FlipForever.Trader:EvaluateBuy(COMMODITY[2589])
""")
print("reserve reached:", T.state, "|", L("FlipForever.status"))
assert T.state == "idle" and "reserve" in L("FlipForever.status")
lua.execute("""
FlipForeverDB.settings.goldReserve = false
GetMoney = function() return 300000 end
FlipForever.Trader:StartBuying()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
""")
print("reserve off:", T.state, T.pending and T.pending.qty)
assert T.state == "ready_commodity" and T.pending.qty == 40
lua.execute("""
FlipForever.Trader:Stop()
SlashCmdList.FLIPFOREVER("reserve 30 50")
RS = tostring(FlipForeverDB.settings.goldReserve) .. "," .. FlipForeverDB.settings.reservePct .. "," .. FlipForeverDB.settings.reserveMin
SlashCmdList.FLIPFOREVER("reserve 10 50s")
RS = RS .. "|" .. FlipForeverDB.settings.reserveMin
SlashCmdList.FLIPFOREVER("reserve 10 1.5")
RS = RS .. "|" .. FlipForeverDB.settings.reserveMin
FlipForever.Trader:NextReserveMin()
RS = RS .. "|" .. FlipForeverDB.settings.reserveMin
FlipForeverDB.settings.goldReserve, FlipForeverDB.settings.reservePct, FlipForeverDB.settings.reserveMin = nil, nil, nil
GetMoney = OLD_MONEY
""")
print("/ff reserve:", L("RS"))
assert L("RS") == "true,0.3,500000|5000|15000|50000", L("RS")
# --- bag space: 3 free slots, 2 kept -> one stack of 20; 2 free -> stops; switch off -> no limit; /ff bags
lua.execute("""
OLD_MONEY, OLD_FREE, OLD_INFO = GetMoney, C_Container.GetContainerNumFreeSlots, C_Item.GetItemInfo
GetMoney = function() return 100000000 end
FREE_SLOTS = 3
C_Container.GetContainerNumFreeSlots = function(bag) if bag == 0 then return FREE_SLOTS, 0 end if bag == 1 then return 9, 8 end return 0, 0 end
C_Item.GetItemInfo = function(id) return "Item", nil, 1, 1, 1, "", "", 20 end
FlipForever.Trader:StartBuying()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
BS1 = FlipForever.Trader.pending and FlipForever.Trader.pending.qty or 0
FlipForever.Trader:Stop()
FREE_SLOTS = 2
FlipForever.Trader:StartBuying()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
BS2 = FlipForever.Trader.state .. ":" .. FlipForever.status
FlipForever.Trader:Stop()
FlipForeverDB.settings.bagSpace = false
FlipForever.Trader:StartBuying()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
BS3 = FlipForever.Trader.pending and FlipForever.Trader.pending.qty or 0
FlipForever.Trader:Stop()
FlipForeverDB.settings.bagSpace = nil
SlashCmdList.FLIPFOREVER("bags 4")
BS4 = FlipForeverDB.settings.bagKeepFree
FlipForeverDB.settings.bagKeepFree = nil
GetMoney, C_Container.GetContainerNumFreeSlots, C_Item.GetItemInfo = OLD_MONEY, OLD_FREE, OLD_INFO
""")
print("bag space:", L("BS1"), "|", L("BS2"), "|", L("BS3"), "|", L("BS4"))
assert L("BS1") == 20 and "bags are nearly full" in L("BS2") and L("BS3") == 40 and L("BS4") == 4
# --- fast flips: 300 cheaper units ahead of a 10/day item (5/day for us = 60 days) -> skipped
lua.execute("""
OLD_MONEY = GetMoney
GetMoney = function() return 100000000 end
FlipForever_Plan = { generated = 902, realm = "Testrealm - Horde", budget = 10000000, hold = 2,
  buy = { {id=2589, max=500, qty=10, exp=1000, vol=10} }, sell = {} }
COMMODITY[2589] = { {unitPrice=400, quantity=10}, {unitPrice=900, quantity=300}, {unitPrice=1000, quantity=50} }
FlipForever.Trader:StartBuying()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
""")
print("slow queue:", T.state, "|", L("FlipForever.status"))
assert T.state == "idle"
lua.execute("""
FlipForever_Plan.buy[1].vol = 400   -- 300 ahead at 200/day for us: 1.5 days, fine
FlipForever_Plan.generated = 903
FlipForever.Trader:StartBuying()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
""")
print("fast queue:", T.state, T.pending and T.pending.qty)
assert T.state == "ready_commodity" and T.pending.qty == 10
lua.execute("""
FlipForever.Trader:Stop()
FlipForever_Plan.buy[1].vol = 10
FlipForever_Plan.generated = 904
FlipForeverDB.settings.fastFlips = false
FlipForever.Trader:StartBuying()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
FS = FlipForever.Trader.state
FlipForever.Trader:Stop()
FlipForeverDB.settings.fastFlips = nil
GetMoney = OLD_MONEY
""")
print("fast flips off:", L("FS"))
assert L("FS") == "ready_commodity"
# --- disenchant values: green armor ilvl 28 -> Soul Dust 75% x1.5, Greater Astral 20% x1.5, Large Glimmering 5%
lua.execute("""
OLD_INFO = C_Item.GetItemInfo
DE_ITEMS = { [9001] = { 2, 28, 4 }, [9002] = { 2, 28, 2 }, [9003] = { 3, 33, 4 }, [9004] = { 1, 28, 4 }, [9005] = { 2, 28, 7 } }
C_Item.GetItemInfo = function(id) local it = DE_ITEMS[id] if it then return "Item " .. id, "link", it[1], it[2], 1, "", "", 1, "", "", 1, it[3] end if OLD_INFO then return OLD_INFO(id) end end
local db = FlipForever:DB()
db.scans[#db.scans + 1] = { t = 9999999990, d = "11083:900:1000:50:5,11082:2900:3000:20:3,11084:3900:4000:10:2,11138:7900:8000:10:2,9001:500:1500:3:2,9002:3000:3500:1:1,9003:4000:9000:1:1" }
DEV = {}
for _, id in ipairs({9001, 9002, 9003, 9004, 9005}) do DEV[#DEV + 1] = tostring(FlipForever.Disenchant:Value(id)) end
DEV = table.concat(DEV, ",")
DEL = FlipForever.Disenchant:BuyList()
DETIP = {}
for _, l in ipairs(FlipForever.Tooltip:Lines(9001)) do DETIP[#DETIP + 1] = l[1] .. " = " .. l[2] end
DETIP = table.concat(DETIP, " | ")
FlipForeverDB.settings.disenchant = false
DEOFF = FlipForever.Tooltip:Lines(9001)
DEOFF = #DEOFF
FlipForeverDB.settings.disenchant = nil
""")
# armor: 0.75*1.5*1000 + 0.2*1.5*3000 + 0.05*4000 = 1125+900+200 = 2225; weapon: 0.2*1.5*1000 + 0.75*1.5*3000 + 200 = 3875
# blue ilvl 33: one Small Glowing Shard = 8000; white and non-gear: nothing
print("disenchant values:", L("DEV"), "| buy list:", L("#DEL"), L("DEL[1] and DEL[1].id"), "| tooltip:", L("DETIP"), "| off:", L("DEOFF"))
assert L("DEV") == "2225,3875,8000,nil,nil"
# listed below value - 15%: 9003 (4000 < 6800), 9001 (500 < 1891), 9002 (3000 < 3293); biggest gain first
assert L("#DEL") == 3 and L("DEL[1].id") == 9003 and L("DEL[2].id") == 9001 and L("DEL[3].id") == 9002
assert "disenchants for = ~" in L("DETIP") and "more than the item" in L("DETIP")
lua.execute("C_Item.GetItemInfo = OLD_INFO; table.remove(FlipForever:DB().scans)")
# --- best time to post: 6 sales of item 7777, 5 of them between 19:00 and 22:59
lua.execute("""
local log = FlipForever:DB().log
BP_START = #log
for _, h in ipairs({19, 20, 20, 21, 22, 9}) do
  log[#log + 1] = { e = "invoice", id = 7777, q = 1, gross = 100, t = os.time({ year = 2026, month = 11, day = 20, hour = h, min = 10 }) }
end
local b = FlipForever:BestPostHours(7777)
BP = b and (b.text .. "," .. tostring(b.own)) or "nil"
FlipForeverDB.settings.bestPostTime = false
BP_OFF = tostring(FlipForever:BestPostHours(7777))
FlipForeverDB.settings.bestPostTime = nil
BP_TIP = {}
for _, l in ipairs(FlipForever.Tooltip:Lines(7777)) do BP_TIP[#BP_TIP + 1] = l[1] .. " = " .. l[2] end
BP_TIP = table.concat(BP_TIP, " | ")
while #log > BP_START do table.remove(log) end
""")
print("best post time:", L("BP"), "| off:", L("BP_OFF"), "| tooltip:", L("BP_TIP"))
assert L("BP") == "19:00-23:00,true" and L("BP_OFF") == "nil" and "your sales peak = 19:00-23:00" in L("BP_TIP")
# --- first-scan mode: price judged live from the listing ladder
lua.execute("""
FlipForever_Plan = { generated = 789, realm = "Testrealm - Horde", budget = 100000, cut = 0.05,
  buy = { {id=4306, gap=0.25, qty=50, max=2000}, {id=4338, gap=0.25, qty=50} }, sell = {} }
-- Silk: 8 cheap units at 300, then the wall at ~1000
COMMODITY[4306] = {
  {unitPrice=300, quantity=8}, {unitPrice=980, quantity=40}, {unitPrice=1000, quantity=200}, {unitPrice=1100, quantity=100},
}
-- Mageweave: no gap at all
COMMODITY[4338] = { {unitPrice=500, quantity=100}, {unitPrice=510, quantity=100} }
FlipForever.Trader:StartBuying()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 4306)
""")
print("gap:", T.state, T.pending and T.pending.qty, T.target.liveMax, T.target.liveExp, "|", L("FlipForever.status"))
# ref = 30% of 348 units -> 1000; live max = 1000*0.95/1.25 = 760 -> only the 8 @300
assert T.state == "ready_commodity" and T.pending.qty == 8 and T.target.liveMax == 760
lua.execute("""
FlipForever.Trader:Primary()
Fire("COMMODITY_PRICE_UPDATED", 300, 2400)
FlipForever.Trader:Primary()
Fire("COMMODITY_PURCHASE_SUCCEEDED")
RunTimers(1)
COMMODITY[4306] = { {unitPrice=980, quantity=40}, {unitPrice=1000, quantity=200} }
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 4306)
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 4338)
""")
n = L("#FlipForeverDB.realms['Testrealm - Horde'].log")
last = db.log[n]
print("gap buy logged:", last.e, last.q, last.p, "exp", last.exp, "| state:", T.state)
assert last.e == "buy" and last.q == 8 and last.p == 300 and last.exp == 1000 and T.state == "idle"

# selling the silk: no rule in plan.sell -> added from the buy; floor from cost
lua.execute("""
BAGS[1] = { [1] = {itemID=4306, stackCount=8} }
BAGCOUNT[4306] = 8
COMMODITY[4306] = { {unitPrice=975, quantity=40} }
FlipForever.Trader:StartSelling()
RunTimers(1)
""")
print("sell target:", T.target and T.target.id)
lua.execute('Fire("COMMODITY_SEARCH_RESULTS_UPDATED", T and 4306 or 4306)')
print("sell silk:", T.state, T.pending and T.pending.unit)
assert T.state == "ready_post" and T.pending.unit == 974
lua.execute("""
FlipForever.Trader:Stop()
COMMODITY[4306] = { {unitPrice=310, quantity=40} }
FlipForever.Trader:StartSelling()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 4306)
""")
n = L("#FlipForeverDB.realms['Testrealm - Horde'].log")
print("market crashed below cost:", T.state, db.log[n].e)
assert db.log[n].e == "hold"
# --- shared cooldown: a second full scan inside 15 min is refused for autopilot
lua.execute("calls = {}")
started = L("(FlipForever.Scan:StartFull(true))")
wait = L("select(2, FlipForever.Scan:StartFull(true))")
print("auto scan inside cooldown:", started, "wait", wait)
assert started is False and wait > 800
# Auctioneer's own request time counts too
lua.execute("FlipForeverDB.lastReplicate = 0; AucAdvancedData = { ForeverReplicateRequested = time() - 60 }")
print("Auctioneer scanned 1 min ago -> wait", L("select(2, FlipForever.Scan:StartFull(true))"))
assert L("select(2, FlipForever.Scan:StartFull(true))") > 800
lua.execute("AucAdvancedData = nil")

# --- piggyback: another addon's replicate scan is read too
lua.execute("""
FlipForeverDB.lastReplicate = 0
local before = #FlipForeverDB.realms['Testrealm - Horde'].scans
REPL = { {name="Iron Ore", id=2772, count=10, buyout=10*700} }
C_AuctionHouse.ReplicateItems()          -- called by 'another addon' (not flagged as ours)
PIGGY_BUSY = FlipForever.Scan.busy
Fire("REPLICATE_ITEM_LIST_UPDATE")
for i = 1, 6 do RunTickers() end
RunTimers(5)
PIGGY_ADDED = #FlipForeverDB.realms['Testrealm - Horde'].scans - before
""")
print("external scan: busy while waiting =", L("PIGGY_BUSY"), "| scans added:", L("PIGGY_ADDED"))
assert L("PIGGY_BUSY") == "external" and L("PIGGY_ADDED") == 1

# --- autopilot: searches every minute, alerts on a deal, yields to other addons, pauses for scans
lua.execute("""
FlipForever_Plans = nil
FlipForever_Plan = { generated = 999, realm = "Testrealm - Horde", budget = 100000, cut = 0.05,
  buy = { {id=4306, gap=0.25, qty=50} }, sell = {} }
COMMODITY[4306] = { {unitPrice=300, quantity=5}, {unitPrice=1000, quantity=300} }
FlipForever.Trader:Stop()
ALERTS = {}
FlipForever.needReload = nil
FlipForeverDB.settings.reloadAfterScan = false   -- this block tests autopilot without the reload pause
FlipForever.Auto:SetEnabled(true)
FlipForever.Auto.nextScan = time() + 9999
FlipForever.Auto.lastExternal = 0
RunTickers()                      -- autopilot tick -> starts a sweep
RunTimers(1)                      -- search sent
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 4306)
RunTickers()
""")
print("auto deal:", L("FlipForever.Trader.state"), "| phase:", L("FlipForever.Auto.phase"), "| alerts:", list(L("ALERTS").values()))
alerts = list(L("ALERTS").values())
assert L("FlipForever.Trader.state") == "ready_commodity" and L("FlipForever.Auto.phase") == "deal"
assert any(a.startswith("sound:") for a in alerts) and any(a.startswith("rw:FLIP FOUND") for a in alerts) and "flash" in alerts

# deal ignored -> stays waiting; skip it, sweep ends, next check scheduled ~60s out
lua.execute("""
FlipForever.Trader:Skip()
RunTickers()
""")
nxt = L("FlipForever.Auto.nextSearch - time()")
print("after sweep: state", L("FlipForever.Trader.state"), "next search in", nxt)
assert L("FlipForever.Trader.state") == "idle" and 55 <= nxt <= 60

# another addon / the user sends a query -> autopilot steps aside
lua.execute("""
FlipForever.Auto.nextSearch = 0
C_AuctionHouse.SendSearchQuery({itemID=1}, {}, true)   -- e.g. Auctionator
RunTickers()
""")
print("after external query: phase", L("FlipForever.Auto.phase"), "trader", L("FlipForever.Trader.state"))
assert L("FlipForever.Auto.phase") == "yield" and L("FlipForever.Trader.state") == "idle"

# scan due -> scan starts, searching paused until it finishes
lua.execute("""
FlipForever.Auto.lastExternal = 0
FlipForever.Auto.nextScan = 0
FlipForeverDB.lastReplicate = 0
REPL = { {name="Silk Cloth", id=4306, count=20, buyout=20*900} }
RunTickers()
SCAN_PHASE = FlipForever.Auto.phase
SCAN_BUSY = FlipForever.Scan.busy
RunTickers()
SCAN_PHASE2 = FlipForever.Auto.phase
SEARCHING_DURING = FlipForever.Trader.state
Fire("REPLICATE_ITEM_LIST_UPDATE")
for i = 1, 6 do RunTickers() end
RunTimers(5)
RunTickers()
""")
print("scan: phase", L("SCAN_PHASE"), L("SCAN_PHASE2"), "| busy", L("SCAN_BUSY"), "| trader during scan:", L("SEARCHING_DURING"),
      "| after: next scan in", L("FlipForever.Auto.nextScan - time()"), "phase", L("FlipForever.Auto.phase"))
assert L("SCAN_PHASE") == "scanning" and L("SCAN_PHASE2") == "scanning" and L("SEARCHING_DURING") == "idle"
assert L("FlipForever.Auto.nextScan - time()") >= 1795 and L("FlipForever.Scan.busy") is None
assert L("FlipForever.Auto.phase") == "searching"   # searches resume right after the scan

# key conflict with Auctionator
lua.execute('AUCTIONATOR_CONFIG = { selling_post_shortcut = "SPACE" }; printed = {}; FlipForeverDB.settings.key = nil')
lua.execute('SlashCmdList.FLIPFOREVER("key SPACE")')
print("key SPACE:", L("printed[#printed]"), "| saved:", L("FlipForeverDB.settings.key"))
assert "Auctionator" in L("printed[#printed]") and L("FlipForeverDB.settings.key") != "SPACE"
lua.execute('SlashCmdList.FLIPFOREVER("key CTRL-SPACE")')
assert L("FlipForeverDB.settings.key") == "CTRL-SPACE"
lua.execute("FlipForever.Auto:SetEnabled(false)")

# --- advisor: level 22 Skyborne Frost mage, 2 unspent points, white staff, empty bag slots, no professions
lua.execute("""
UnitName = function() return 'Tester' end
BAGS = {}
C_Container.GetContainerNumSlots = function(bag) if bag >= 3 then return 0 end return 16 end  -- 2 empty bag slots
FlipForever.Advisor:Show()
ADV = {}
for i, r in ipairs(FlipForever.Advisor.last) do ADV[i] = r.text:gsub('|T.-|t%s*', ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '') end
""")
adv = list(L("ADV").values())
print("ADVISOR (level 22 mage):")
for a in adv: print("   -", a)
assert any("Spend 2 talent points" in a and "Ice Shards +2" in a for a in adv), "talent advice"

# --- advisor: where talent points go, across talents, tiers and trees
lua.execute("""
local AD = FlipForever.Advisor
local oT, oN, oI, oTab = GetNumTalentTabs, GetNumTalents, GetTalentInfo, GetTalentTabInfo
local TREES = {
  { name = "Holy", t = { {"Divine Strength", 1, 0, 5}, {"Divine Intellect", 1, 0, 5} } },
  { name = "Retribution", t = { {"Benediction", 1, 3, 5}, {"Improved Judgement", 2, 0, 2}, {"Seal of Command", 3, 0, 1} } },
}
GetNumTalentTabs = function() return #TREES end
GetNumTalents = function(tab) return #TREES[tab].t end
GetTalentInfo = function(tab, i) local t = TREES[tab].t[i] return t[1], nil, t[2], 1, t[3], t[4] end
GetTalentTabInfo = function(tab) return TREES[tab].name end
local build = { name = "Ret", keyOnly = true, talents = { {"Seal of Command", 1}, {"Improved Judgement", 2}, {"Benediction", 5} } }
local plan, left = AD:SpendPlan(build, 6, 30)
local s = {}
for _, o in ipairs(plan) do s[#s + 1] = AD:SpendText(o) end
SPEND = table.concat(s, "; ") .. " | left " .. left
-- not enough points in the tree yet for tier 3: Seal of Command waits
plan, left = AD:SpendPlan(build, 1, 30)
SPEND1 = AD:SpendText(plan[1]) .. " | left " .. left
-- an ordered build hands out points in its order and stops at the minimum level
local ordered = { name = "Ord", talents = { {"Divine Strength", 2}, {"Benediction", 5}, {"Seal of Command", 1, 40} } }
plan, left = AD:SpendPlan(ordered, 10, 30)
s = {}
for _, o in ipairs(plan) do s[#s + 1] = AD:SpendText(o) end
SPEND_ORD = table.concat(s, "; ") .. " | left " .. left
NOPLAN = AD:SpendPlan(build, 0, 30) == nil and AD:SpendPlan({ name = "x" }, 3, 30) == nil
-- the Advisor step opens the Talents window when clicked
OPENED = 0
ToggleTalentFrame = function() OPENED = OPENED + 1 end
local oldBuild = AD.Build
AD.Build = function() return build end
UNSPENT = 3
FlipForever.Advisor:Show()
for _, r in ipairs(AD.last) do if r.kind == "talent" then TSTEP = r.text TWHY = r.why if r.action then r.action() end end end
AD.Build = oldBuild
UNSPENT = 2
GetNumTalentTabs, GetNumTalents, GetTalentInfo, GetTalentTabInfo = oT, oN, oI, oTab
""")
print("spend plan:", L("SPEND"), "|", L("SPEND1"), "|", L("SPEND_ORD"))
print("talent step:", L("TSTEP"), "| opened:", L("OPENED"))
assert L("SPEND") == "Benediction +2 (Retribution); Improved Judgement +2 (Retribution) | left 2", L("SPEND")
assert L("SPEND1") == "Benediction +1 (Retribution) | left 0", L("SPEND1")
assert L("SPEND_ORD") == "Divine Strength +2 (Holy); Benediction +2 (Retribution) | left 6", L("SPEND_ORD")
assert L("NOPLAN") is True
assert "Spend 3 talent points for Ret" in L("TSTEP") and "Benediction" in L("TSTEP") and "Improved Judgement" in L("TSTEP") and "Talents window" in L("TWHY") and L("OPENED") == 1
assert any("Hypnotic" not in a for a in adv)
assert any("Coldspire Staff" in a for a in adv), "gear advice"
assert any("Learn Tailoring + Enchanting" in a for a in adv), "profession advice"
assert any("Weak slots" in a and "Main hand (white)" in a for a in adv), "weak slot"
assert any(a.startswith("Dungeon for upgrades: ") and "(entrance: " in a for a in adv), [a for a in adv if "ungeon" in a]
assert any("empty bag slot" in a for a in adv), "bags"
assert any("Next power spike at level 24: Counterspell" in a for a in adv), "spike"

# a level-up and a new staff change the advice; Ice Lance follows once Ice Shards is done
lua.execute("""
TALENTS[4][2] = 3
GEAR[16] = {id=102, name="Coldspire Staff", q=2}; ITEMNAMES[102] = "Coldspire Staff"
UNSPENT = 1
Fire("PLAYER_LEVEL_UP", 23)
RunTimers(5)
ADV = {}
for i, r in ipairs(FlipForever.Advisor.last) do ADV[i] = r.text:gsub('|T.-|t%s*', ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '') end
""")
adv = list(L("ADV").values())
print("after level-up + new staff:", adv[:3])
assert any("Ice Lance +1" in a for a in adv)
assert not any("Get Coldspire Staff" in a for a in adv)
snap = L("FlipForeverDB.realms['Testrealm - Horde'].chars.Tester.advisor")
print("snapshot for app:", snap.build, "|", snap.steps[1])
assert snap.build.startswith("Frost")

# warlock: class quest due -> recommended until the spell is learned
lua.execute("""
UnitClass = function() return "Warlock", "WARLOCK" end
PLEVEL = 10
KNOWN = { "Shadow Bolt", "Summon Imp" }
FlipForever.Advisor:Refresh()
W1 = FlipForever.Advisor.last
KNOWN = { "Shadow Bolt", "Summon Imp", "Summon Voidwalker" }
FlipForever.Advisor:Refresh()
W2 = FlipForever.Advisor.last
""")
def has(name, needle): return any(needle in r.text for r in L(name).values())
print("warlock L10 voidwalker quest shown before/after learning:", has("W1", "Voidwalker class quest"), has("W2", "Voidwalker class quest"))
assert has("W1", "Voidwalker class quest") and not has("W2", "Voidwalker class quest")

# build switching cycles and is remembered per character
lua.execute("UnitClass = function() return 'Warrior', 'WARRIOR' end; FlipForever.Advisor:CycleBuild(1)")
print("warrior build after one click:", L("FlipForever.Advisor:Build(FlipForever.Advisor:Player()).name"))
assert L("FlipForever.Advisor:Build(FlipForever.Advisor:Player()).id") == "prot"

# --- combat helper: frost mage, steps cycle one per click, adapt to target between fights
lua.execute("""
UnitClass = function() return "Mage", "MAGE" end
UnitName = function(u) if u == "target" then return TARGET and TARGET.name end return "Tester" end
PLEVEL = 30
KNOWN = { "Frostbolt", "Fireball", "Fire Blast", "Ice Lance", "Frost Nova" }
FlipForever.Advisor:CharStore().build = "frost"
TARGET = { name = "Defias Bandit", ctype = "Humanoid", level = 30, power = 1 }
FlipForeverDB.settings.combatTarget = false  -- this part tests the spell sequence only
FlipForever.Combat:Toggle()       -- on
CB = FlipForeverCombatButton
SEQ1 = {}
for i = 1, 6 do SEQ1[i] = CB:GetAttribute("macrotext"); ClickButton(CB, false) end
ICON = CB.icon.texture
""")
seq1 = list(L("SEQ1").values())
print("frost mage vs humanoid, 6 clicks:", [s.replace("/cast ", "") for s in seq1])
assert seq1[:5] == ["/cast Frostbolt", "/cast Frostbolt", "/cast Ice Lance", "/cast Frostbolt", "/cast Fire Blast"] and seq1[5] == "/cast Frostbolt"
print("big icon after 6 clicks:", L("ICON"))
assert L("ICON") == "icon:Frostbolt"

# the 'up' half of a key press must not skip a step
lua.execute("BEFORE = CB:GetAttribute('step'); ClickButton(CB, true); AFTER = CB:GetAttribute('step')")
assert L("BEFORE") == L("AFTER")

# target a water elemental out of combat -> frost swapped for fire; hint mentions it
lua.execute("""
TARGET = { name = "Tide Elemental", ctype = "Elemental", level = 33, class = "elite", power = 0 }
Fire("PLAYER_TARGET_CHANGED")
SEQ2 = {}
for i = 1, 5 do SEQ2[i] = CB:GetAttribute("macrotext"); ClickButton(CB, false) end
""")
seq2 = [s.replace("/cast ", "") for s in L("SEQ2").values()]
hint = L("FlipForeverCombatBar") and None
print("vs water elemental:", seq2)
assert "Frostbolt" not in seq2 and "Ice Lance" not in seq2 and seq2[0] == "Fireball"

# in combat: target change can't rebuild (secure rule) -> waits for the fight to end
lua.execute("""
COMBAT = true
TARGET = { name = "Skeleton", ctype = "Undead", level = 30 }
Fire("PLAYER_TARGET_CHANGED")
MID = CB:GetAttribute("step1")
COMBAT = false
Fire("PLAYER_REGEN_ENABLED")
AFTERFIGHT = CB:GetAttribute("step1")
""")
print("in combat step1 stays:", L("MID"), "| after fight:", L("AFTERFIGHT"))
assert L("MID") == "/cast Fireball" and L("AFTERFIGHT") == "/cast Frostbolt"

# paladin vs undead gets Exorcism; warrior vs mechanical drops Rend
lua.execute("""
UnitClass = function() return "Paladin", "PALADIN" end
KNOWN = { "Seal of Righteousness", "Judgement", "Holy Strike", "Exorcism" }
FlipForever.Combat:Rebuild()
PAL = {} for i = 1, CB:GetAttribute("count") do PAL[i] = CB:GetAttribute("step" .. i) end
UnitClass = function() return "Warrior", "WARRIOR" end
FlipForever.Advisor:CharStore().build = "arms"
KNOWN = { "Battle Shout", "Rend", "Heroic Strike" }
TARGET = { name = "Mechano-Tank", ctype = "Mechanical", level = 30 }
FlipForever.Combat:Rebuild()
WAR = {} for i = 1, CB:GetAttribute("count") do WAR[i] = CB:GetAttribute("step" .. i) end
""")
pal = [s.split("/cast ")[-1] for s in L("PAL").values()]
war = [s.split("/cast ")[-1] for s in L("WAR").values()]
print("paladin vs undead:", pal)
print("warrior vs mechanical:", war, "| melee prefix:", "/startattack" in L("WAR")[1])
assert "Exorcism" in pal and "Rend" not in war and "/startattack" in L("WAR")[1]
print("target hint:", L("FlipForever.Combat:TargetHint(FlipForever.Combat:Target())"))
lua.execute("FlipForever.Combat:Toggle()")

# --- the FlipForever window: everything reachable with the mouse
lua.execute("""
COMPARTMENT = {}
Fire("PLAYER_LOGIN")
SlashCmdList.FLIPFOREVER("")                    -- plain /ff opens the window
HUB = FlipForeverHub
HUB_SHOWN = HUB:IsShown()
MM = FlipForeverMinimapButton ~= nil
HUB.combat.OnClick(HUB.combat)                  -- tick "Show the combat helper"
COMBAT_ON = FlipForever.Combat:Enabled()
-- Set key (combat) -> press CTRL+Q
HUB.combatKeyButton.OnClick(HUB.combatKeyButton)
CAP_SHOWN = FlipForeverKeyCapture:IsShown()
MODS.ctrl = true
FlipForeverKeyCapture.OnKeyDown(FlipForeverKeyCapture, "LCTRL")   -- modifier alone: keep waiting
FlipForeverKeyCapture.OnKeyDown(FlipForeverKeyCapture, "Q")
MODS.ctrl = false
COMBAT_KEY = FlipForeverDB.settings.combatKey
-- Set key (auction house) -> press CTRL+Q too: must be refused (already the combat key)
FlipForeverDB.settings.key = nil
HUB.ahKeyButton.OnClick(HUB.ahKeyButton)
MODS.ctrl = true
FlipForeverKeyCapture.OnKeyDown(FlipForeverKeyCapture, "Q")
MODS.ctrl = false
AH_KEY_AFTER_CLASH = FlipForeverDB.settings.key
-- Escape cancels
HUB.ahKeyButton.OnClick(HUB.ahKeyButton)
FlipForeverKeyCapture.OnKeyDown(FlipForeverKeyCapture, "ESCAPE")
AH_KEY_AFTER_ESC = FlipForeverDB.settings.key
-- autopilot + minimap checkboxes
HUB.auto.OnClick(HUB.auto)
AUTO_ON = FlipForever.Auto:Enabled()
HUB.mm:SetChecked(false); HUB.mm.OnClick(HUB.mm)
MM_HIDDEN = FlipForeverDB.settings.hideMinimap
""")
print("hub shown:", L("HUB_SHOWN"), "| minimap button:", L("MM"), "| AddOns menu:", list(L("COMPARTMENT").values()))
print("combat checkbox:", L("COMBAT_ON"), "| capture box shown:", L("CAP_SHOWN"), "| combat key:", L("COMBAT_KEY"))
print("AH key after pressing the combat key:", L("AH_KEY_AFTER_CLASH"), "| after Escape:", L("AH_KEY_AFTER_ESC"))
print("autopilot checkbox:", L("AUTO_ON"), "| minimap hidden:", L("MM_HIDDEN"))
assert L("HUB_SHOWN") and L("MM") and list(L("COMPARTMENT").values()) == ["FlipForever"]
assert L("COMBAT_ON") is True and L("CAP_SHOWN") and L("COMBAT_KEY") == "CTRL-Q"
assert L("AH_KEY_AFTER_CLASH") is None and L("AH_KEY_AFTER_ESC") is None
assert L("AUTO_ON") is True and L("MM_HIDDEN") is True
lua.execute("FlipForever.Combat:SetKey(nil); FlipForever.Combat:Toggle(); FlipForever.Auto:SetEnabled(false)")
# --- 2.1: tooltip prices, today's results, minimap summary
lua.execute("""
UnitName = function(u) return "Tester" end
GameTooltip = { lines = {} }
function GameTooltip:AddDoubleLine(a, b) table.insert(self.lines, a .. " = " .. b) end
FlipForever_Plans = nil
FlipForever_Plan = { generated = 2101, realm = "Testrealm - Horde", budget = 50000,
  buy = { {id = 2589, max = 60, qty = 10} }, sell = { {id = 2589, floor = 55, normal = 80, ceil = 120} } }
TT_HOOKS[0](GameTooltip, { id = 2589 })
TIPLINES = GameTooltip.lines
-- a tooltip for an item FlipForever knows nothing about adds nothing
GameTooltip.lines = {}
TT_HOOKS[0](GameTooltip, { id = 999999 })
TIP_UNKNOWN = #GameTooltip.lines
-- switched off in the window -> no lines
FlipForeverDB.settings.tooltips = false
GameTooltip.lines = {}
TT_HOOKS[0](GameTooltip, { id = 2589 })
TIP_OFF = #GameTooltip.lines
FlipForeverDB.settings.tooltips = nil
-- today's results: one sale and one buy today, one sale yesterday
local log = FlipForeverDB.realms['Testrealm - Horde'].log
table.insert(log, { e = "invoice", t = NOW - 60, gross = 2000, cut = 100, q = 20, char = "Tester" })
table.insert(log, { e = "invoice", t = NOW - 2 * 86400, gross = 5000, cut = 250, q = 50, char = "Tester" })
table.insert(log, { e = "buy", t = NOW - 30, q = 10, p = 50, char = "Tester" })
TODAY = FlipForever:Today()
SUMMARY = FlipForever.Hub:Summary()
""")
tips = list(L("TIPLINES").values())
print("tooltip for Linen:", tips)
assert any("typical price" in t for t in tips) and any("on your shopping list" in t for t in tips) and any("you post at" in t for t in tips)
assert L("TIP_UNKNOWN") == 0 and L("TIP_OFF") == 0
today = L("TODAY")
print("today:", dict(today.items()) if hasattr(today, "items") else today)
assert today.sold >= 1900 and today.sales >= 1 and today.spent >= 500 and today.buys >= 1
summary = list(L("SUMMARY").values())
print("minimap summary:", summary)
assert summary[0].startswith("Shopping list: 1 to check") and summary[1].startswith("Today: sold")

# --- 2.2: profession planner (self-contained: reads the game's recipe data)
lua.execute("""
C_TradeSkillUI = {
  IsTradeSkillLinked = function() return false end,
  IsTradeSkillGuild = function() return false end,
  GetBaseProfessionInfo = function() return { professionName = "Tailoring", skillLevel = 50, maxSkillLevel = 75 } end,
  GetAllRecipeIDs = function() return { 1, 2, 3, 4 } end,
  GetRecipeInfo = function(id)
    return ({
      { name = "Bolt of Linen Cloth", learned = true, relativeDifficulty = 1 },
      { name = "Linen Cloak", learned = true, relativeDifficulty = 0 },
      { name = "Heavy Linen Gloves", learned = false, relativeDifficulty = 0 },
      { name = "Brown Linen Shirt", learned = true, relativeDifficulty = 3 },
    })[id]
  end,
  GetRecipeSchematic = function(id)
    return ({
      { outputItemID = 2996, quantityMin = 1, reagentSlotSchematics = { { quantityRequired = 2, reagents = { { itemID = 2589 } } } } },
      { outputItemID = 2570, quantityMin = 1, reagentSlotSchematics = { { quantityRequired = 1, reagents = { { itemID = 2996 } } }, { quantityRequired = 1, reagents = { { itemID = 2320 } } } } },
      { outputItemID = 4307, quantityMin = 1, reagentSlotSchematics = { { quantityRequired = 2, reagents = { { itemID = 2996 } } }, { quantityRequired = 1, reagents = { { itemID = 2320 } } } } },
      { outputItemID = 2576, quantityMin = 1, reagentSlotSchematics = { { quantityRequired = 1, reagents = { { itemID = 2996 } } } } },
    })[id]
  end,
}
C_Item.GetItemInfo = function(id) if id == 2320 then return "Coarse Thread", nil, 1, 1, 1, "", "", 20, "", "", 10 end end
C_Item.GetItemCount = function(id) return BAGCOUNT[id] or 0 end
BAGCOUNT[2589] = 4
UnitClass = function() return "Mage", "MAGE" end
Fire("TRADE_SKILL_SHOW")
RunTimers(1)
PLAN = FlipForever.Professions:Plan("Tailoring")
TOP = PLAN[1]
TOPSTEP = FlipForever.Professions:TopStep("Tailoring")
SHOWN = FlipForeverProfPlanner and FlipForeverProfPlanner:IsShown()
FlipForever.Professions.current = "Tailoring"
BUYLIST = FlipForever.Professions:BuyList("Tailoring", 1)
FlipForever.Advisor:Refresh()
ADVPROF = nil
for _, r in ipairs(FlipForever.Advisor.last) do if r.text:find("Tailoring") then ADVPROF = r.text end end
""")
top = L("TOP")
print("planner top:", top.recipe.name, "| chance", top.chance, "| per point", top.perPoint, "| crafts", top.crafts, "| panel shown:", L("SHOWN"))
print("top step:", L("TOPSTEP"))
assert top.recipe.name == "Bolt of Linen Cloth" and top.chance == 0.75 and top.crafts == 7
assert L("SHOWN")
names = [r.recipe.name for r in L("PLAN").values()]
print("ranked:", names)
assert "Brown Linen Shirt" not in names  # grey: no skill-ups
cloak = [r for r in L("PLAN").values() if r.recipe.name == "Linen Cloak"][0]
print("Linen Cloak priced through its crafted Bolt:", not cloak.unknown, "| per point", cloak.perPoint)
assert not cloak.unknown and cloak.perPoint == 100 + 40   # bolt = 2 linen (100c) + thread (4 x 10c)
bl = list(L("BUYLIST").values())
print("buy list:", [(b.id, b.qty, b.max) for b in bl])
assert len(bl) == 1 and bl[0].id == 2589 and bl[0].qty == 10 and bl[0].max == 62
print("advisor:", L("ADVPROF"))
assert L("ADVPROF") and "craft 7x Bolt of Linen Cloth" in L("ADVPROF")

# buy the mats at the AH: same one-key buyer, custom list, never above max
lua.execute("""
COMMODITY[2589] = { {unitPrice = 55, quantity = 6}, {unitPrice = 60, quantity = 10}, {unitPrice = 90, quantity = 50} }
FlipForever.Professions.pendingMats = BUYLIST
FlipForever.Professions:BuyPending()
RunTimers(1)
Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
MATSTATE = FlipForever.Trader.state
MATQTY = FlipForever.Trader.pending and FlipForever.Trader.pending.qty
FlipForever.Trader:Primary()
Fire("COMMODITY_PRICE_UPDATED", 58, 580)
FlipForever.Trader:Primary()
Fire("COMMODITY_PURCHASE_SUCCEEDED")
RunTimers(1)
MATDONE = FlipForever.Trader.state
MATSTATUS = FlipForever.status
""")
print("mats buy:", L("MATSTATE"), L("MATQTY"), "->", L("MATDONE"), "|", L("MATSTATUS"))
assert L("MATSTATE") == "ready_commodity" and L("MATQTY") == 10 and L("MATDONE") == "idle" and "profession mats" in L("MATSTATUS")

# --- 2.3: crafted mats list their own materials; gather hint; mailbox summary
lua.execute("""
-- top craft that needs bolts: make Bolt of Linen grey so Linen Cloak (needs a bolt) is top
local orig = C_TradeSkillUI.GetRecipeInfo
C_TradeSkillUI.GetRecipeInfo = function(id)
  local r = orig(id)
  if id == 1 then r = { name = r.name, learned = true, relativeDifficulty = 3 } end
  return r
end
FlipForever.Professions:Capture()
CPLAN = FlipForever.Professions:Plan("Tailoring")
CMISS = FlipForever.Professions:Missing(CPLAN[1])
CBUY = FlipForever.Professions:BuyList("Tailoring", 1)
C_TradeSkillUI.GetRecipeInfo = orig
-- mailbox: two new sale invoices -> one summary line
printed = {}
INBOX = { {name="Linen Cloth", bid=3000, dep=0, cut=150, count=30, daysLeft=29.99},
          {name="Wool Cloth", bid=2000, dep=0, cut=100, count=10, daysLeft=29.98} }
Fire("MAIL_SHOW")
Fire("MAIL_INBOX_UPDATE")
Fire("MAIL_INBOX_UPDATE")
RunTimers(2)
MAILMSG = printed[#printed]
""")
top = L("CPLAN")[1]
miss = [(m.id, m.need, m.missing, m.source, m.via) for m in L("CMISS").values()]
print("top craft:", top.recipe.name, "| materials:", miss)
assert top.recipe.name == "Linen Cloak"
assert any(m[0] == 2996 and m[3] == "crafted" for m in miss) and any(m[0] == 2589 and m[4] == "Bolt of Linen Cloth" for m in miss)
buy = [(b.id, b.qty) for b in L("CBUY").values()]
print("buy list now includes the bolt's linen:", buy)
assert (2589, 10) in buy or any(b[0] == 2589 for b in buy)
print("mail:", L("MAILMSG"))
assert "2 auctions sold" in L("MAILMSG")

# --- reload button: reloads only when it's safe
lua.execute("""
RELOADS = 0
ReloadUI = function() RELOADS = RELOADS + 1 end
FlipForever.Trader:Stop()
COMBAT = true;  FlipForever:ReloadForSync()   -- in combat: refused
COMBAT = false; FlipForever.Scan.busy = "replicate"; FlipForever:ReloadForSync()  -- scan running: refused
FlipForever.Scan.busy = nil; FlipForever:ReloadForSync()    -- safe: reloads
""")
print("reload button: reloads only when safe ->", L("RELOADS"))
assert L("RELOADS") == 1

# --- Beta 3: scan finished -> alert, flashing Reload, autopilot paused until reload
lua.execute("""
FlipForeverDB.settings.reloadAfterScan = nil
FlipForever.needReload = nil
FlipForever.Trader:Stop()
FlipForever.Auto:SetEnabled(true)
FlipForever.Auto.lastExternal = 0
FlipForever.Auto.scanBlocked = false
FlipForever.Auto.nextScan = 0
FlipForeverDB.lastReplicate = 0
AucAdvancedData = nil
REPL = { {name="Silk Cloth", id=4306, count=20, buyout=20*900} }
ALERTS = {}
RunTickers()                                  -- autopilot starts the scan
Fire("REPLICATE_ITEM_LIST_UPDATE")
for i = 1, 6 do RunTickers() end
RunTimers(5)
RunTickers()                                  -- after the scan
PAUSED_PHASE = FlipForever.Auto.phase
PAUSED_TRADER = FlipForever.Trader.state
RELOAD_TEXT = FlipForever.UI.reloadButton and FlipForever.UI.reloadButton.text
SCAN_ALERT = false
for _, a in ipairs(ALERTS) do if a:find("Scan saved") then SCAN_ALERT = true end end
FlipForever.Auto:SetEnabled(false)
FlipForever.needReload = nil
""")
print("after scan: phase", L("PAUSED_PHASE"), "| trader", L("PAUSED_TRADER"), "| alert:", L("SCAN_ALERT"), "| reload button:", L("RELOAD_TEXT"))
assert L("PAUSED_PHASE") == "needreload" and L("PAUSED_TRADER") == "idle" and L("SCAN_ALERT") is True
assert "RELOAD" in (L("RELOAD_TEXT") or "")

# --- Beta 3: one-key targeting + tank mode
lua.execute("""
COMBAT = false
UnitName = function(u) if u == "targettarget" then return "Healbot" end if u == "target" then return TARGET and TARGET.name end return "Tester" end
UnitClass = function() return "Warrior", "WARRIOR" end
FlipForever.Advisor:CharStore().build = "prot"
KNOWN = { "Battle Shout", "Thunder Clap", "Sunder Armor", "Heroic Strike", "Taunt" }
TARGET = { name = "Kobold", ctype = "Humanoid", level = 22 }
FlipForeverDB.settings.combatTank = nil
FlipForeverDB.settings.combatTarget = nil
if not FlipForever.Combat:Enabled() then FlipForever.Combat:Toggle() end
FlipForever.Combat:Rebuild()
CB = FlipForeverCombatButton
TANK1 = CB:GetAttribute("step1")
TANK2 = CB:GetAttribute("step2")
IS_TANK = FlipForever.Combat:IsTank()
-- damage build: no /assist, still auto-target
UnitClass = function() return "Mage", "MAGE" end
FlipForever.Advisor:CharStore().build = "frost"
KNOWN = { "Frostbolt", "Fire Blast" }
FlipForever.Combat:Rebuild()
DPS1 = CB:GetAttribute("step1")
-- auto-target off: plain casts
FlipForever.Combat:SetAutoTarget(false)
OFF1 = CB:GetAttribute("step1")
FlipForever.Combat:SetAutoTarget(true)
-- the enemy is hitting an ally -> warning line
UnitExists = function(u) return u == "player" or u == "target" or u == "targettarget" end
UnitIsFriend = function(a, b) return b == "targettarget" end
UnitIsUnit = function(a, b) return false end
FlipForever.Combat:UpdateIcons()
HINT = FlipForeverCombatBar and true
""")
print("tank step1:", repr(L("TANK1")), "| step2:", L("TANK2"), "| tank detected:", L("IS_TANK"))
assert L("TANK1").startswith("/assist [help,nodead]\n/targetenemy [noharm][dead]\n/startattack\n") and L("TANK2").endswith("/cast Taunt")
assert L("IS_TANK") is True
print("dps step1:", repr(L("DPS1")), "| auto-target off:", repr(L("OFF1")))
assert L("DPS1") == "/targetenemy [noharm][dead]\n/cast Frostbolt" and L("OFF1") == "/cast Frostbolt"
print("ally warning:", L("FlipForever.Combat:AllyUnderAttack()"))
assert L("FlipForever.Combat:AllyUnderAttack()") == "Healbot"
lua.execute("FlipForever.Combat:Toggle()")

# --- Beta 4: the in-game planner gives the same list as the app (same demo data, same learning)
import json as _json  # noqa: E402
import sqlite3 as _sqlite3  # noqa: E402
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "app"))
from flipforever import demo as _demo, engine as _engine, luaio as _luaio, store as _store  # noqa: E402

_con = _sqlite3.connect(":memory:")
_con.row_factory = _sqlite3.Row
_con.executescript(_store.SCHEMA)
_realm = _demo.create_demo(_con)
NOW = _con.execute("SELECT MAX(t) FROM scans").fetchone()[0] + 600
_set = _store.Settings()
_set.budget_gold = 50.0
_model = _engine.market_model(_con, _realm, NOW)
_all = _engine.build_ledger(_con, _realm)
_mine = _engine.build_ledger(_con, _realm, "Demochar")
_learned = _engine.learn(_con, _realm, _set, _all, _model, commit_tuning=False)
_names = {iid: f"item {iid}" for iid in _model}
_deals = _engine.recommend(_set, _model, _learned, _all, _names, now=NOW, holder=_mine)
_py, _ = _engine.build_plan(_set, _deals, _model, _learned, _mine, _names, _realm)
# Deals page filters
_regular = [d for d in _deals if not d.starter]
_fast = _engine.filter_deals(_deals, fast_only=True)
_pos = sorted(d.profit_unit for d in _regular if d.profit_unit > 0)
_minp = _pos[len(_pos) // 2] if _pos else 1
_rich = _engine.filter_deals(_deals, min_profit=_minp)
print("deal filters:", len(_deals), "all |", len(_fast), "fast |", len(_rich), f"profit >= {_minp}")
assert all(d.fast or d.starter for d in _fast) and len(_fast) == sum(1 for d in _deals if d.fast or d.starter)
assert all(d.profit_unit >= _minp or d.starter for d in _rich) and len(_rich) < len(_deals) or not _regular
assert _engine.filter_deals(_deals, text=_deals[0].name.upper()) and not _engine.filter_deals(_deals, text="zzzz-nothing")
# the context goes through plans.json like in the app (number keys become strings)
_ctx = _json.loads(_json.dumps(_engine.planner_context(_set, _learned, _all, _mine)))
_scans = []
for (_t,) in _con.execute("SELECT DISTINCT t FROM scans WHERE realm=? ORDER BY t", (_realm,)):
    rows = _con.execute("SELECT id, min, p25, qty, n FROM prices WHERE realm=? AND t=?", (_realm, _t)).fetchall()
    _scans.append({"t": _t, "src": "full", "n": len(rows), "d": ";".join(":".join(str(v) for v in r) for r in rows)})
_held = [s for s in _py["sell"] if s.get("held")]
lua.execute("PY_CTX = " + _luaio.to_lua(_ctx) + "\nPY_SCANS = " + _luaio.to_lua(_scans) + "\nPY_HELD = " + _luaio.to_lua(_held))
lua.execute(f"""
LUA_PLAN = FlipForever.Planner:Compute(PY_SCANS, PY_CTX, {NOW}, function(id) return "item " .. id end, PY_HELD, {{}})
""")
_lp = L("LUA_PLAN")
_lbuy = [dict(_lp.buy[i]) for i in range(1, len(_lp.buy) + 1)]
print("planner: app", [(b["id"], b["max"], b["qty"]) for b in _py["buy"]])
print("planner: game", [(b["id"], b["max"], b["qty"]) for b in _lbuy])
assert len(_py["buy"]) > 0, "demo data should give something to buy"
assert [b["id"] for b in _py["buy"]] == [b["id"] for b in _lbuy], "in-game planner picked different items"
for a, b in zip(_py["buy"], _lbuy):
    assert abs(a["max"] - b["max"]) <= max(1, a["max"] * 0.01), (a, b)
    assert a["qty"] == b["qty"], (a, b)
assert _lp.budget == _py["budget"] and len(_lp.sell) == len(_py["sell"])
print("in-game planner matches the app:", len(_lbuy), "buys,", len(_lp.sell), "sells")
# scans are parsed once: a second rebuild parses nothing, a new scan only itself
lua.execute(f"""
local P = FlipForever.Planner
local c0 = P.parseCount
P:MarketModel(PY_SCANS, {NOW})
PARSE_AGAIN = P.parseCount - c0
PY_SCANS[#PY_SCANS + 1] = {{ t = {NOW} - 60, src = "full", n = 1, d = "2589:40:45:100:10" }}
c0 = P.parseCount
P:MarketModel(PY_SCANS, {NOW})
PARSE_NEW = P.parseCount - c0
table.remove(PY_SCANS)
""")
print("re-parsed scans on rebuild:", L("PARSE_AGAIN"), "| after one new scan:", L("PARSE_NEW"))
assert L("PARSE_AGAIN") == 0 and L("PARSE_NEW") == 1

# --- Beta 4: after a scan the list is rebuilt in game; no reload, autopilot keeps going
lua.execute(f"""
FlipForever_Plan = nil
FlipForever_Plans = {{ ["Tester @ Testrealm - Horde"] = {{ generated = 1, budget = 1, buy = {{}}, sell = {{}}, ctx = PY_CTX }} }}
FlipForeverDB.settings.livePlanning = nil
FlipForeverDB.settings.reloadAfterScan = nil
local db = FlipForever:DB()
for _, s in ipairs(PY_SCANS) do db.scans[#db.scans + 1] = s end
OLD_NOW = NOW; NOW = {NOW}
ALERTS = {{}}
FlipForever.needReload = nil
FlipForever:ScanFinished(5)
LIVE_ALERT = false
for _, a in ipairs(ALERTS) do if a:find("Shopping list updated") then LIVE_ALERT = true end end
LIVE = FlipForever:Plan()
""")
print("after scan (live):", L("LIVE.live"), "| buys", L("#LIVE.buy"), "| needReload", L("FlipForever.needReload"), "| alert", L("LIVE_ALERT"))
assert L("LIVE.live") is True and L("FlipForever.needReload") is None and L("LIVE_ALERT") is True
assert L("#LIVE.buy") >= len(_py["buy"])  # the test DB also holds scans from earlier test steps
# 2.3.0: tooltips show how fast an item sells
_tid = _py["buy"][0]["id"]
lua.execute(f"""
FlipForeverDB.settings.tooltips = nil
TIP = {{}}
for _, l in ipairs(FlipForever.Tooltip:Lines({_tid})) do TIP[#TIP + 1] = l[1] .. " = " .. l[2] end
TIP = table.concat(TIP, " | ")
""")
print("tooltip:", L("TIP"))
assert "sells on the AH = ~" in L("TIP") and "/day" in L("TIP")
assert abs(L(f"FlipForever.Planner:SellsPerDay({_tid})") - _model[_tid].vol_day) < 1e-6
# a newer list from the app wins again
lua.execute("FlipForever_Plans['Tester @ Testrealm - Horde'].generated = LIVE.generated + 1")
assert L("FlipForever:Plan().live") is None
lua.execute("FlipForever.livePlan = nil; FlipForeverDB.settings.livePlanning = false; NOW = OLD_NOW")

# --- 2.4.0: Advisor names your best farming zone (measured gold/hour)
lua.execute("""
local ns = FlipForever.gatherNS
GZ = ns ~= nil and not ns.skipGather
local oldDB = ns and ns.db
if GZ then
  ns.db = ns.db or { nodes = {}, zoneStats = {} }
  OLD_CMAP = C_Map
  C_Map = { GetMapInfo = function(id) return { name = id == 1411 and "Durotar" or "Elsewhere" } end }
  PROFS = { 1 }
  PROFS_INFO = { { "Mining", 120 } }
  ns.db.zoneStats = { [1411] = { active = 1200, value = 300000, nodes = 25 }, [1412] = { active = 300, value = 900000, nodes = 4 } }
  FlipForever.Advisor:Refresh()
  GATHERSTEP = nil
  ALLWHY = true
  for _, r in ipairs(FlipForever.Advisor:Compute()) do
    if r.text:find("farming") then GATHERSTEP = r.text GATHERWHY = r.why end
    if not r.why or r.why == "" then ALLWHY = false end
  end
  ns.db.zoneStats = {}
  ns.db = oldDB
  C_Map = OLD_CMAP
  PROFS = {}
end
""")
if L("GZ"):
    print("advisor gather step:", L("GATHERSTEP"))
    print("why:", L("GATHERWHY"), "| every step explained:", L("ALLWHY"))
    assert L("ALLWHY") is True and "your own gathering" in L("GATHERWHY")
    assert L("GATHERSTEP") and "Best farming zone so far" in L("GATHERSTEP") and "Durotar" in L("GATHERSTEP") and "about 90g" in L("GATHERSTEP")
else:
    print("advisor gather step: gathering module not active in this mock - skipped")

# --- 2.4.0: smarter undercut - a tiny dumped lot isn't the market
lua.execute("""
local T = FlipForever.Trader
A1, I1 = T:UndercutAnchor({ {unitPrice=40, quantity=1}, {unitPrice=100, quantity=50}, {unitPrice=105, quantity=80} })
A2, I2 = T:UndercutAnchor({ {unitPrice=90, quantity=40}, {unitPrice=100, quantity=50} })        -- normal market
A3, I3 = T:UndercutAnchor({ {unitPrice=40, quantity=30}, {unitPrice=100, quantity=50} })        -- big cheap lot = real
A4, I4 = T:UndercutAnchor({ {unitPrice=50, quantity=1, containsOwnerItem=true}, {unitPrice=100, quantity=5} }) -- own lot
A5 = T:UndercutAnchor({ {unitPrice=30, quantity=1} })                                            -- only one listing
""")
print("undercut anchors:", (L("A1"), L("I1")), (L("A2"), L("I2")), (L("A3"), L("I3")), (L("A4"), L("I4")), L("A5"))
assert (L("A1"), L("I1")) == (100, 40) and (L("A2"), L("I2")) == (90, None) and (L("A3"), L("I3")) == (40, None)
assert (L("A4"), L("I4")) == (100, None) and L("A5") == 30

# --- combat helper learns from fights, per class / build / level band
lua.execute("""
local L = FlipForever.CombatLearn
FlipForeverDB.combatLearn = nil
FlipForeverDB.settings.combatLearn, FlipForeverDB.settings.combatTips = nil, nil
L.Key = function() return "MAGE:test:11-39" end
local base = { "Frostbolt", "Fire Blast", "Frost Nova", "Arcane Explosion" }
-- every version gets its fights first, the guide's order included
local seen = {}
local function fightWith(variantSteps, dur, kill, died, hpLost)
  L:Apply(base)
  local name = L.current.variant
  seen[name] = (seen[name] or 0) + 1
  L:StartFight(100)
  L.fight.hp0, L.fight.hpMin = 1, 1 - (hpLost or 0)
  L:OnCast("Frostbolt", 101)
  L:OnCast("Fire Blast", 102)
  return L:EndFight(100 + dur, kill, died), name
end
L.lastTip = time()           -- no notes during the warm-up
for i = 1, 40 do
  -- "swap1" (Fire Blast first) kills fastest in this test
  local name = L.current and L.current.variant
  L:Apply(base)
  name = L.current.variant
  local dur = (name == "swap1") and 6 or 10
  L:StartFight(100)
  L:OnCast("Frostbolt", 101, true)      -- cast by the helper
  L:EndFight(100 + dur, true, false)
end
local vs = L:Store().bases[table.concat(base, ">")].variants
-- a fight you did by hand teaches the helper nothing
L:Apply(base)
local manualVariant = L.current.variant
local before = vs[manualVariant] and vs[manualVariant].n or 0
L:StartFight(100)
L:OnCast("Frostbolt", 101, false) L:OnCast("Fire Blast", 102, false) L:OnCast("Frostbolt", 103, true)
local mrec = L:EndFight(110, true, false)
LEARN_MANUAL = tostring(mrec.helper) .. ":" .. ((vs[manualVariant] and vs[manualVariant].n or 0) - before)
-- a press of the helper's button marks the next cast as the helper's
L:OnHelperPress(50)
LEARN_PRESS = tostring(L:IsHelperCast(50.3)) .. "," .. tostring(L:IsHelperCast(51))
LEARN_COUNTS = (vs.base and vs.base.n or 0) .. "/" .. (vs.swap1 and vs.swap1.n or 0) .. "/" .. (vs.swap2 and vs.swap2.n or 0) .. "/" .. (vs.swap3 and vs.swap3.n or 0)
-- settled: the best version is used (no random pick)
local oldRandom = math.random
math.random = function() return 0.99 end
local picked = L:Apply(base)
math.random = oldRandom
LEARN_PICK = L.current.variant .. ":" .. table.concat(picked, ",")
-- a spell that keeps failing for lack of mana is tried later in the order
local st = L:Store().spells
st["Frost Nova"] = { cast = 4, fail = 8, power = 8 }
local variants = L:Variants(base, L:Store())
LEARN_LATER = variants["later:Frost Nova"] and table.concat(variants["later:Frost Nova"], ",") or "none"
-- the order from written guides is one more version (known spells only, no big cooldowns left out by the helper)
local oldKnown = FlipForever.Advisor.KnownSpells
FlipForever.Advisor.KnownSpells = function() return { ["Fireball"] = true, ["Fire Blast"] = true, ["Scorch"] = true, ["Combustion"] = true } end
local fv = L:Variants({ "Fireball", "Fireball", "Fire Blast" }, L:Store(), "MAGE:fire:40-60")
LEARN_GUIDE = fv.guide and table.concat(fv.guide, ",") or "none"
FlipForeverDB.settings.combatTutorial = false
fv = L:Variants({ "Fireball", "Fireball", "Fire Blast" }, L:Store(), "MAGE:fire:40-60")
LEARN_GUIDE = LEARN_GUIDE .. "|" .. tostring(fv.guide == nil)
FlipForeverDB.settings.combatTutorial = nil
FlipForever.Advisor.KnownSpells = oldKnown
-- what to do better after a fight
L:StartFight(200)
L:OnCast("Frostbolt", 201)
local rec, tip = L:EndFight(215, true, false)        -- nothing cast for 14 s: counted as 5 s of waiting (the end of a fight is capped)
TIP_IDLE = tip
L:StartFight(300)
local rec2, tip2 = L:EndFight(310, false, true)
TIP_DIED = tip2
L:StartFight(400)
L:OnCast("Frostbolt", 400.5)
L.lastFailed = nil
L:OnFail("Fireball", "range") L:OnFail("Fireball", "range") L:OnFail("Fireball", "range")
L:OnCast("Frostbolt", 402) L:OnCast("Frostbolt", 404)
local rec3, tip3 = L:EndFight(405, true, false)
TIP_RANGE = tip3
L:StartFight(500)
local short = L:EndFight(501.5, true, false)
SHORT_SKIPPED = short == nil
printed = {}
L:Report()
LEARN_REPORT = table.concat(printed, " || ")
-- learning switched off: the guide's order stays
FlipForeverDB.settings.combatLearn = false
LEARN_OFF = table.concat(L:Apply(base), ",")
FlipForeverDB.settings.combatLearn = nil
FlipForeverDB.combatLearn = nil
L.Key = nil
""")
print("combat learning:", L("LEARN_COUNTS"), "| pick", L("LEARN_PICK"), "| later", L("LEARN_LATER"))
print("  tips:", L("TIP_IDLE"), "|", L("TIP_DIED"), "|", L("TIP_RANGE"))
print("  report:", L("LEARN_REPORT")[:300])
_counts = [int(x) for x in L("LEARN_COUNTS").split("/")]
assert all(c >= 6 for c in _counts), L("LEARN_COUNTS")
assert L("LEARN_PICK") == "swap1:Fire Blast,Frostbolt,Frost Nova,Arcane Explosion", L("LEARN_PICK")
assert L("LEARN_GUIDE") == "Scorch,Fireball,Fire Blast,Fireball,Fireball|true", L("LEARN_GUIDE")
assert L("LEARN_LATER") == "Frostbolt,Fire Blast,Arcane Explosion,Frost Nova"
assert "waited 5 of 15 seconds" in L("TIP_IDLE") and "you died" in L("TIP_DIED") and "Fireball failed 3 times out of range" in L("TIP_RANGE")
assert L("SHORT_SKIPPED") is True and "recent fights: 44, kills: 43, deaths: 1" in L("LEARN_REPORT") and "40 of 44" in L("LEARN_REPORT") and "Orders being compared" in L("LEARN_REPORT")
assert L("LEARN_OFF") == "Frostbolt,Fire Blast,Frost Nova,Arcane Explosion"
assert L("LEARN_MANUAL") == "false:0" and L("LEARN_PRESS") == "true,false", (L("LEARN_MANUAL"), L("LEARN_PRESS"))

# --- combat guide: emergency key, interrupts, big cooldowns only for elites (WoW: Forever class guides)
lua.execute("""
local GD = FlipForever.CombatGuide
local AD = FlipForever.Advisor
local oldPlayer, oldKnown = AD.Player, AD.KnownSpells
AD.Player = function() return { class = "WARRIOR", level = 40 } end
local KNOWN = { ["Shield Wall"] = true, ["Retaliation"] = true, ["Pummel"] = true, ["Hamstring"] = true,
                ["Recklessness"] = true, ["Mortal Strike"] = true, ["Heroic Strike"] = true }
AD.KnownSpells = function() return KNOWN end
FlipForeverDB.settings.combatGuide = nil
local steps = { "Recklessness", "Mortal Strike", "Heroic Strike" }
GUIDE_NORMAL = table.concat(GD:FilterSteps(steps, { class = "normal", level = 40 }), ",")
GUIDE_ELITE = table.concat(GD:FilterSteps(steps, { class = "elite", level = 40 }), ",")
GUIDE_HIGHER = table.concat(GD:FilterSteps(steps, { class = "normal", level = 44 }), ",")
-- the emergency macro: defensives in the guide's order, then the best healthstone and potion carried
local oldCount = C_Item and C_Item.GetItemCount
C_Item = C_Item or {}
local BAG = { [9421] = 1, [858] = 3, [13446] = 0 }
C_Item.GetItemCount = function(id) return BAG[id] or 0 end
GUIDE_MACRO, GUIDE_FIRST = GD:EmergencyMacro()
-- advice during a fight
local oldLock, oldHealth, oldMax, oldCast = InCombatLockdown, UnitHealth, UnitHealthMax, UnitCastingInfo
InCombatLockdown = function() return true end
GD.emergencyFirst, GD.emergencyLabel, GD.emergencyKey = "Shield Wall", "Shield Wall", "SHIFT-+"
local HP = { player = 30, target = 100 }
UnitHealth = function(u) return HP[u] or 100 end
UnitHealthMax = function() return 100 end
HINT_LOW = GD:Hint()
HP.player = 90
UnitCastingInfo = function(u) if u == "target" then return "Heal", nil, nil, nil, nil, nil, nil, false end end
local oldExists, oldAttack = UnitExists, UnitCanAttack
UnitExists = function() return true end
UnitCanAttack = function() return true end
HINT_KICK = GD:Hint()
UnitCastingInfo = function() return nil end
UnitChannelInfo = UnitChannelInfo or function() return nil end
HINT_NONE = GD:Hint()
FlipForeverDB.settings.combatGuide = false
HINT_OFF = GD:Hint()
GUIDE_OFF = table.concat(GD:FilterSteps(steps, { class = "normal", level = 40 }), ",")
FlipForeverDB.settings.combatGuide = nil
InCombatLockdown, UnitHealth, UnitHealthMax, UnitCastingInfo = oldLock, oldHealth, oldMax, oldCast
UnitExists, UnitCanAttack = oldExists, oldAttack
C_Item.GetItemCount = oldCount
AD.Player, AD.KnownSpells = oldPlayer, oldKnown
GD.emergencyFirst, GD.emergencyLabel, GD.emergencyKey = nil, nil, nil
""")
print("combat guide:", L("GUIDE_NORMAL"), "|", L("GUIDE_ELITE"), "|", L("GUIDE_HIGHER"), "| macro", repr(L("GUIDE_MACRO")))
print("  hints:", L("HINT_LOW"), "|", L("HINT_KICK"), "|", L("HINT_NONE"), "|", L("HINT_OFF"))
assert L("GUIDE_NORMAL") == "Mortal Strike,Heroic Strike" and L("GUIDE_ELITE") == "Recklessness,Mortal Strike,Heroic Strike"
assert L("GUIDE_HIGHER") == "Recklessness,Mortal Strike,Heroic Strike" and L("GUIDE_OFF") == "Recklessness,Mortal Strike,Heroic Strike"
assert L("GUIDE_MACRO") == "/cast Shield Wall\n/cast Retaliation\n/use item:9421\n/use item:858" and L("GUIDE_FIRST") == "Shield Wall"
assert "Low health" in L("HINT_LOW") and "SHIFT-+" in L("HINT_LOW") and "Interrupt Heal: Pummel" in L("HINT_KICK")
assert L("HINT_NONE") is None and L("HINT_OFF") is None

# --- shared combat learning: what all players learned gives the helper a head start
lua.execute("""
local L = FlipForever.CombatLearn
FlipForeverDB.combatLearn = nil
L.Key = function() return "MAGE:test:11-39" end
local base = { "Frostbolt", "Fire Blast", "Frost Nova" }
local sig = table.concat(base, ">")
-- everyone found "swap1" faster; nothing learned locally yet
FlipForever.COMBAT_SHARED = { ["MAGE:test:11-39"] = { [sig] = {
  base = { n = 200, kills = 200, time = 2000, deaths = 0, hp = 40 },
  swap1 = { n = 200, kills = 200, time = 1400, deaths = 0, hp = 40 },
  swap2 = { n = 200, kills = 200, time = 2200, deaths = 0, hp = 40 } } } }
local oldRandom = math.random
math.random = function() return 0.99 end
SHARED_PICK = table.concat(L:Apply(base), ",") .. ":" .. L.current.variant
math.random = oldRandom
FlipForever.COMBAT_SHARED = {}
NO_SHARED = L.current and L:Apply(base) and L.current.variant
FlipForeverDB.combatLearn = nil
L.Key = nil
-- the warning about collecting data is shown once
FlipForeverDB.settings.combatShareWarned = nil
printed = {}
WARN1 = L:WarnOnce()
WARN2 = L:WarnOnce()
WARN_TEXT = printed[1]
""")
print("shared learning:", L("SHARED_PICK"), "| without:", L("NO_SHARED"), "| warning once:", L("WARN1"), L("WARN2"))
assert L("SHARED_PICK") == "Fire Blast,Frostbolt,Frost Nova:swap1" and L("NO_SHARED") == "base"
assert L("WARN1") is True and L("WARN2") is False and "anonymous combat data" in L("WARN_TEXT") and "Settings, Features" in L("WARN_TEXT")

# the app side: anonymous summary, one message per entry, both switches respected, nothing sent twice
from flipforever import share as _share  # noqa: E402
_learn = {"MAGE:frost:11-39": {"spells": {"Frostbolt": {"cast": 3}}, "fights": [{"dur": 9}],
                                "bases": {"Frostbolt>Fire Blast": {"variants": {"base": {"n": 6, "kills": 6, "time": 54.25, "hp": 1.2},
                                                                              "swap1": {"n": 0}}}}},
          "bad key": {"bases": {}}}
_sum = _share.summarize(_learn)
_msgs = _share.messages(_sum, "abc123")
print("share summary:", _sum, "|", _msgs)
assert _sum == {"MAGE:frost:11-39": {"Frostbolt>Fire Blast": {"base": {"n": 6, "kills": 6, "time": 54.2, "deaths": 0, "hp": 1.2}}}}
assert len(_msgs) == 1 and '"i":"abc123"' in _msgs[0] and "Tester" not in _msgs[0] and _msgs[0].startswith("```json")


class _ShareSettings(_store.Settings):
    def save(self):
        pass


_ss = _ShareSettings()
_posted = []
_n1 = _share.send(_ss, _learn, True, poster=lambda m: _posted.append(m) or True, now=1000000)
_n2 = _share.send(_ss, _learn, True, poster=lambda m: _posted.append(m) or True, now=1000000 + 30 * 3600)   # unchanged
_ss.share_digest = ""
_n3 = _share.send(_ss, _learn, False, poster=lambda m: _posted.append(m) or True, now=1000000 + 60 * 3600)  # off in game
_ss.share_combat = False
_n4 = _share.send(_ss, _learn, True, poster=lambda m: _posted.append(m) or True, now=1000000 + 90 * 3600)   # off in the app
print("share sends:", _n1, _n2, _n3, _n4)
assert (_n1, _n2, _n3, _n4) == (1, 0, 0, 0) and len(_posted) == 1

# the release build merges the summaries: newest per install, then summed; junk is ignored
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "tools"))
import merge_combat_learning as _mcl  # noqa: E402
_dump = ("FlipForever combat data BOT\n" + _msgs[0] + "\n" + _msgs[0].replace('"n":6', '"n":7').replace('"kills":6', '"kills":7')
         + "\n" + _msgs[0].replace("abc123", "zzz999") + '\n{"f":1,"i":"x","k":"<script>","s":"a","v":{"base":{"n":1}}}'
         + '\n{"f":1,"i":"y","k":"MAGE:frost:11-39","s":"Frostbolt","v":{"base":{"n":5,"kills":9}}}')
_parsed = _mcl.parse(_dump)
_total = _mcl.merge(_parsed, {})
print("merged:", len(_parsed), _total)
assert len(_parsed) == 3 and _total["MAGE:frost:11-39"]["Frostbolt>Fire Blast"]["base"]["n"] == 13
assert 'FF.COMBAT_SHARED = {' in _mcl.to_lua(_total) and '["base"] = { n = 13' in _mcl.to_lua(_total)

# --- undercut fix: cancel and repost only where it pays after the deposit
lua.execute("""
local T = FlipForever.Trader
local u = { mine = 1000, qty = 10, timeLeft = 20 * 3600 }
local function d(...) local a, w, p = T:UndercutDecision(...) return tostring(a) .. ":" .. w .. ":" .. tostring(p) end
UD = table.concat({
  d(u, 900, 50, 10, 500, 0.05, 100, 0),            -- 50 cheaper, ~8 sell before yours ends: act
  d(u, 1000, 50, 10, 500, 0.05, 100, 0),           -- not undercut
  d(u, nil, 0, 10, 500, 0.05, 100, 0),             -- no competition left
  d({ mine = 1000, qty = 10, timeLeft = 1800 }, 900, 50, 10, 500, 0.05, 100, 0),   -- ends in 30 min
  d(u, 900, 50, 10, 950, 0.05, 100, 0),            -- below the floor
  d(u, 900, 5, 10, 500, 0.05, 100, 0),             -- the 5 cheaper ones sell first
  d(u, 900, 50, 10, 500, 0.05, 3000, 0),           -- deposit eats the repost
  d(u, 900, 50, nil, 500, 0.05, 100, 3000),        -- cancel fee too high
}, " ")
-- the full flow: live search, one press to cancel, the item comes back for reposting
local AHT = C_AuctionHouse
local cancelled
local saved = {}
local patch = {
  CancelAuction = function(id) cancelled = id end,
  CalculateCommodityDeposit = function() return 50 end,
  GetCancelCost = function() return 0 end,
  CanCancelAuction = function() return true end,
}
for k, v in pairs(patch) do saved[k] = AHT[k] AHT[k] = v end
FlipForeverDB.settings.undercutFix = nil
FlipForever.Auctions.undercut = { { id = 2589, name = "Linen Cloth", mine = 1000, qty = 20, timeLeft = 40000, auctionID = 77 },
                                  { id = 2592, name = "Wool Cloth", mine = 500, qty = 2, timeLeft = 40000, auctionID = 78 } }
T.state, T.mode = "idle", nil
local realSearch = T.Search
T.Search = function(self, id) self.searchID = id self.state = "searching" end
T:Primary()
UF_SEARCH1 = T.searchID
T.isCommodity = true
T:OnResults({ { unitPrice = 900, quantity = 200 }, { unitPrice = 1000, quantity = 20, containsOwnerItem = true } })
UF_STATE1, UF_BTN = T.state, T:ButtonText()
T:Primary()
UF_CANCELLED, UF_STATE2 = cancelled, T.state
Fire("AUCTION_CANCELED", 77)
UF_SEARCH2 = T.searchID
T:OnResults({ { unitPrice = 499, quantity = 1 }, { unitPrice = 500, quantity = 2, containsOwnerItem = true } })  -- 1 cheaper: sells first
UF_STATE3 = T.state
UF_REPOST = T:Reposts()[2589] and T:Reposts()[2589].price
local hasRepost = false
for _, s in ipairs(T:BuildSellList()) do if s.id == 2589 and s.repost then hasRepost = true end end
UF_INLIST = hasRepost
T:Reposts()[2589] = nil
T.Search = realSearch
for k in pairs(patch) do AHT[k] = saved[k] end
""")
print("undercut decisions:", L("UD"))
assert L("UD") == "true:repost:899 false:cheapest:nil false:cheapest:nil false:ends:nil false:floor:899 false:sells:899 false:deposit:899 false:deposit:899", L("UD")
print("undercut flow:", L("UF_SEARCH1"), L("UF_STATE1"), L("UF_BTN"), "| cancelled", L("UF_CANCELLED"), L("UF_STATE2"),
      "| next", L("UF_SEARCH2"), L("UF_STATE3"), "| repost at", L("UF_REPOST"), L("UF_INLIST"))
assert L("UF_SEARCH1") == 2589 and L("UF_STATE1") == "ready_cancel" and L("UF_BTN") == "CANCEL 20 x Linen Cloth"
assert L("UF_CANCELLED") == 77 and L("UF_STATE2") == "cancelling" and L("UF_SEARCH2") == 2592
assert L("UF_STATE3") == "idle" and L("UF_REPOST") == 899 and L("UF_INLIST") is True

# --- 2.4.0: tabbed FlipForever window, shopping-list view with Skip
lua.execute("""
FlipForever_Plan = nil
FlipForever_Plans = { ["Tester @ Testrealm - Horde"] = { generated = 77, budget = 100000,
  buy = { {id=4306, name="Silk Cloth", max=999999, qty=5}, {id=2589, name="Linen Cloth", max=1, qty=3}, {id=2592, name="Wool Cloth", gap=0.25, max=500, qty=2} },
  sell = {} } }
FlipForever.Hub:Show()
TAB1 = FlipForever.Hub.tab
FlipForever.Hub:Show("list")
TAB2 = FlipForever.Hub.tab
ROWS = FlipForever.Hub:ListRows()
FlipForever.Hub:SetSkipped(2589, true)
ROWS2 = FlipForever.Hub:ListRows()
REM_SKIPPED = FlipForever.Trader:Remaining({id=2589, qty=3})
REM_OK = FlipForever.Trader:Remaining({id=4306, qty=5})
FlipForever.Hub:SetSkipped(2589, false)
REM_BACK = FlipForever.Trader:Remaining({id=2589, qty=3})
FlipForever.Hub:SelectTab("settings")
""")
_rows = [dict(L("ROWS")[i]) for i in range(1, 4)]
print("hub tabs:", L("TAB1"), "->", L("TAB2"), "| rows:", [(r["name"], r["status"], r.get("now")) for r in _rows])
assert L("TAB1") == "overview" and L("TAB2") == "list"
_byname = {r["name"]: r for r in _rows}
assert _rows[0]["name"] == "Silk Cloth" and _rows[0]["status"] == "deal" and _byname["Wool Cloth"]["live"] is True
assert _byname["Silk Cloth"]["profit"] is not None
assert _byname["Linen Cloth"]["status"] == "watching"
assert L("ROWS2")[3].status == "skipped" and L("ROWS2")[3].name == "Linen Cloth" and L("REM_SKIPPED") == 0 and L("REM_OK") == 5 and L("REM_BACK") == 3
print("skip: skipped item not bought, back after unticking")

# --- 2.5.0: crafting profit finder (uses the Tailoring recipes captured above)
lua.execute("""
local FF = FlipForever
local oldPrice, oldSpeed = FF.PriceOf, FF.Planner.SellsPerDay
local PRICES = { [2589] = 40, [2570] = 400, [4307] = 900 }
FF.PriceOf = function(_, id) return PRICES[id] end
FF.Planner.SellsPerDay = function(_, id) return ({ [2570] = 6, [4307] = 1 })[id] end
BAGCOUNT[2996] = 0
PROFIT = FF.Professions:ProfitList()
PBUY = FF.Professions:ProfitBuyList(nil, 1)
FF.Professions:SetMode("profit")
FF.Professions:Show()
FF.Professions:QueueProfitMats()
PENDING = FF.Professions.pendingMats or (FF.Trader.custom and FF.Trader.list)
FF.Professions.pendingMats = nil
FF.Trader:Stop()
FF.Professions:SetMode("skill")
FF.PriceOf, FF.Planner.SellsPerDay = oldPrice, oldSpeed
""")
_p = [dict(L("PROFIT")[i]) for i in range(1, len(L("PROFIT")) + 1)]
print("profitable crafts:", [(e["recipe"].name, e["profit"], e["crafts"]) for e in _p])
assert [e["recipe"].name for e in _p] == ["Linen Cloak"]          # gloves not learned, shirt has no price
assert _p[0]["cost"] == 120 and _p[0]["profit"] == 254 and _p[0]["crafts"] == 6
_b = [dict(L("PBUY")[i]) for i in range(1, len(L("PBUY")) + 1)]
print("mats to buy:", _b)
assert _b == [{"id": 2589, "qty": 8, "max": 50}] and L("PENDING") is not None

# --- 2.5.0: gear finder - affordable AH upgrades for the class and level
lua.execute("""
local FF = FlipForever
local oldModel, oldInfo, oldInstant = FF.Planner.Model, C_Item.GetItemInfo, C_Item.GetItemInfoInstant
FF.Planner.Model = function() return {
  [100] = { cur_min = 5000 },    -- mail chest, level 28: an upgrade
  [101] = { cur_min = 900000 },  -- the same, but too expensive
  [102] = { cur_min = 3000 },    -- cloth chest: wrong armor type for a warrior
  [103] = { cur_min = 2000 },    -- two-handed sword, level 25
  [104] = { cur_min = 2000 },    -- plate legs: warriors wear plate only from 40
  [105] = { cur_min = 1000 },    -- level 45 helm: too high
} end
local ITEMS = {
  [100] = { "Scaled Chestguard", 2, 28, "INVTYPE_CHEST", 4, 3, { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 8, RESISTANCE0_NAME = 200 } },
  [101] = { "Pricey Chestguard", 3, 28, "INVTYPE_CHEST", 4, 3, { ITEM_MOD_STRENGTH_SHORT = 30 } },
  [102] = { "Silk Robe", 2, 28, "INVTYPE_ROBE", 4, 1, { ITEM_MOD_INTELLECT_SHORT = 12 } },
  [103] = { "Heavy Claymore", 2, 25, "INVTYPE_2HWEAPON", 2, 8, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20, ITEM_MOD_STRENGTH_SHORT = 5 } },
  [104] = { "Plate Legguards", 2, 28, "INVTYPE_LEGS", 4, 4, { ITEM_MOD_STRENGTH_SHORT = 15 } },
  [105] = { "Mail Helm", 2, 45, "INVTYPE_HEAD", 4, 3, { ITEM_MOD_STRENGTH_SHORT = 15 } },
}
local EQUIPPED = { [5] = { ITEM_MOD_STRENGTH_SHORT = 3 }, [16] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 } }
C_Item.GetItemInfoInstant = function(id) local it = ITEMS[id] if it then return id, "", "", it[4], 0, it[5], it[6] end end
C_Item.GetItemInfo = function(id) local it = ITEMS[id] if it then return it[1], "link:" .. id, it[2], 30, it[3] end end
GetItemStats = function(link)
  local id = tonumber(link:match("link:(%d+)")) if id then return ITEMS[id][7] end
  local slot = tonumber(link:match("eq:(%d+)")) return slot and EQUIPPED[slot]
end
GetInventoryItemLink = function(_, slot) return EQUIPPED[slot] and ("eq:" .. slot) or nil end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitLevel = function() return 30 end
GetMoney = function() return 100000 end
FF.Advisor:CharStore().build = nil
FF.Gear:Search()
RunTimers(5)
GEAR = FF.Gear.results
GEARSTEP = FF.Gear:TopStep()
GEARDIFF = FF.Gear:StatDiffText(FF.Gear.results[2]) .. " || " .. FF.Gear:StatDiffText(FF.Gear.results[1])
FF.Advisor:Refresh()
local adv = FF.Advisor:CharStore().advisor
GEARSAVED = adv and adv.gear and adv.gear[1] and adv.gear[1].name
FF.Hub:Show("gear")
FF.Planner.Model, C_Item.GetItemInfo, C_Item.GetItemInfoInstant = oldModel, oldInfo, oldInstant
""")
_g = [dict(L("GEAR")[i]) for i in range(1, len(L("GEAR")) + 1)]
print("gear upgrades:", [(r["name"], round(r["gain"], 1), r["price"]) for r in _g], "| step:", L("GEARSTEP"))
assert [r["name"] for r in _g] == ["Heavy Claymore", "Scaled Chestguard"]
assert abs(_g[0]["gain"] - 35) < 0.01 and abs(_g[1]["gain"] - 15.8) < 0.01
assert "Heavy Claymore" in L("GEARSTEP") and L("GEARSAVED") == "Heavy Claymore"
print("gear stat gains:", L("GEARDIFF"))
assert "+7 Strength" in L("GEARDIFF") and "+8 Stamina" in L("GEARDIFF") and "+200 Armor" in L("GEARDIFF")
assert "+10.0 DPS" in L("GEARDIFF") and "+5 Strength" in L("GEARDIFF")

# --- 2.5.0: languages - every client language, chosen in the FlipForever window
lua.execute("""
local FF = FlipForever
GetLocale = function() return "frFR" end
FlipForeverDB.settings.language = nil
T_GAME = FF:T("Overview")                 -- follows the game client
FlipForeverDB.settings.language = "deDE"
T_DE = FF:T("Overview")
T_DE2 = FF:T("Show profitable crafts") .. "|" .. FF:T("Do this next:")
T_MISSING = FF:T("Some text not translated yet")
FlipForeverDB.settings.language = ""
FF.Hub:Show("settings")
FF.Hub:NextLanguage()
T_NEXT = FlipForeverDB.settings.language
N_LANGS = #FF.LANGUAGES
FlipForeverDB.settings.language = "enUS"
T_EN = FF:T("Overview")
FlipForeverDB.settings.language = nil
GetLocale = function() return "enUS" end
FF.needReload = nil
""")
print("languages:", L("N_LANGS"), "| game (frFR):", L("T_GAME"), "| de:", L("T_DE"), "| next after game language:", L("T_NEXT"))
assert L("N_LANGS") == 11 and L("T_GAME") == "Aperçu" and L("T_DE") == "Übersicht" and L("T_EN") == "Overview"
assert L("T_MISSING") == "Some text not translated yet" and L("T_NEXT") == "enUS"
assert L("T_DE2") == "Gewinnbringende Herstellungen|Als Nächstes:"

# --- 2.5.0: vendor flips, auto-sell at a merchant, vendor floor when posting
lua.execute("""
local FF = FlipForever
local oldInfo = C_Item.GetItemInfo
local VENDOR = { [900] = 100, [901] = 100, [902] = 1000 }
C_Item.GetItemInfo = function(id)
  if VENDOR[id] then return "Vendor item " .. id, "link", 1, 1, 1, "", "", 20, "", "", VENDOR[id] end
  return oldInfo(id)
end
local now = time()
FLIPS = FF.Planner:VendorFlips({
  [900] = { cur_min = 60, cur_qty = 12, cur_t = now },        -- 40c below vendor: flip
  [901] = { cur_min = 95, cur_qty = 50, cur_t = now },        -- only 5% below: not worth it
  [902] = { cur_min = 500, cur_qty = 3, cur_t = now - 9 * 3600 }, -- stale scan: skip
}, now, 15)
-- merchant: the flip in the bags gets sold, other items don't
local BAGS = { [0] = { [1] = { itemID = 900, stackCount = 12 }, [2] = { itemID = 4306, stackCount = 5 } } }
SOLDSLOTS = {}
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(bag) return BAGS[bag] and 2 or 0 end
C_Container.GetContainerItemInfo = function(bag, slot) return BAGS[bag] and BAGS[bag][slot] end
C_Container.UseContainerItem = function(bag, slot) SOLDSLOTS[#SOLDSLOTS + 1] = BAGS[bag][slot].itemID end
local oldCount = C_Item.GetItemCount
C_Item.GetItemCount = function(id) return id == 900 and 12 or 0 end
FF:DB().vendorFlips = { [900] = true, [777] = true }
Fire("MERCHANT_SHOW")
FORGOT777 = FF:DB().vendorFlips[777] == nil
C_Item.GetItemCount = oldCount
-- posting loot the AH values at under 1.5x its vendor price: held, told to vendor it
FlipForever_Plans = { ["Tester @ Testrealm - Horde"] = { generated = 5, budget = 1, buy = {}, sell = { { id = 902, floor = 1, normal = 1300, ceil = 3000 } } } }
FF.Trader:Stop()
FF.Trader.target = { id = 902, floor = 1, normal = 1300, ceil = 3000 }
FF.Trader.mode = "sell"
FF.Trader.NextSellTarget = function(self) VENDOR_HOLD = true end
VENDOR_HOLD = false
FF.Trader:EvaluateSell({ { unitPrice = 1200, quantity = 5 } })
FF.Trader.NextSellTarget = nil
FF.Trader:Stop()
C_Item.GetItemInfo = oldInfo
""")
_f = [dict(L("FLIPS")[i]) for i in range(1, len(L("FLIPS")) + 1)]
print("vendor flips:", [(e["id"], e["max"], e["qty"]) for e in _f], "| sold at merchant:", list(L("SOLDSLOTS").values()),
      "| held for vendor:", L("VENDOR_HOLD"))
assert [(e["id"], e["max"], e["qty"]) for e in _f] == [(900, 90, 12)]
assert list(L("SOLDSLOTS").values()) == [900] and L("FORGOT777") is True and L("VENDOR_HOLD") is True

# --- 2.5.0: exact skill-up chances learned from colour changes
lua.execute("""
local P = FlipForever.Professions
local oldBase, oldInfo = C_TradeSkillUI.GetBaseProfessionInfo, C_TradeSkillUI.GetRecipeInfo
SKILL, DIFF2 = 59, 0
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionName = "Tailoring", skillLevel = SKILL, maxSkillLevel = 150 } end
C_TradeSkillUI.GetRecipeInfo = function(id)
  local r = oldInfo(id)
  if id == 2 then r = { name = r.name, learned = true, relativeDifficulty = DIFF2 } end
  return r
end
FlipForeverDB.recipeThresholds = {}
local function read(skill, diff) SKILL, DIFF2 = skill, diff P:Capture() end
read(59, 0) read(60, 1)        -- turned yellow at 60
read(69, 1) read(70, 2)        -- turned green at 70
read(72, 2)
CH, EXACT = P:Chance({ id = 2, diff = 2 }, 72)
CH_UNKNOWN = P:Chance({ id = 3, diff = 1 }, 72)  -- never seen changing: colour average
read(80, 3)                   -- jump of 8 skill points: not trusted as exact
TH = FlipForeverDB.recipeThresholds[2]
C_TradeSkillUI.GetBaseProfessionInfo, C_TradeSkillUI.GetRecipeInfo = oldBase, oldInfo
""")
print("exact chance at 72:", L("CH"), L("EXACT"), "| unknown recipe:", L("CH_UNKNOWN"), "| thresholds:", dict(L("TH")))
assert abs(L("CH") - 0.4) < 1e-9 and L("EXACT") is True and L("CH_UNKNOWN") == 0.75
assert L("TH").yellow == 60 and L("TH").green == 70 and L("TH").grey is None and L("TH").greyMax == 80

# --- 2.5.0: combat helper level bands 1-10 / 11-39 / 40-60
lua.execute("""
local C, AD = FlipForever.Combat, FlipForever.Advisor
local oldLevel = UnitLevel
TARGET = nil
local function steps(class, build, level, spells)
  UnitClass = function() return class, class:upper() end
  UnitLevel = function() return level end
  AD:CharStore().build = build
  KNOWN = spells
  local s = C:BuildSteps()
  return table.concat(s, ",") .. " [" .. C.band .. "]"
end
HUNTER5 = steps("Hunter", nil, 5, { "Raptor Strike" })
PALA3 = steps("Paladin", nil, 3, { "Seal of Righteousness" })
ARMS20 = steps("Warrior", "arms", 20, { "Battle Shout", "Rend", "Heroic Strike", "Mortal Strike", "Whirlwind" })
ARMS50 = steps("Warrior", "arms", 50, { "Battle Shout", "Rend", "Heroic Strike", "Mortal Strike", "Whirlwind" })
FERAL50_NOCAT = steps("Druid", "feral", 50, { "Moonfire", "Wrath", "Starfire" })
UnitLevel = oldLevel
AD:CharStore().build = nil
""")
for k in ("HUNTER5", "PALA3", "ARMS20", "ARMS50", "FERAL50_NOCAT"):
    print(k, "->", L(k))
assert L("HUNTER5") == "Raptor Strike,Raptor Strike [1-10]"
assert L("PALA3") == "Seal of Righteousness,Seal of Righteousness [1-10]"
assert "Whirlwind" not in L("ARMS20") and L("ARMS20").endswith("[11-39]")
assert "Whirlwind" in L("ARMS50") and L("ARMS50").endswith("[40-60]")
assert L("FERAL50_NOCAT").startswith("Moonfire,Wrath,Starfire") and L("FERAL50_NOCAT").endswith("[40-60]")

# --- 2.5.0: more builds per class from the guides, each with its own rotation
lua.execute("""
local G, C, AD = FlipForever.Guide, FlipForever.Combat, FlipForever.Advisor
COUNTS, BAD = {}, {}
for class, cd in pairs(G.CLASSES) do
  COUNTS[class] = #cd.builds
  local ids = {}
  for _, b in ipairs(cd.builds) do
    if ids[b.id] then BAD[#BAD + 1] = class .. ":dup:" .. b.id end
    ids[b.id] = true
    if not G.SOURCES[b.source] then BAD[#BAD + 1] = class .. ":source:" .. b.id end
    if b.role and not ({ leveling = 1, dps = 1, tank = 1, healer = 1, pvp = 1 })[b.role] then BAD[#BAD + 1] = class .. ":role:" .. b.id end
  end
end
local oldLevel = UnitLevel
local function pick(class, build, level, spells)
  UnitClass = function() return class, class:upper() end
  UnitLevel = function() return level end
  AD:CharStore().build = build
  KNOWN = spells
  return table.concat(C:BuildSteps(), ",")
end
DESTRO = pick("Warlock", "destro_wct", 50, { "Immolate", "Corruption", "Conflagrate", "Incinerate", "Shadowburn", "Shadow Bolt" })
FURY = pick("Warrior", "fury_rb", 30, { "Battle Shout", "Bloodthirst", "Heroic Strike", "Sunder Armor" })
FlipForeverDB.settings.combatTank = nil
pick("Druid", "bear_rb", 50, {})
BEAR_TANK = C:IsTank()
UnitLevel = oldLevel
AD:CharStore().build = nil
""")
counts = dict(L("COUNTS"))
print("builds per class:", counts, "| problems:", list(L("BAD").values()))
print("destro:", L("DESTRO"), "| fury:", L("FURY"), "| bear is tank:", L("BEAR_TANK"))
assert all(7 <= n <= 10 for n in counts.values()) and len(counts) == 9 and not list(L("BAD").values())
assert "Conflagrate" in L("DESTRO") and "Incinerate" in L("DESTRO") and L("FURY").startswith("Battle Shout,Bloodthirst")
assert L("BEAR_TANK") is True

# --- waypoint arrow (feature branch): direction, distance, targets
lua.execute("""
local A = FlipForever.Arrow
local oldMap = C_Map
C_Map = { GetBestMapForUnit = function() return 77 end,
  GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
  GetMapWorldSize = function() return 1000, 1000 end }
local ns = FlipForever.gatherNS
local oldPP, oldMS = ns and ns.PlayerPos, ns and ns.MapSize
if ns then ns.PlayerPos, ns.MapSize = nil, nil end
local t = { mapID = 77, x = 0.6, y = 0.5 }                 -- 100 yards east
ROT_N, DIST = A:Compute(t, 77, 0.5, 0.5, 0)               -- facing north: point right (-90 degrees)
ROT_E = A:Compute(t, 77, 0.5, 0.5, 3 * math.pi / 2)       -- facing east: straight ahead
OTHER = A:Compute(t, 78, 0.5, 0.5, 0)                     -- target on another map: nothing
SlashCmdList.FLIPFOREVERWAY("60 50")
MANUAL = A:Target()
SHOWN = FlipForeverArrow and FlipForeverArrow:IsShown()
SlashCmdList.FLIPFOREVERWAY("")
CLEARED = A.manual == nil
-- map pin whose position is a plain table (no GetXY), as on some clients
C_Map.HasUserWaypoint = function() return true end
C_Map.GetUserWaypoint = function() return { uiMapID = 77, position = { x = 0.25, y = 0.75 } } end
PIN = A:Target()
C_Map.GetUserWaypoint = function() return { uiMapID = 77, position = {} } end
PIN_BAD = A:Target()
C_Map.GetPlayerMapPosition = function() return { x = 0.4, y = 0.6 } end
POS_PLAIN = table.concat({ select(2, pcall(function() return FlipForever.Arrow.PosXY(C_Map.GetPlayerMapPosition()) end)) }, ",")
if ns then ns.PlayerPos, ns.MapSize = oldPP, oldMS end
C_Map = oldMap
""")
import math as _m
print("arrow: rot north", round(L("ROT_N"), 3), "dist", L("DIST"), "| rot east", round(L("ROT_E") % (2 * _m.pi), 3), "| manual", dict(L("MANUAL")), "| shown", L("SHOWN"))
assert abs(L("ROT_N") + _m.pi / 2) < 1e-9 and abs(L("DIST") - 100) < 1e-9
assert abs(L("ROT_E") % (2 * _m.pi)) < 1e-9 and L("OTHER") is None
assert abs(L("MANUAL").x - 0.6) < 1e-9 and L("MANUAL").mapID == 77 and L("SHOWN") and L("CLEARED") is True
print("arrow plain pin:", L("PIN") and (L("PIN").x, L("PIN").y), "| bad pin:", L("PIN_BAD"), "| plain pos:", L("POS_PLAIN"))
assert abs(L("PIN").x - 0.25) < 1e-9 and abs(L("PIN").y - 0.75) < 1e-9 and L("PIN_BAD") is None
assert L("POS_PLAIN") == "0.4,0.6"

# --- translations keep every placeholder (%d, %s) and colour code in the same order
import re as _re  # noqa: E402
from flipforever import i18n as _i18n  # noqa: E402
_bad = []
for _lang, _table in _i18n.TRANSLATIONS.items():
    for _en, _tr in _table.items():
        for _pat in (r"%[ds]", r"\|c[0-9a-f]{8}|\|r"):
            if _re.findall(_pat, _en) != _re.findall(_pat, _tr):
                _bad.append((_lang, _en))
print("translations checked:", sum(len(t) for t in _i18n.TRANSLATIONS.values()), "| placeholder problems:", _bad[:5])
assert not _bad
lua.execute("""
FlipForeverDB.settings.language = "deDE"
DE_STEP = FlipForever:T("At level %d: %s"):format(20, "Mount")
FlipForeverDB.settings.language = nil
""")
assert L("DE_STEP") == "Auf Stufe 20: Mount"
# chat messages translate, and the plural "s" disappears in other languages
lua.execute("""
FlipForeverDB.settings.language = "frFR"
FR_MAIL = FlipForever:T("|cffffd200Mail:|r %d auction%s sold since your last visit, |cff33ff99+%s|r after the AH cut."):format(2, FlipForever:Plural(2), "1g")
FlipForeverDB.settings.language = "enUS"
EN_PLURAL = FlipForever:Plural(2) .. FlipForever:Plural(1)
FlipForeverDB.settings.language = nil
""")
print("french mail line:", L("FR_MAIL"))
assert "2 enchère(s) vendue(s)" in L("FR_MAIL") and L("EN_PLURAL") == "s"
# the How to use page: every section has all 10 translations and still matches its English text
from flipforever import i18n_help as _help  # noqa: E402
from flipforever.gui import HELP as _HELP  # noqa: E402
assert len(_help.SECTIONS) == len(_HELP) and all(len(r) == 10 for _, r in _help.SECTIONS)
_stale = [s for (s, _), (_, en) in zip(_help.SECTIONS, _HELP) if not en.startswith(s)]
assert not _stale, _stale
assert _help.translate(1, _HELP[1][1], "deDE").startswith("FlipForever findet") and _help.translate(1, "changed", "deDE") == "changed"
# the desktop app: fixed texts of every widget follow the chosen language
import tkinter as _tk  # noqa: E402
from tkinter import ttk as _ttk  # noqa: E402
from flipforever import gui as _gui  # noqa: E402
try:
    _root = _tk.Tk()
    _root.withdraw()
except _tk.TclError:
    _root = None
if _root is not None:
    _i18n.set_language("deDE")
    _lbl = _ttk.Label(_root, text="   search:")
    _btn = _ttk.Button(_root, text="Save settings")
    _free = _ttk.Label(_root, text="Item Name 123")
    _tv = _ttk.Treeview(_root, columns=("a", "b"))
    _tv.heading("a", text="Profit")
    _tv.heading("b", text="Qty")
    _n = _gui.translate_widgets(_root)
    print("app widgets translated:", _n, "|", _lbl.cget("text"), "|", _btn.cget("text"), "|", _tv.heading("a", "text"))
    assert _lbl.cget("text") == "   Suche:" and _btn.cget("text") == "Einstellungen speichern"
    assert _tv.heading("a", "text") == "Gewinn" and _tv.heading("b", "text") == "Menge" and _free.cget("text") == "Item Name 123"
    _i18n.set_language("enUS")
    _root.destroy()

# the app follows the character you play: the one the game saved last, once per new character
_cc = _sqlite3.connect(":memory:")
_cc.row_factory = _sqlite3.Row
_cc.executescript(_store.SCHEMA)
_store.set_param(_cc, "Realm A - Horde", "chars", {"Alt": {"t": 100}, "Main": {"t": 300}})
_store.set_param(_cc, "Realm B - Alliance", "chars", {"Other": {"t": 200}, "Broken": {"t": "x"}})
_cc.execute("INSERT INTO scans VALUES (?,?,?,?)", ("Realm A - Horde", 1, "full", 0))
_cc.execute("INSERT INTO scans VALUES (?,?,?,?)", ("Realm B - Alliance", 1, "full", 0))
print("last played:", _engine.last_played(_cc))
assert _engine.last_played(_cc) == ("Realm A - Horde", "Main", 300)


class _FakeApp:
    def __init__(self, con):
        self.con, self.settings = con, _store.Settings()
        self.settings.save = lambda: None


_fa = _FakeApp(_cc)
_fa.settings.realm, _fa.settings.character = "Realm B - Alliance", "Other"
_sw1 = _gui.App._follow_played_character(_fa)
_fa.settings.character = "Alt"                       # the player picks another one by hand
_sw2 = _gui.App._follow_played_character(_fa)        # same character saved again: the pick stays
_store.set_param(_cc, "Realm B - Alliance", "chars", {"Other": {"t": 400}})
_sw3 = _gui.App._follow_played_character(_fa)        # now another character was played
_fa.settings.auto_character = False
_store.set_param(_cc, "Realm A - Horde", "chars", {"Main": {"t": 500}})
_sw4 = _gui.App._follow_played_character(_fa)        # switched off
print("follow played character:", _sw1, _sw2, _sw3, _sw4, "|", _fa.settings.realm, _fa.settings.character)
assert (_sw1, _sw2, _sw3, _sw4) == ("Main", None, "Other", None)
assert (_fa.settings.realm, _fa.settings.character) == ("Realm B - Alliance", "Other")

# --- test harness: delayed timers wait for their time instead of being dropped (issue P9)
lua.execute("""
FIRED = 0
C_Timer.After(10, function() FIRED = FIRED + 1 end)
RunTimers(5)
EARLY = FIRED
RunTimers(10)
LATE = FIRED
""")
assert L("EARLY") == 0 and L("LATE") == 1, (L("EARLY"), L("LATE"))
print("mock timers: a 10 s timer waits through a 5 s run and fires in the next one")

# --- quest locations (feature branch): start NPCs, learned positions, arrow target
lua.execute("""
local QS, AD = FlipForever.QuestStarts, FlipForever.Advisor
HUNTER_NE = QS:Find("HUNTER", "Taming the Beast - get your first pet", "Alliance", "Night Elf")
DRUID_H = QS:Find("DRUID", "Cure Poison quest (Lessons Anew)", "Horde", "Tauren")
NONE = QS:Find("MAGE", "anything", "Horde", "Orc")
VW_UD = QS:Find("WARLOCK", "Voidwalker class quest", "Horde", "Undead").npc
DS_TAUREN = QS:Find("WARRIOR", "Defensive Stance class quest", "Horde", "Tauren").npc
SORAN = QS:Find("WARLOCK", "Staff or Orb of Soran'ruk quest", "Alliance", "Human").npc
local m, x, y = QS:Locate(HUNTER_NE)
SEED = m and (m .. ":" .. x .. ":" .. y)
-- talk to Turak Runetotem: his position is remembered
local oldMap, oldUN = C_Map, UnitName
C_Map = { GetBestMapForUnit = function() return 1456 end,
  GetPlayerMapPosition = function() return { GetXY = function() return 0.7, 0.3 end } end, GetMapWorldSize = function() return 1000, 1000 end }
local ns = FlipForever.gatherNS
local oldPP = ns and ns.PlayerPos
if ns then ns.PlayerPos = nil end
UnitName = function(u) if u == "npc" then return "Turak Runetotem" end return "Tester" end
Fire("QUEST_DETAIL")
local lm, lx, ly = QS:Locate(DRUID_H)
LEARNED = lm and (lm .. ":" .. lx .. ":" .. ly)
-- the Advisor step for a tauren druid at 14 gets the start NPC and an arrow target
UnitName = oldUN
UnitClass = function() return "Druid", "DRUID" end
UnitRace = function() return "Tauren" end
UnitFactionGroup = function() return "Horde" end
UnitLevel = function() return 14 end
KNOWN = { "Bear Form" }
STEP, TARGET = nil, nil
for _, r in ipairs(AD:Compute()) do
  if r.text:find("Lessons Anew") then STEP = r.text TARGET = r.target and r.target.label WHY = r.why end
end
-- the quest is in the log and its hand-in spot is learned: the step points there instead (switch off: the NPC)
local QH = FlipForever.QuestHelper
local oldLog = QH.Log
QH.Log = function() return { { questID = 7001, title = "Lessons Anew", complete = true, objectives = {} } } end
QH:Entry(7001, "Lessons Anew").turnin = { n = "Mull Thunderhorn", m = 1456, x = 0.6, y = 0.4 }
local function stepTarget()
  for _, r in ipairs(AD:Compute()) do if r.text:find("Lessons Anew") then return r.target and r.target.label end end
end
LEARNED_STEP = stepTarget()
FlipForeverDB.settings.advisorQuestSpots = false
LEARNED_OFF = stepTarget()
FlipForeverDB.settings.advisorQuestSpots = nil
-- quest log button: pins the selected quest's next spot and points the arrow; again removes it
local oldSet = FlipForever.Arrow.SetTarget
local aimed
FlipForever.Arrow.SetTarget = function(_, m, x, y, l) aimed = l end
local ps = QH:PinStore() for k in pairs(ps) do ps[k] = nil end
local on = QH:PinQuest(7001)
local n1 = #QH:PinStore()
local off = QH:PinQuest(7001)
QLOG_PIN = tostring(on) .. ":" .. n1 .. ":" .. tostring(off) .. ":" .. #QH:PinStore() .. ":" .. tostring(QH:PinQuest(9999)) .. ":" .. tostring(aimed)
FlipForever.Arrow.SetTarget = oldSet
QH.Log = oldLog
FlipForeverDB.quests[7001] = nil
if ns then ns.PlayerPos = oldPP end
C_Map = oldMap
""")
print("quest starts:", dict(L("HUNTER_NE")), "| seed", L("SEED"), "| learned", L("LEARNED"))
print("advisor step:", L("STEP"), "| arrow target:", L("TARGET"))
assert L("HUNTER_NE").npc == "Dazalar" and L("DRUID_H").npc == "Turak Runetotem" and L("NONE") is None
assert L("VW_UD") == "Ageron Kargal" and L("DS_TAUREN").startswith("Sorek") and L("SORAN") == "Doan Karhan"
_s = [float(v) for v in L("SEED").split(":")]
assert _s[0] == 1438 and abs(_s[1] - 0.567) < 1e-9 and abs(_s[2] - 0.595) < 1e-9 and L("LEARNED") == "1456:0.7:0.3"
assert "Turak Runetotem" in L("STEP") and L("TARGET") == "Turak Runetotem" and "Click to point" in L("WHY")
print("advisor learned spot:", L("LEARNED_STEP"), "| off:", L("LEARNED_OFF"), "| quest log pin:", L("QLOG_PIN"))
assert L("LEARNED_STEP") == "Hand in: Mull Thunderhorn" and L("LEARNED_OFF") == "Turak Runetotem"
assert L("QLOG_PIN") == "true:1:false:0:false:Lessons Anew - Hand in: Mull Thunderhorn"
# --- gear finder: upgrades already in your bags come first, with an Equip button
lua.execute("""
local FF = FlipForever
local oldModel, oldInfo, oldInstant, oldCont = FF.Planner.Model, C_Item.GetItemInfo, C_Item.GetItemInfoInstant, C_Container
FF.Planner.Model = function() return { [103] = { cur_min = 2000 } } end
local ITEMS = {
  [100] = { "Scaled Chestguard", 2, 28, "INVTYPE_CHEST", 4, 3, { ITEM_MOD_STRENGTH_SHORT = 10 } },
  [103] = { "Heavy Claymore", 2, 25, "INVTYPE_2HWEAPON", 2, 8, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20 } },
}
C_Item.GetItemInfoInstant = function(id) local it = ITEMS[id] if it then return id, "", "", it[4], 0, it[5], it[6] end end
C_Item.GetItemInfo = function(id) local it = ITEMS[id] if it then return it[1], "link:" .. id, it[2], 30, it[3] end end
GetItemStats = function(link) local id = tonumber(link:match("link:(%d+)")) return id and ITEMS[id][7] or nil end
GetInventoryItemLink = function() return nil end
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
  GetContainerItemInfo = function(bag, slot) return { itemID = 100, stackCount = 1 } end }
UnitClass = function() return "Warrior", "WARRIOR" end
UnitLevel = function() return 30 end
GetMoney = function() return 100000 end
EQUIPPED_LINK = nil
EquipItemByName = function(link) EQUIPPED_LINK = link end
FF.Gear:Search()
RunTimers(5)
BAGFIRST = FF.Gear.results[1]
FF.Gear:Buy(BAGFIRST)
BAGSTEP = FF.Gear:TopStep()
-- item tooltips say when a piece beats what you wear; a worse or unusable one gets no line
local function upLine(id) local l = FF.Tooltip:Upgrade(id) return l and (l[1] .. " = " .. l[2]) or "none" end
TT_UP = upLine(103)
ITEMS[104] = { "Rusty Bracers", 1, 20, "INVTYPE_WRIST", 4, 3, {} }
TT_NONE = upLine(104) .. "|" .. upLine(999)
FF.Planner.Model, C_Item.GetItemInfo, C_Item.GetItemInfoInstant, C_Container = oldModel, oldInfo, oldInstant, oldCont
""")
print("bag upgrade:", L("BAGFIRST").name, "| bag:", L("BAGFIRST").bag, "| equipped:", L("EQUIPPED_LINK"), "| step:", L("BAGSTEP"))
assert L("BAGFIRST").name == "Scaled Chestguard" and L("BAGFIRST").bag is True and L("EQUIPPED_LINK") == "link:100"
assert L("BAGSTEP").startswith("Equip Scaled Chestguard from your bags")
print("tooltip upgrade line:", L("TT_UP"), "| no line:", L("TT_NONE"))
assert "upgrade for you" in L("TT_UP") and "Main hand" in L("TT_UP") and L("TT_NONE") == "none|none"

# --- app: profit per character
import hashlib as _hashlib  # noqa: E402
for _ev in [(1000, "buy", 2589, "Linen Cloth", 10, 30, None, None, None, 40), (1100, "post", 2589, "Linen Cloth", 10, 45, 5, None, None, None),
            (2000, "invoice", 2589, "Linen Cloth", 10, None, 5, 450, 22, None)]:
    _t, _e, _iid, _nm, _q, _p, _dep, _gross, _cut, _exp = _ev
    _con.execute("INSERT INTO events VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                 (_hashlib.sha1(repr(_ev).encode()).hexdigest(), _realm, _t, _e, _iid, _nm, _q, _p, _dep, _gross, _cut, _exp, "Altchar"))
_pc = {r["char"]: r for r in _engine.profit_by_char(_con, _realm)}
print("profit per character:", {k: v["realized"] for k, v in _pc.items()})
assert _pc["Altchar"]["realized"] == 128 and _pc["Altchar"]["sold"] == 1 and "Demochar" in _pc

# --- auction length by sell speed (deposit grows with the duration)
lua.execute("""
local T, P = FlipForever.Trader, FlipForever.Planner
local oldSpeed, oldCalc = P.SellsPerDay, C_AuctionHouse.CalculateCommodityDeposit
P.SellsPerDay = function(_, id) return ({ [1] = 30, [2] = 5, [3] = 0.5 })[id] end
DUR = T:DurationFor(1, 2) .. T:DurationFor(2, 2) .. T:DurationFor(3, 2) .. T:DurationFor(4, 2)
USED = nil
C_AuctionHouse.CalculateCommodityDeposit = function(id, d, q) USED = d return 10 end
FlipForeverDB.settings.autoDuration = nil
T:Deposit({ id = 1, commodity = true, qty = 5 })
AUTO = USED
FlipForeverDB.settings.autoDuration = false
T:Deposit({ id = 1, commodity = true, qty = 5 })
OFF = USED
FlipForeverDB.settings.autoDuration = nil
P.SellsPerDay, C_AuctionHouse.CalculateCommodityDeposit = oldSpeed, oldCalc
""")
print("durations (30/day, 5/day, 0.5/day, unknown):", L("DUR"), "| deposit asked for duration", L("AUTO"), "| switched off:", L("OFF"))
assert L("DUR") == "1232" and L("AUTO") == 1 and L("OFF") == 2

# --- combat helper smart mode: cooldowns go first when ready, the rest only moves on after a cast
lua.execute("""
local C, AD = FlipForever.Combat, FlipForever.Advisor
local oldLevel = UnitLevel
FlipForeverDB.settings.combatSmart = nil
FlipForeverDB.settings.combatTarget = false
FlipForeverDB.settings.combatTank = false
UnitClass = function() return "Warrior", "WARRIOR" end
UnitLevel = function() return 50 end
AD:CharStore().build = "arms"
KNOWN = { "Battle Shout", "Rend", "Heroic Strike", "Mortal Strike", "Whirlwind", "Sweeping Strikes" }
TARGET = nil
if not C:Enabled() then C:Toggle() end
C:Rebuild()
CB = FlipForeverCombatButton
SMART_MACRO = CB:GetAttribute("macrotext")
SMART_COUNT = CB:GetAttribute("count")
-- Mortal Strike on cooldown (5 s left), Whirlwind ready: the icon shows Whirlwind
CDS = { ["Mortal Strike"] = 5 }
GetSpellCooldown = function(s) local left = CDS[s] if left then return GetTime() - 1, left + 1 end return 0, 0 end
NEXT1 = C:SmartNext()
CDS["Whirlwind"] = 8; CDS["Sweeping Strikes"] = 20
QueryCastSequence = function(seq) return "Rend" end
NEXT2 = C:SmartNext()
-- every press moves on to the next skill, even when the last one couldn't be cast
ClickButton(CB, false)
SMART_AFTER1 = CB:GetAttribute("macrotext")
NEXT3 = C:SmartNext()
ClickButton(CB, false)
SMART_AFTER2 = CB:GetAttribute("macrotext")
CDS["Recklessness"] = 90; CDS["Bloodrage"] = 1.2
CDTEXT = table.concat({ C.CooldownText("Whirlwind"), C.CooldownText("Recklessness"), C.CooldownText("Bloodrage"), C.CooldownText("Rend"), C.CooldownText(nil) }, ",")
C:UpdateIcons()
C:Toggle()
FlipForeverDB.settings.combatTarget = nil
FlipForeverDB.settings.combatTank = nil
FlipForeverDB.settings.combatSmart = false
UnitLevel = oldLevel
AD:CharStore().build = nil
""")
print("smart macro:", repr(L("SMART_MACRO")))
print("next with MS on cooldown:", L("NEXT1"), "| with all cooldowns busy:", L("NEXT2"))
_m = L("SMART_MACRO")
assert "/cast Mortal Strike\n" in _m and "/cast Whirlwind\n" in _m and "/cast Sweeping Strikes\n" in _m
assert _m.split("\n")[-1] == "/cast Battle Shout" and len(_m) <= 255 and L("SMART_COUNT") >= 3
print("after presses:", repr(L("SMART_AFTER1").split("\n")[-1]), repr(L("SMART_AFTER2").split("\n")[-1]))
assert L("SMART_AFTER1").split("\n")[-1] == "/cast Rend" and L("SMART_AFTER2").split("\n")[-1] == "/cast Heroic Strike"
assert "/cast Mortal Strike\n" in L("SMART_AFTER1")   # cooldowns stay in front of every press
assert L("NEXT1") == "Whirlwind" and L("NEXT2") == "Battle Shout" and L("NEXT3") == "Rend"
print("cooldown texts:", L("CDTEXT"))
assert L("CDTEXT") == "8,2m,,,"

# --- combat helper smart mode, paladin: seal and Judgement in a cast sequence, cooldowns and filler after it
lua.execute("""
local C, AD = FlipForever.Combat, FlipForever.Advisor
local oldLevel = UnitLevel
FlipForeverDB.settings.combatSmart = nil
FlipForeverDB.settings.combatTarget = false
FlipForeverDB.settings.combatTank = false
UnitClass = function() return "Paladin", "PALADIN" end
UnitLevel = function() return 20 end
AD:CharStore().build = nil
KNOWN = { "Seal of Righteousness", "Judgement", "Consecration", "Holy Strike" }
TARGET = nil
CDS = {}
QueryCastSequence = function(seq) return "Judgement" end
if not C:Enabled() then C:Toggle() end
C:Rebuild()
CB = FlipForeverCombatButton
PALA_MACRO = CB:GetAttribute("macrotext")
PALA_COUNT = CB:GetAttribute("count")
PALA_NEXT1 = C:SmartNext()
CDS["Judgement"] = 6
PALA_NEXT2 = C:SmartNext()
CDS["Consecration"] = 5
PALA_NEXT3 = C:SmartNext()
ClickButton(CB, false)
PALA_AFTER = CB:GetAttribute("macrotext")
C:UpdateIcons()
C:Toggle()
FlipForeverDB.settings.combatTarget = nil
FlipForeverDB.settings.combatTank = nil
FlipForeverDB.settings.combatSmart = false
UnitLevel = oldLevel
""")
print("paladin macro:", repr(L("PALA_MACRO")), "| next:", L("PALA_NEXT1"), L("PALA_NEXT2"), L("PALA_NEXT3"))
_p = L("PALA_MACRO").split("\n")
assert _p[0] == "/startattack" and _p[1] == "/castsequence reset=target/combat Seal of Righteousness, Judgement"
assert "/cast Consecration" in _p and _p[-1] == "/cast Holy Strike" and _p.index("/cast Consecration") < _p.index("/cast Holy Strike")
assert L("PALA_COUNT") == 0 and L("PALA_AFTER") == L("PALA_MACRO")   # one macro for every press
assert L("PALA_NEXT1") == "Judgement" and L("PALA_NEXT2") == "Consecration" and L("PALA_NEXT3") == "Holy Strike"

# --- paladin: the big icon follows the seal/Judgement sequence after each cast; missing buffs go first out of combat
lua.execute("""
local C, AD = FlipForever.Combat, FlipForever.Advisor
local oldLevel, oldName, oldQuery = UnitLevel, C_Spell.GetSpellName, QueryCastSequence
FlipForeverDB.settings.combatSmart = nil
FlipForeverDB.settings.combatTarget = false
FlipForeverDB.settings.combatTank = false
UnitClass = function() return "Paladin", "PALADIN" end
UnitLevel = function() return 20 end
AD:CharStore().build = nil
KNOWN = { "Seal of Righteousness", "Judgement", "Consecration", "Holy Strike", "Blessing of Might", "Devotion Aura" }
TARGET = nil
CDS = {}
PBUFFS = {}
UnitBuff = function(unit, i) return PBUFFS[i] end
-- the game's answer: position first, then item, then spell
QueryCastSequence = function(seq) return 1, nil, "Seal of Righteousness" end
local IDS = { [1] = "Seal of Righteousness", [2] = "Judgement", [3] = "Consecration" }
C_Spell.GetSpellName = function(id) return IDS[id] end
if not C:Enabled() then C:Toggle() end
FlipForeverCombatButton.label = { SetText = function(s, t) s.text = t end }   -- keeps the label text
C:Rebuild()
CB = FlipForeverCombatButton
BUFF_MACRO =CB:GetAttribute("macrotext")
BUFF_LABEL = CB.label.text
PBUFFS = { "Greater Blessing of Might" }
Fire("UNIT_AURA", "player")
BUFF_MACRO2 = CB:GetAttribute("macrotext")
PBUFFS = { "Greater Blessing of Might", "Devotion Aura" }
Fire("UNIT_AURA", "player")
BUFF_MACRO3 = CB:GetAttribute("macrotext")
-- auras hidden by the game (around fights): no error, the last answer stays
local oldUB, oldSecret = UnitBuff, issecretvalue
UnitBuff = function() error("Auras cannot be accessed when secret") end
HIDDEN_OK, HIDDEN_MISS = pcall(function() return #C:MissingBuffs() end)
UnitBuff = oldUB
issecretvalue = function(v) return v == "Devotion Aura" end
HIDDEN_NIL = C.PlayerBuffNames() == nil
issecretvalue = function(v) return v == "SECRET" end
CHAT_OK = pcall(Fire, "CHAT_MSG_SYSTEM", "SECRET")
issecretvalue = oldSecret
SEQ0 = C:SmartNext()
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g1", 1)
SEQ1 = C:SmartNext()
SEQ1_LABEL = CB.label.text
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g2", 3)   -- Consecration: not in the sequence
SEQ2 = C:SmartNext()
Fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "g3", 2)   -- someone else
SEQ3 = C:SmartNext()
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g4", 2)
SEQ4 = C:SmartNext()
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g5", 1)
local oldLock = InCombatLockdown
InCombatLockdown = function() return true end
Fire("PLAYER_TARGET_CHANGED")
SEQ5 = C:SmartNext()
InCombatLockdown = oldLock
FlipForeverDB.settings.combatBuffs = false
PBUFFS = {}
C:Rebuild()
BUFF_OFF = CB:GetAttribute("macrotext")
FlipForeverDB.settings.combatBuffs = nil
C:Toggle()
UnitBuff, PBUFFS = nil, nil
C_Spell.GetSpellName, QueryCastSequence, UnitLevel = oldName, oldQuery, oldLevel
FlipForeverDB.settings.combatTarget = nil
FlipForeverDB.settings.combatTank = nil
FlipForeverDB.settings.combatSmart = false
""")
print("buffs first:", repr(L("BUFF_MACRO").split("\n")[:3]), "|", L("BUFF_LABEL"))
assert L("BUFF_MACRO").startswith("/cast [nocombat] Blessing of Might\n/cast [nocombat] Devotion Aura\n/startattack\n/castsequence")
assert L("BUFF_LABEL") == "Blessing of Might (before the fight)"
assert L("BUFF_MACRO2").startswith("/cast [nocombat] Devotion Aura\n/startattack")   # Greater Blessing counts
assert L("BUFF_MACRO3").startswith("/startattack") and len(L("BUFF_MACRO")) <= 255
print("hidden auras:", L("HIDDEN_OK"), L("HIDDEN_MISS"), L("HIDDEN_NIL"), "| hidden chat text:", L("CHAT_OK"))
assert L("HIDDEN_OK") is True and L("HIDDEN_MISS") == 0 and L("HIDDEN_NIL") is True and L("CHAT_OK") is True
print("sequence icon:", L("SEQ0"), L("SEQ1"), L("SEQ2"), L("SEQ3"), L("SEQ4"), "| new target in combat:", L("SEQ5"))
assert L("SEQ0") == "Seal of Righteousness" and L("SEQ1") == "Judgement" and L("SEQ1_LABEL") == "Judgement"
assert L("SEQ2") == "Judgement" and L("SEQ3") == "Judgement" and L("SEQ4") == "Seal of Righteousness"
assert L("SEQ5") == "Seal of Righteousness"
assert L("BUFF_OFF").startswith("/startattack")   # switched off in Settings: no buff lines

# --- a blocked action is kept in the error list with the function name
lua.execute("""
FlipForeverDB.errors = {}
local oldLock = InCombatLockdown
InCombatLockdown = function() return true end
Fire("ADDON_ACTION_BLOCKED", "SomeOtherAddon", "CastSpellByName()")
Fire("ADDON_ACTION_BLOCKED", "FlipForever", "StopMovingOrSizing()")
InCombatLockdown = oldLock
BLOCKED_N = #FlipForeverDB.errors
BLOCKED_MSG = FlipForeverDB.errors[1] and FlipForeverDB.errors[1].msg or ""
""")
print("blocked actions kept:", L("BLOCKED_N"), L("BLOCKED_MSG"))
assert L("BLOCKED_N") == 1 and L("BLOCKED_MSG") == "blocked: StopMovingOrSizing() (in combat)"

# --- combat helper key: + by default (main keyboard and numpad), your own key replaces it, Clear removes it
lua.execute("""
local C = FlipForever.Combat
BOUND = {}
local oldSet = SetOverrideBindingClick
EBOUND = {}
SetOverrideBindingClick = function(owner, prio, key, button)
  if button == "FlipForeverEmergencyButton" then EBOUND[#EBOUND + 1] = key else BOUND[#BOUND + 1] = key end
end
FlipForeverDB.settings.combatKey = nil
if not C:Enabled() then C:Toggle() end
BOUND = {}
C:Apply()
KEYS_DEFAULT = table.concat(BOUND, ",")
EKEYS = {}
for _, k in ipairs(FlipForever.CombatGuide:Keys()) do EKEYS[#EKEYS + 1] = k end
EKEYS = table.concat(EKEYS, ",")
BOUND = {}
C:SetKey("F")
KEYS_OWN = table.concat(BOUND, ",")
BOUND = {}
C:SetKey(nil)
KEYS_CLEARED = table.concat(BOUND, ",")
STORED = tostring(FlipForeverDB.settings.combatKey)
FlipForeverDB.settings.combatKey = nil
C:Toggle()
SetOverrideBindingClick = oldSet
""")
print("combat keys: default", L("KEYS_DEFAULT"), "| own", L("KEYS_OWN"), "| cleared", repr(L("KEYS_CLEARED")), "| stored", L("STORED"))
assert L("EKEYS") == "SHIFT-+,SHIFT-NUMPADPLUS", L("EKEYS")   # emergency key: Shift + the combat key
assert L("KEYS_DEFAULT") == "+,NUMPADPLUS" and L("KEYS_OWN") == "F" and L("KEYS_CLEARED") == "" and L("STORED") == "false"

# --- per-character plans
lua.execute("""
FlipForever_Plan = nil
FlipForever_Plans = {
  ["Tester @ Testrealm - Horde"] = { generated = 1, budget = 5000, buy = { {id=1, max=10, qty=1} }, sell = {} },
  ["Alt @ Testrealm - Horde"] = { generated = 2, budget = 99, buy = {}, sell = {} },
}
""")
print("plan for Tester:", L("FlipForever:Plan().budget"), "| char record:", L("FlipForever:UpdateChar() or FlipForeverDB.realms['Testrealm - Horde'].chars.Tester.money"))
assert L("FlipForever:Plan().budget") == 5000
lua.execute("UnitName = function() return 'Other' end")
print("plan for char without list:", L("FlipForever:Plan()"))
assert L("FlipForever:Plan()") is None
lua.execute("FlipForever.Trader:StartBuying()")
print("status:", L("FlipForever.status"))
assert "No shopping list for Other" in L("FlipForever.status")

# --- mailbox: collect auction gold (sale invoices only)
lua.execute("""
DropTimers()
printed = {}
TAKEN = {}
INBOX = {
  {name="Linen Cloth", bid=3000, cut=150, dep=0, count=30, daysLeft=29},
  {name="Won item", kind="buyer", bid=500, money=0, items=1, daysLeft=29},
  {name="Letter", kind="none", money=1000, daysLeft=29},
  {name="Wool Cloth", bid=2000, cut=100, dep=0, count=10, daysLeft=29},
  {name="Expired", kind="seller", bid=0, money=0, items=1, daysLeft=29},
}
Fire("MAIL_SHOW")
MAILBTN_BEFORE = FlipForeverMailButton.text
MAILN, MAILG = FlipForever:SaleMail()
FlipForeverMailButton.OnClick()
RunTimers(10)
MAILBTN_AFTER = FlipForeverMailButton.text
MAILLEFT = #INBOX
COLLECTMSG = printed[#printed]
""")
print("mail button:", L("MAILBTN_BEFORE"), "->", L("MAILBTN_AFTER"), "| taken:", list(L("TAKEN").values()), "|", L("COLLECTMSG"))
assert L("MAILN") == 2 and L("MAILG") == 4750
assert list(L("TAKEN").values()) == ["Wool Cloth", "Linen Cloth"]
assert L("MAILLEFT") == 3 and "2 sale mails" in L("COLLECTMSG") and "No auction gold" in L("MAILBTN_AFTER")

# --- Overview: this week's profit (today and the 6 days before)
lua.execute("""
UnitName = function() return 'Weekly' end
local log = FlipForever:DB().log
table.insert(log, { e = "invoice", char = "Weekly", t = NOW - 3 * 86400, gross = 10000, cut = 500 })
table.insert(log, { e = "buy", char = "Weekly", t = NOW - 2 * 86400, q = 2, p = 1500 })
table.insert(log, { e = "invoice", char = "Weekly", t = NOW - 9 * 86400, gross = 99999, cut = 0 })
WEEKLINE = FlipForever:WeekLine()
WEEK_TODAY = FlipForever:Today().sales
UnitName = function() return 'Nobody' end
WEEKNONE = FlipForever:WeekLine()
UnitName = function() return 'Tester' end
""")
print("week:", L("WEEKLINE"), "|", L("WEEKNONE"))
assert "+65s" in L("WEEKLINE") and "sold 95s" in L("WEEKLINE") and L("WEEK_TODAY") == 0 and "no trades" in L("WEEKNONE")

# --- spell names on a non-English client (looked up by spell ID)
lua.execute("""
local S, C, AD = FlipForever.Spells, FlipForever.Combat, FlipForever.Advisor
local DE = { [116] = "Frostblitz", [133] = "Feuerball", [2136] = "Feuerschlag", [122] = "Frostnova" }
local oldKnown, oldName, oldLocale = KNOWN, C_Spell.GetSpellName, GetLocale
EN_LOCAL = S:Local("Frostbolt")
GetLocale = function() return "deDE" end
C_Spell.GetSpellName = function(id) return DE[id] end
S:Reset()
KNOWN = { "Frostblitz", "Feuerball", "Feuerschlag" }
DE_LOCAL = S:Local("Frostbolt") .. "|" .. S:Local("Holy Strike") .. "|" .. S:English("Feuerschlag") .. "|" .. S:English("Unbekannt")
local known = AD:KnownSpells()
DE_KNOWN = (known["Frostbolt"] and known["Frostblitz"] and known["Fire Blast"]) and true or false
local oldTarget = TARGET
TARGET = nil
local steps = C:BuildSteps()
TARGET = oldTarget
local out = {}
for i, s in ipairs(steps) do out[i] = S:Local(s) end
DE_STEPS = table.concat(out, ",")
DE_CD = C:HasCooldown("Feuerschlag")
KNOWN, C_Spell.GetSpellName, GetLocale = oldKnown, oldName, oldLocale
S:Reset()
""")
print("spells: en", L("EN_LOCAL"), "| de", L("DE_LOCAL"), "| steps", L("DE_STEPS"))
assert L("EN_LOCAL") == "Frostbolt" and L("DE_LOCAL") == "Frostblitz|Holy Strike|Fire Blast|Unbekannt"
_de = L("DE_STEPS")
assert L("DE_KNOWN") is True and L("DE_CD") is True and _de
assert ("Feuerball" in _de or "Frostblitz" in _de) and not any(e in _de for e in ("Fireball", "Frostbolt", "Fire Blast"))

# --- random-stat gear: the scan keeps each version, the gear finder scores each on its own stats
lua.execute("""
local FF = FlipForever
local oldModel, oldInfo, oldInstant, oldStats = FF.Planner.Model, C_Item.GetItemInfo, C_Item.GetItemInfoInstant, GetItemStats
local oldClass, oldLevel, oldMoney, oldCont = UnitClass, UnitLevel, GetMoney, C_Container
-- the scan: three listings of one bracer in two versions, plus cloth (not gear)
REPL = {
  { name = "Bracers", count = 1, buyout = 900, id = 105, link = "item:105:0:0:0:0:0:1200:0" },
  { name = "Bracers", count = 1, buyout = 700, id = 105, link = "item:105:0:0:0:0:0:1200:0" },
  { name = "Bracers", count = 1, buyout = 500, id = 105, link = "item:105:0:0:0:0:0:1700:0" },
  { name = "Linen Cloth", count = 20, buyout = 2000, id = 2589, link = "item:2589:0:0:0:0:0:0:0" },
}
C_AuctionHouse.GetNumReplicateItems = function() return #REPL end
C_AuctionHouse.GetReplicateItemLink = function(i) return REPL[i + 1].link end
C_Item.GetItemInfoInstant = function(id) if id == 105 then return id, "", "", "INVTYPE_WRIST", 0, 4, 3 end return id, "", "", "", 0, 7, 0 end
FF.Scan:ProcessReplicate({ own = false })
RunTimers(1)
local v = FF.Scan.variants[105]
VAR_1200, VAR_1700, VAR_CLOTH = v and v[1200] and v[1200].price, v and v[1700] and v[1700].price, FF.Scan.variants[2589] and 1 or 0
-- the gear finder: "of the Bear" (1200, strength) beats "of the Owl" (1700, intellect) for a warrior
FF.Planner.Model = function() return { [105] = { cur_min = 500 } } end
C_Item.GetItemInfo = function(l)
  if l == "item:105:0:0:0:0:0:1200:0" then return "Bracers of the Bear", l, 2, 20, 18 end
  if l == "item:105:0:0:0:0:0:1700:0" then return "Bracers of the Owl", l, 2, 20, 18 end
  if l == 105 then return "Bracers", "item:105:0:0:0:0:0:0:0", 2, 20, 18 end
end
GetItemStats = function(l)
  if l:find(":1200:") then return { ITEM_MOD_STRENGTH_SHORT = 6, ITEM_MOD_STAMINA_SHORT = 6 } end
  if l:find(":1700:") then return { ITEM_MOD_INTELLECT_SHORT = 6, ITEM_MOD_SPIRIT_SHORT = 6 } end
  return {}
end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitLevel = function() return 25 end
GetMoney = function() return 100000 end
C_Container = nil
FF.Gear:Search()
RunTimers(5)
local top = FF.Gear.results[1]
GEAR_VAR = top and (top.name .. "|" .. tostring(top.suffix) .. "|" .. top.price) or "none"
-- buying asks the auction house for that version only
calls = {}
FF.Trader:StartBuying({ { id = 105, qty = 1, max = 1000, suffix = 1200 } }, "gear upgrade")
RunTimers(1)
BUY_SUFFIX = FF.Trader.searchSuffix
FF.Trader:Stop()
FF.Scan.variants = nil
REPL = {}
FF.Planner.Model, C_Item.GetItemInfo, C_Item.GetItemInfoInstant, GetItemStats = oldModel, oldInfo, oldInstant, oldStats
UnitClass, UnitLevel, GetMoney, C_Container = oldClass, oldLevel, oldMoney, oldCont
""")
print("gear versions: bear", L("VAR_1200"), "owl", L("VAR_1700"), "| top:", L("GEAR_VAR"), "| buy suffix:", L("BUY_SUFFIX"))
assert L("VAR_1200") == 700 and L("VAR_1700") == 500 and L("VAR_CLOTH") == 0
assert L("GEAR_VAR") == "Bracers of the Bear|1200|700" and L("BUY_SUFFIX") == 1200
_ls = (L("FlipForever:LinkSuffix('item:105:0:0:0:0:0:-23:0')"), L("FlipForever:LinkSuffix(nil)"))
print("link suffixes:", _ls)
assert _ls == (-23, 0)

# --- errors are kept for bug reports; the app copies them without user names or paths
lua.execute("""
FlipForeverDB.errors = nil
FlipForever:On("FF_TEST_BOOM", function() error("boom at C:\\\\Users\\\\Somebody\\\\x.lua") end)
Fire("FF_TEST_BOOM")
for i = 1, 25 do FlipForever:RecordError("loop", "e" .. i) end
ERR_N = #FlipForeverDB.errors
ERR_LAST = FlipForeverDB.errors[ERR_N].msg
printed = {}
SlashCmdList.FLIPFOREVER("errors")
ERR_CMD = table.concat(printed, "\\n")
""")
assert L("ERR_N") == 20 and L("ERR_LAST") == "e25"
assert "Last 5 errors" in L("ERR_CMD") and "loop: e25" in L("ERR_CMD") and "e20" not in L("ERR_CMD")
import tempfile as _tf  # noqa: E402
from pathlib import Path  # noqa: E402
from flipforever import store as _store2  # noqa: E402
with _tf.TemporaryDirectory() as _d:
    _wow = Path(_d) / "_forever_"
    _sv = _wow / "WTF" / "Account" / "ACC" / "SavedVariables"
    _sv.mkdir(parents=True)
    (_sv / "FlipForever.lua").write_text(
        'FlipForeverDB = {\n["errors"] = {\n{ ["t"] = 1700000000, ["v"] = "2.5.0-beta.25", ["where"] = "AUCTION_HOUSE_SHOW", '
        '["msg"] = "Interface\\\\AddOns\\\\FlipForever\\\\Trader.lua:12: boom in C:\\\\Users\\\\Somebody\\\\file" },\n},\n}\n',
        encoding="utf-8")
    _toc = _wow / "Interface" / "AddOns" / "FlipForever"
    _toc.mkdir(parents=True)
    (_toc / "FlipForever.toc").write_text("## Title: FlipForever\n## Version: 2.5.0-beta.25\n", encoding="utf-8")
    _s = _store2.Settings()
    _s.wow_path, _s.account = str(_wow), "ACC"
    _rep = _engine.bug_report_text(_s, "2.5.0-beta.25", now=1700000100)
print("bug report:\n" + _rep)
assert "Addon version: 2.5.0-beta.25" in _rep and "AUCTION_HOUSE_SHOW" in _rep and "Trader.lua:12" in _rep
assert "Somebody" not in _rep and "ACC" not in _rep and _d not in _rep

# --- the Advisor is one click away: title-bar button, clickable next step, key binding names
lua.execute("""
local FF = FlipForever
FF.Hub:Toggle()
local f = _G.FlipForeverHub
local shown = 0
local oldShow, oldToggle = FF.Advisor.Show, FF.Advisor.Toggle
FF.Advisor.Show = function() shown = shown + 1 end
FF.Advisor.Toggle = function() shown = shown + 1 end
f.advisorBtn.OnClick()
f.pages.overview.adviceClick.OnClick()
ADV_OPENED = shown
FF.Advisor.Show, FF.Advisor.Toggle = oldShow, oldToggle
BIND_NAME = BINDING_NAME_FLIPFOREVER_ADVISOR
""")
assert L("ADV_OPENED") == 2 and "Advisor" in L("BIND_NAME")
assert (ADDON / "Bindings.xml").read_text(encoding="utf-8").count("FlipForever.Advisor:Toggle()") == 1

# --- Gear tab: hovering an item shows it with all stats, next to what you wear
lua.execute("""
local FF = FlipForever
TIPS = {}
local function tip(name)
  local t = {}
  for _, m in ipairs({ "SetOwner", "SetHyperlink", "AddLine", "Show", "Hide", "ClearAllPoints", "SetPoint" }) do
    t[m] = function(self, a) table.insert(TIPS, name .. ":" .. m .. ":" .. tostring(a)) end
  end
  return t
end
GameTooltip = tip("GT")
GameTooltip_ShowCompareItem = function(t) table.insert(TIPS, "compare") end
FF.Hub:SelectTab("gear")
local pg = FlipForeverHub.pages.gear
pg.rows[1].data = { link = "item:105:0:0:0:0:0:1200:0", pct = 0.25, slot = 9 }
pg.rows[1].hover.OnEnter(pg.rows[1].hover)
GEAR_TIPS = table.concat(TIPS, " | ")
""")
print("gear hover:", L("GEAR_TIPS"))
assert "GT:SetHyperlink:item:105" in L("GEAR_TIPS") and "compare" in L("GEAR_TIPS") and "25%" in L("GEAR_TIPS")

# --- the autopilot is turned off for players: it can't be switched on
lua.execute("""
local A = FlipForever.Auto
A.AVAILABLE = AUTO_SHIPPED
FlipForeverDB.settings.auto = false
printed = {}
A:SetEnabled(true)
AUTO_ON = A:Enabled()
AUTO_MSG = printed[1] or ""
A.AVAILABLE = true
""")
assert L("AUTO_SHIPPED") is False and L("AUTO_ON") is False and "turned off for now" in L("AUTO_MSG")

# --- druids: each press casts the skill for the form you're in (bear, cat or caster)
lua.execute("""
local FF, C, AD = FlipForever, FlipForever.Combat, FlipForever.Advisor
local oldClass, oldLevel, oldKnown = UnitClass, UnitLevel, KNOWN
UnitClass = function() return "Druid", "DRUID" end
UnitLevel = function() return 24 end
KNOWN = { "Bear Form", "Cat Form", "Wrath", "Moonfire", "Maul", "Demoralizing Roar", "Swipe", "Claw", "Rake", "Rip", "Ferocious Bite" }
FORMS = { "Bear Form", "Aquatic Form", "Cat Form" }
CURFORM = 0
GetNumShapeshiftForms = function() return #FORMS end
GetShapeshiftFormInfo = function(i) return "icon", FORMS[i], false, true end
GetShapeshiftForm = function() return CURFORM end
AD:CharStore().build = nil
if not C:Enabled() then C:Toggle() end
C:Rebuild()
local B = FlipForeverCombatButton
DRUID_M1 = B:GetAttribute("macrotext")
CURFORM = 1
C:UpdateIcons()
DRUID_BEAR_STEP = C.formSteps[1] and C.formSteps[1][1]
C:Toggle()
C.formSteps = nil
UnitClass, UnitLevel, KNOWN = oldClass, oldLevel, oldKnown
""")
print("druid press 1:", repr(L("DRUID_M1")), "| bear step:", L("DRUID_BEAR_STEP"))
_dm = L("DRUID_M1")
assert "[form:1] " in _dm and "[form:3] " in _dm and "/startattack [form:1/3]" in _dm and len(_dm) <= 255
assert _dm.split("; ")[-1] in ("Moonfire", "Wrath") and L("DRUID_BEAR_STEP") in ("Demoralizing Roar", "Maul", "Swipe")

# --- the character record keeps the Advisor's data; an empty realm name doesn't split the data
lua.execute("""
local FF = FlipForever
local rec = FF:DB().chars[UnitName("player")]
rec.build, rec.advisor = "arms", { steps = { "x" } }
FF:UpdateChar()
REC_KEPT = (FF:DB().chars[UnitName("player")].build == "arms" and FF:DB().chars[UnitName("player")].advisor ~= nil) and true or false
local oldRealm = GetRealmName
GetRealmName = function() return "" end
KEY_EMPTY = FF:RealmKey()
-- data that an older version saved under " - Horde" moves to the real realm
FlipForeverDB.realms[" - Horde"] = { scans = { { t = 5, d = "" } }, chars = { Alt = { level = 3, t = 9 } } }
GetRealmName = oldRealm
local before = #FF:DB().scans
FF:MergeEmptyRealm()
MERGED = (FlipForeverDB.realms[" - Horde"] == nil and #FF:DB().scans == before + 1 and FF:DB().chars.Alt.level == 3) and true or false
""")
print("record kept:", L("REC_KEPT"), "| empty realm key:", L("KEY_EMPTY"), "| merged:", L("MERGED"))
assert L("REC_KEPT") is True and L("KEY_EMPTY") == "Testrealm - Horde" and L("MERGED") is True
# --- characters on two realms: a new character on another realm never borrows the last realm while the name is empty
lua.execute("""
local FF = FlipForever
local oldRealm, oldName = GetRealmName, UnitName
local realmName, me = "PvP RP Realm", "Newbie"
GetRealmName = function() return realmName end
UnitName = function(u) if u == "player" then return me end return oldName(u) end
local k1 = FF:RealmKey()                 -- Newbie seen on the PvP realm
me, realmName = "Oldie", "Testrealm"
FF:RealmKey()                            -- Oldie plays last, on the first realm
realmName = ""
local k2 = FF:RealmKey()                 -- Oldie, no name: his own realm
me = "Newbie"
local k3 = FF:RealmKey()                 -- Newbie, no name: the PvP realm, not the last one used
me = "Fresh"
local k4 = FF:RealmKey()                 -- never seen: held under " - Horde" until the name is known
TWO_REALMS = table.concat({ k1, k2, k3, "[" .. k4 .. "]" }, "|")
FlipForeverDB.charRealms["Newbie - Horde"], FlipForeverDB.charRealms["Oldie - Horde"] = nil, nil
FlipForeverDB.realms["PvP RP Realm - Horde"] = nil
GetRealmName, UnitName = oldRealm, oldName
FF:RealmKey()
""")
print("two realms:", L("TWO_REALMS"))
assert L("TWO_REALMS") == "PvP RP Realm - Horde|Testrealm - Horde|PvP RP Realm - Horde|[ - Horde]", L("TWO_REALMS")
# --- WoW: Forever keeps the first realm's long name after a realm switch; the short name decides
lua.execute("""
local FF = FlipForever
local oldRealm = GetRealmName
GetRealmName = function() return "CAMWOW EU4 Realm 1 PvE" end
RegionalUniqueNamesEnabled = function() return true end
Enum.GameRule = { PvPRuleset = 1, RPRuleset = 2, HardcoreRuleset = 3 }
local active = { [1] = true, [2] = true }
C_GameRules = { IsGameRuleActive = function(r) return active[r] or false end }
NORM1 = FF:RealmKey()
active = {}
NORM2 = FF:RealmKey()
active = { [1] = true }
RegionalUniqueNamesEnabled = function() return false end
NORM3 = FF:RealmKey()
RegionalUniqueNamesEnabled, C_GameRules, Enum.GameRule = nil, nil, nil
GetRealmName = oldRealm
FlipForeverDB.realms["RPPvP - Horde"], FlipForeverDB.realms["CAMWOW EU4 Realm 1 PvE - Horde"] = nil, nil
FF:RealmKey()
""")
print("short realm name:", L("NORM1"), "|", L("NORM2"), "|", L("NORM3"))
assert L("NORM1") == "RPPvP - Horde" and L("NORM2") == "CAMWOW EU4 Realm 1 PvE - Horde" and L("NORM3") == "CAMWOW EU4 Realm 1 PvE - Horde"

# --- your auctions: which listings the newest scan undercuts
lua.execute("""
local FF = FlipForever
local oldModel = FF.Planner.Model
FF.Planner.Model = function() return { [501] = { cur_min = 900 }, [502] = { cur_min = 2000 }, [503] = { cur_min = 50 } } end
OWNED = {
  { itemKey = { itemID = 501 }, buyoutAmount = 1000, quantity = 5, status = 0 },   -- undercut by 1s, x5
  { itemKey = { itemID = 502 }, buyoutAmount = 2000, quantity = 1, status = 0 },   -- still cheapest
  { itemKey = { itemID = 503 }, buyoutAmount = 80, quantity = 20, status = 0 },    -- undercut by 30c, x20
  { itemKey = { itemID = 504 }, buyoutAmount = 500, quantity = 1, status = 1 },    -- sold, ignored
}
OWNED_QUERIED = 0
C_AuctionHouse.QueryOwnedAuctions = function() OWNED_QUERIED = OWNED_QUERIED + 1 end
C_AuctionHouse.GetNumOwnedAuctions = function() return #OWNED end
C_AuctionHouse.GetOwnedAuctionInfo = function(i) return OWNED[i] end
printed = {}
Fire("AUCTION_HOUSE_SHOW")
Fire("OWNED_AUCTIONS_UPDATED")
Fire("OWNED_AUCTIONS_UPDATED")   -- a second update in the same visit stays quiet
OWN_MSGS = #printed
OWN_MSG = printed[1]
OWN_LINE = FF.Auctions:Line()
OWN_FIRST = FF.Auctions.undercut[1].id
local saved = FF.Advisor:CharStore().auctions
OWN_SAVED = saved and (saved.up .. "/" .. saved.n .. "/" .. saved.undercut[1].mine) or "none"
FF.Planner.Model = oldModel
""")
print("own auctions:", L("OWN_MSG"), "|", L("OWN_LINE"))
assert L("OWNED_QUERIED") >= 1 and L("OWN_MSGS") == 2 and "2 of your 3 auctions are undercut" in L("OWN_MSG")
assert "cancel and repost only where that pays" in L("printed[2]")   # the undercut fix is offered
assert L("OWN_FIRST") == 503 and "3 up" in L("OWN_LINE") and "2 undercut" in L("OWN_LINE")
print("saved for the app:", L("OWN_SAVED"))
assert L("OWN_SAVED") == "3/2/80"

# --- Overview: age of the newest scan
lua.execute("""
local scans = FlipForever:DB().scans
scans[#scans + 1] = { t = NOW - 25 * 60, d = "" }
AGE_FRESH = FlipForever:ScanAgeLine()
scans[#scans].t = NOW - 7 * 3600
AGE_OLD = FlipForever:ScanAgeLine()
scans[#scans] = nil
""")
print("scan age:", L("AGE_FRESH"), "|", L("AGE_OLD"))
assert L("AGE_FRESH") == "Last scan: 25 min ago" and "7 h ago" in L("AGE_OLD") and "scan again" in L("AGE_OLD")

# --- gear finder: alert only for upgrades that are new since the last search
lua.execute("""
local G = FlipForever.Gear
G.known = nil
ALERTS = {}
printed = {}
local a = { id = 501, name = "Sturdy Belt", slot = 6, price = 900 }
local b = { id = 502, name = "Keen Dagger", slot = 16, price = 4000 }
local bag = { id = 503, name = "Old Boots", slot = 8, bag = true, price = 0 }
GA1 = #G:Announce({ a }, true)              -- first search learns, no alert
GA_PRINT1 = #printed
GA2 = #G:Announce({ a, b, bag }, true)      -- the dagger is new
GA_MSG = printed[#printed]
GA_SOUND = #ALERTS
GA3 = #G:Announce({ a, b }, true)           -- nothing new
FlipForeverDB.settings.gearAlert = false
G.known["502:0"] = nil
printed = {}
GA4 = #G:Announce({ b }, true)
GA_PRINT4 = #printed
FlipForeverDB.settings.gearAlert = nil
""")
print("gear alert:", L("GA_MSG"))
assert L("GA1") == 0 and L("GA_PRINT1") == 0 and L("GA2") == 1 and "Keen Dagger" in L("GA_MSG") and L("GA_SOUND") == 1
assert L("GA3") == 0 and L("GA4") == 1 and L("GA_PRINT4") == 0

# --- talent overlay: the chosen build on the game's Talents window
lua.execute("""
local TO = FlipForever.TalentOverlay
SAVED_TALENTS = TALENTS
SAVED_CLASS = UnitClass
function UnitClass() return "Mage", "MAGE" end
TALENTS = { {"Improved Frostbolt", 5, 5}, {"Precision", 3, 3}, {"Frostbite", 1, 3}, {"Ice Shards", 0, 3}, {"Ice Lance", 0, 1} }
FlipForever.Advisor:CharStore().build = nil
PLEVEL = 22
-- the load-on-demand Talents window with five talent buttons
TF = CreateFrame("Frame", "TalentFrame")
for i = 1, 5 do CreateFrame("Button", "TalentFrameTalent" .. i, TF) end
TF.selectedTab = 1
Fire("ADDON_LOADED", "Blizzard_TalentUI")
TF.shown = true
TO:Refresh()
local plan = TO:PanelText().plan
TO_STATES = {}
for _, s in ipairs(plan.steps) do TO_STATES[#TO_STATES + 1] = s.name .. "=" .. s.state end
TO_STATES = table.concat(TO_STATES, ",")
TO_MARK3 = TO:Mark(TalentFrameTalent3) and TO:Mark(TalentFrameTalent3).state
TO_MARK1 = TO:Mark(TalentFrameTalent1) and TO:Mark(TalentFrameTalent1).state
TO_PANEL = FlipForeverTalentPanel and FlipForeverTalentPanel:IsShown()
TO_HOOKED = #(TF.hooks.OnShow or {})
-- a point spent: the next talent moves on
TALENTS[3][2] = 3
Fire("CHARACTER_POINTS_CHANGED")
TO_MARK3B = TO:Mark(TalentFrameTalent3).state
TO_MARK4B = TO:Mark(TalentFrameTalent4).state
-- switched off in Settings: marks and panel go away
FlipForeverDB.settings.talentOverlay = false
TO:Refresh()
TO_OFF_MARK = TO:Mark(TalentFrameTalent4):IsShown()
TO_OFF_PANEL = FlipForeverTalentPanel:IsShown()
FlipForeverDB.settings.talentOverlay = nil
-- window closed: panel hides
TF.shown = false
TO:Refresh()
TO_CLOSED = FlipForeverTalentPanel:IsShown()
TALENTS = SAVED_TALENTS
""")
print("talent overlay:", L("TO_STATES"))
assert L("TO_STATES").startswith("Improved Frostbolt=done,Precision=done,Frostbite=next,Ice Shards=todo,Ice Lance=todo"), L("TO_STATES")
assert L("TO_MARK3") == "next" and L("TO_MARK1") == "done" and L("TO_PANEL") and L("TO_HOOKED") == 1
assert L("TO_MARK3B") == "done" and L("TO_MARK4B") == "next"
assert L("TO_OFF_MARK") is False and L("TO_OFF_PANEL") is False and L("TO_CLOSED") is False
lua.execute("""
PLEVEL = 12
TO_LVL = {}
for _, s in ipairs(FlipForever.TalentOverlay:Plan(FlipForever.Advisor:Build(FlipForever.Advisor:Player()), 12).steps) do
  if s.name == "Ice Lance" then TO_LVL = s.state end
end
TO_LINE = FlipForever.TalentOverlay:StepLine({ order = 5, name = "Ice Lance", state = "level", minLevel = 20 })
PLEVEL = 22
UnitClass = SAVED_CLASS
""")
assert L("TO_LVL") == "level" and "from level 20" in L("TO_LINE")

# --- talent overlay beta 2: tree names, role, how to play, points to spend, /ff talents
lua.execute("""
local TO, AD = FlipForever.TalentOverlay, FlipForever.Advisor
UnitClass = function() return "Mage", "MAGE" end
SAVED_TABINFO = GetTalentTabInfo
GetTalentTabInfo = function(tab) return "Frost" end
UNSPENT = 2
local txt = TO:PanelText()
TO2_LINE = txt.lines[2]
TO2_POINTS = txt.points
TO2_ROLE = txt.role
TO2_ROT = txt.rotation
TO2_BUILD = AD:Build(AD:Player())
TO2_HASROT = TO2_BUILD and TO2_BUILD.rotation ~= nil
TO2_ROLEKEY = TO2_BUILD and TO2_BUILD.role
-- /ff talents: loads the Talents window and toggles it
TOGGLED = 0
LoadAddOn = function(name) LOADED = name end
ToggleTalentFrame = function() TOGGLED = TOGGLED + 1 end
PLEVEL = 22
TO2_OPEN = TO:Open()
TO2_TOGGLED = TOGGLED
PLEVEL = 5
local savedLevel = UnitLevel
UnitLevel = function() return PLEVEL end
printed = {}
TO2_OPENLOW = TO:Open()
UnitLevel = savedLevel
TO2_LOW = TOGGLED
TO2_LOWMSG = printed[#printed] or ""
PLEVEL = 22
SlashCmdList.FLIPFOREVER("talents")
TO2_SLASH = TOGGLED
ToggleTalentFrame, LoadAddOn = nil, nil
GetTalentTabInfo = SAVED_TABINFO
UnitClass = SAVED_CLASS
""")
lua.execute("""
-- WoW: Forever: no ToggleTalentFrame and an own window name; the Talents key binding opens it
local TO = FlipForever.TalentOverlay
UnitClass = function() return "Mage", "MAGE" end
local savedTF = _G.TalentFrame
_G.TalentFrame = nil
FOREVER_FRAME = CreateFrame("Frame", "ForeverTalentsFrame", UIParent)
BOUND = nil
RunBinding = function(b) BOUND = b FOREVER_FRAME.shown = true end
TO3_OPEN = TO:Open()
TO3_BOUND = BOUND
TO3_FOUND = TO.foundName
TO3_PANEL = FlipForeverTalentPanel and FlipForeverTalentPanel:IsShown()
RunBinding = nil
printed = {}
FOREVER_FRAME.shown = false
TO.foundName = nil
_G.ForeverTalentsFrame = nil
TO3_FAIL = TO:Open()
TO3_MSG = printed[#printed] or ""
_G.TalentFrame = savedTF
UnitClass = SAVED_CLASS
""")
print("forever talents:", L("TO3_OPEN"), L("TO3_BOUND"), L("TO3_FOUND"), L("TO3_PANEL"), "|", L("TO3_FAIL"), repr(L("TO3_MSG")))
assert L("TO3_OPEN") is True and L("TO3_BOUND") == "TOGGLETALENTS" and L("TO3_FOUND") == "ForeverTalentsFrame" and L("TO3_PANEL")
assert L("TO3_FAIL") is False and "press your Talents key" in L("TO3_MSG")
print("talent panel line:", repr(L("TO2_LINE")), "| points:", repr(L("TO2_POINTS")), "| role:", L("TO2_ROLE"))
print("talents command:", L("TO2_OPEN"), L("TO2_TOGGLED"), L("TO2_OPENLOW"), L("TO2_LOW"), repr(L("TO2_LOWMSG")), L("TO2_SLASH"))
assert L("TO2_LINE").endswith(" |cff888888Frost|r")
assert "2 to spend" in L("TO2_POINTS")
if L("TO2_ROLEKEY"):
    assert L("TO2_ROLE").startswith("Role: ")
if L("TO2_HASROT"):
    assert "How to play:" in L("TO2_ROT")

# --- talent overlay beta 5: warn about points in a tree the build leaves empty
lua.execute("""
local TO = FlipForever.TalentOverlay
DRIFT1 = TO:DriftLine({ points = "0/26/0" }, { spent = { 3, 10, 0 }, treeNames = { "Arms", "Fury", "Protection" } }) or ""
DRIFT2 = TO:DriftLine({ points = "0/26/0" }, { spent = { 0, 10, 0 } }) or ""
DRIFT3 = TO:DriftLine({}, { spent = { 3, 0, 0 } }) or ""
""")
print("talent drift:", L("DRIFT1"))
assert "3 points in Arms" in L("DRIFT1") and L("DRIFT2") == "" and L("DRIFT3") == ""

# --- talent overlay beta 6: where your points should stand per level band
lua.execute("""
local TO = FlipForever.TalentOverlay
-- order: 5 in tree 2, 5 in tree 2, 3 in tree 1, 5 in tree 2, then 33 more in tree 3 (51 points)
local plan = { spent = { 0, 4, 0 }, steps = {
  { tab = 2, target = 5 }, { tab = 2, target = 5 }, { tab = 1, target = 3 }, { tab = 2, target = 5 },
  { tab = 3, target = 30 }, { tab = 3, target = 3 }, { name = "Missing", state = "missing" } } }
local bands = TO:Bands({ talents = {} }, plan)
BANDS = {}
for _, b in ipairs(bands) do BANDS[#BANDS + 1] = b.level .. "=" .. table.concat(b.split, "/") end
BANDS = table.concat(BANDS, " ")
BAND1, BAND2, BEHIND = TO:BandLines({ talents = {} }, plan, 25)
BAND_KEYONLY = TO:Bands({ keyOnly = true }, plan) == nil
-- a short build: complete by level 30, no later bands
local short = TO:Bands({}, { spent = { 0, 0, 0 }, steps = { { tab = 1, target = 15 } } })
SHORT_N, SHORT_LAST = #short, short[#short].level .. "=" .. table.concat(short[#short].split, "/")
-- the panel: points spent elsewhere show a note, unspent points don't
local oldUCP = UnitCharacterPoints
UnitCharacterPoints = function() return 2 end
_, _, BEHIND_OK = TO:BandLines({}, { spent = { 0, 9, 0 }, steps = { { tab = 2, target = 20 } } }, 20)
UnitCharacterPoints = oldUCP
""")
print("level bands:", L("BANDS"), "|", L("BAND1"), "|", L("BAND2"), "| behind at 25:", L("BEHIND"))
assert L("BANDS") == "20=1/10/0 30=3/15/3 40=3/15/13 50=3/15/23 60=3/15/33"
assert L("BAND1") == "By level 20: 1/10/0  |cffffd20030: 3/15/3|r  40: 3/15/13" and L("BAND2") == "50: 3/15/23  60: 3/15/33"
assert L("BEHIND") == 12   # level 25: 16 points due (3 in tree 1, 13 in tree 2), 4 spent
assert L("BAND_KEYONLY") and L("SHORT_N") == 2 and L("SHORT_LAST") == "30=15/0/0"
assert L("BEHIND_OK") == 2

# --- talent picker by level: the talent for every level of the chosen build
lua.execute("""
local TO = FlipForever.TalentOverlay
local savedInfo, savedTALENTS = GetTalentInfo, TALENTS
TIERS = { 1, 1, 2, 3, 5 }
GetTalentInfo = function(tab, i) local t = TALENTS[i] return t[1], nil, TIERS[i], 1, t[2], t[3] end
TALENTS = { {"Improved Frostbolt", 2, 5}, {"Precision", 0, 3}, {"Frostbite", 0, 3}, {"Ice Shards", 0, 3}, {"Ice Lance", 0, 1} }
-- full order: 5 Improved Frostbolt, then Frostbite (tier 2), Ice Shards (tier 3, needs 10 points)
local build = { talents = { {"Improved Frostbolt", 5}, {"Frostbite", 3}, {"Ice Shards", 3} } }
local plan = TO:Plan(build, 14)
local lv = TO:LevelPlan(build, plan, 14)
local o = {}
for _, e in ipairs(lv) do o[#o + 1] = e.level .. ":" .. e.name .. e.rank .. (e.filler and "f" or "") .. ":" .. e.state end
LV = table.concat(o, ",")
LV_N = #lv
LV_RANGES = table.concat(TO:LevelRanges(lv), "|")
-- the panel's By level view
FlipForeverDB.settings.talentView = "levels"
local savedBuild = FlipForever.Advisor.Build
FlipForever.Advisor.Build = function() return build end
local txt = TO:PanelText()
LV_VIEW, LV_FIRST, LV_LINE1 = txt.view, txt.lines[1], txt.lines[2]
FlipForeverDB.settings.talentLevels = false
LV_OFF = TO:PanelText().view
FlipForeverDB.settings.talentLevels, FlipForeverDB.settings.talentView = nil, nil
FlipForever.Advisor.Build = savedBuild
GetTalentInfo, TALENTS = savedInfo, savedTALENTS
""")
print("talents by level:", L("LV"))
print("talent ranges:", L("LV_RANGES"))
assert L("LV").startswith("10:Improved Frostbolt1:done,11:Improved Frostbolt2:done,12:Improved Frostbolt3:next,13:Improved Frostbolt4:todo,14:Improved Frostbolt5:todo,15:Frostbite1:todo"), L("LV")
# Ice Shards (tier 3) needs 10 points in the tree: after 5 + 3 the 9th and 10th points are fillers (Precision)
assert "18:Precision1f:todo,19:Precision2f:todo,20:Ice Shards1:todo" in L("LV"), L("LV")
assert L("LV_N") == 13 and L("LV_RANGES").startswith("L10-14  Improved Frostbolt 5/5")
assert L("LV_VIEW") == "levels" and "By level" in L("LV_FIRST") and "L10" in L("LV_LINE1") and L("LV_OFF") == "order"

# --- WoW: Forever: the three trees come from the trait system (no classic talent functions)
lua.execute("""
local TO = FlipForever.TalentOverlay
local sv = { GetNumTalentTabs, GetNumTalents, GetTalentInfo, GetTalentTabInfo, C_Traits, C_ClassTalents, GetSpellInfo }
GetNumTalentTabs, GetNumTalents, GetTalentInfo, GetTalentTabInfo = nil, nil, nil, nil
-- three trees side by side, 7 rows each; every row has one 5-rank talent, Holy Shield sits in row 7
local NODES, nodeIDs = {}, {}
local function add(id, x, y, name, rank, max)
  NODES[id] = { ID = id, posX = x, posY = y, ranksPurchased = rank, maxRanks = max, entryIDs = { id }, isVisible = true, name = name }
  nodeIDs[#nodeIDs + 1] = id
end
for tree = 1, 3 do
  for row = 1, 7 do
    local id = tree * 100 + row
    local name = (tree == 2 and row == 7) and "Holy Shield" or (tree == 2 and row == 1) and "Redoubt" or ("T" .. tree .. "R" .. row)
    add(id, tree * 4000 + (row % 2) * 600, 1500 + row * 600, name, (tree == 2 and row == 1) and 2 or 0, (name == "Holy Shield") and 1 or 5)
  end
end
NODES[9999] = { ID = 9999, posX = 6000, posY = 900, subTreeID = 5, entryIDs = { 9999 }, name = "Hero" }
nodeIDs[#nodeIDs + 1] = 9999
C_ClassTalents = { GetActiveConfigID = function() return 77 end }
C_Traits = {
  GetConfigInfo = function() return { treeIDs = { 790 } } end,
  GetTreeNodes = function() return nodeIDs end,
  GetNodeInfo = function(_, id) return NODES[id] end,
  GetEntryInfo = function(_, id) return { definitionID = id } end,
  GetDefinitionInfo = function(id) return { spellID = 20000 + id } end,
  GetTreeCurrencyInfo = function() return { { quantity = 3 } } end,
}
GetSpellInfo = function(id) local n = NODES[id - 20000] return n and n.name end
local where, spent = TO:Trees()
local hs, rd = where["Holy Shield"], where["Redoubt"]
TT_HS = hs.tab .. ":" .. hs.tier .. ":" .. hs.max .. ":" .. hs.spellID
TT_RD = rd.tab .. ":" .. rd.tier .. ":" .. rd.rank .. ":" .. spent[2]
TT_HERO = where["Hero"] == nil
local build = { keyOnly = true, talents = { {"Holy Shield", 1}, {"Redoubt", 5} } }
local plan = TO:Plan(build, 11)
local lv = TO:LevelPlan(build, plan, 11)
TT_HSLEVEL = 0
for _, e in ipairs(lv) do if e.name == "Holy Shield" then TT_HSLEVEL = e.level end end
TT_STEP = plan.steps[1].name .. ":" .. plan.steps[1].state
local ranks, unspent = FlipForever.Advisor:Talents()
TT_RANKS = ranks and ranks["Redoubt"].rank .. ":" .. tostring(unspent)
local sp = FlipForever.Advisor:SpendPlan(build, 3, 11)
TT_SPEND = sp and sp[1] and sp[1].name or "none"
GetNumTalentTabs, GetNumTalents, GetTalentInfo, GetTalentTabInfo, C_Traits, C_ClassTalents, GetSpellInfo = (table.unpack or unpack)(sv)
""")
print("trait trees:", L("TT_HS"), L("TT_RD"), "Holy Shield at", L("TT_HSLEVEL"), L("TT_STEP"), L("TT_RANKS"), L("TT_SPEND"))
assert L("TT_HS") == "2:7:1:20207" and L("TT_RD") == "2:1:2:2" and L("TT_HERO")
# Holy Shield (row 7) needs 30 points in its tree: not before level 40
assert L("TT_HSLEVEL") >= 40, L("TT_HSLEVEL")
assert L("TT_STEP") == "Redoubt:next" and L("TT_RANKS") == "2:3" and L("TT_SPEND") == "Redoubt", (L("TT_STEP"), L("TT_SPEND"))

# --- every Paladin build's level order on WoW: Forever's real trees (read in game 23 Nov 2026):
# each point goes into a tier that is already open (5 points per tier in that tree)
lua.execute("""
local TO = FlipForever.TalentOverlay
local FOREVER_PALADIN = { {1,1,"Spiritual Focus",5}, {1,1,"Divine Strength",5}, {1,2,"Healing Light",3}, {1,2,"Reverence",2}, {1,2,"Improved Seals",5}, {1,2,"Purifying Power",2}, {1,3,"Divine Favor",1}, {1,3,"Illumination",5}, {1,3,"Holy Conduit",2}, {1,4,"Divine Precision",2}, {1,4,"Infusion of Light",2}, {1,4,"Oath of Light",1}, {1,5,"Consecrated Ground",2}, {1,5,"Holy Shock",1}, {1,5,"Boundless Light",2}, {1,6,"Holy Power",5}, {1,7,"Light's Vigil",1}, {2,1,"Divine Intellect",5}, {2,1,"Redoubt",5}, {2,2,"Precision",3}, {2,2,"Guardian's Favor",2}, {2,2,"Sacred Duty",2}, {2,3,"Templar's Bulwark",1}, {2,3,"Improved Hammer of Justice",3}, {2,3,"Shield Specialization",2}, {2,3,"Toughness",5}, {2,4,"Swift Judgement",1}, {2,4,"Improved Righteous Fury",3}, {2,4,"Anticipation",5}, {2,5,"Stoicism",2}, {2,5,"Holy Shield",1}, {2,5,"Reckoning",5}, {2,6,"Iron Creed",3}, {2,7,"Shieldsworn",1}, {3,1,"Deflection",5}, {3,1,"Benediction",5}, {3,2,"Improved Judgement",2}, {3,2,"Conviction",3}, {3,2,"Sanctified Judgement",3}, {3,3,"Vindication",3}, {3,3,"Unyielding Faith",2}, {3,3,"Seal of Command",1}, {3,3,"Pursuit of Justice",2}, {3,4,"Eye for an Eye",2}, {3,4,"Sacred Arbiter",1}, {3,4,"Two-Handed Weapon Specialization",3}, {3,5,"Turn Evil",2}, {3,5,"Repentance",1}, {3,5,"Vengeance",3}, {3,6,"Champion of the Light",5}, {3,7,"Unsealed Wrath",1} }
local savedTrees = TO.Trees
TO.Trees = function()
  local where, spent, idx = {}, { 0, 0, 0 }, {}
  for _, t in ipairs(FOREVER_PALADIN) do
    idx[t[1]] = (idx[t[1]] or 0) + 1
    where[t[3]] = { tab = t[1], tier = t[2], index = idx[t[1]], rank = 0, max = t[4] }
  end
  return where, spent, {}
end
local where = TO:Trees()
local bad, missing, orders = {}, {}, {}
for _, b in ipairs(FlipForever.Guide.CLASSES.PALADIN.builds) do
  for _, t in ipairs(b.talents or {}) do if not where[t[1]] then missing[#missing + 1] = b.id .. ":" .. t[1] end end
  local lv = TO:LevelPlan(b, TO:Plan(b, 60), 60) or {}
  local inTree, o = { 0, 0, 0 }, {}
  for _, e in ipairs(lv) do
    local w = where[e.name]
    if not w or inTree[w.tab] < (w.tier - 1) * 5 then bad[#bad + 1] = b.id .. ":" .. e.level .. ":" .. e.name end
    if w then inTree[w.tab] = inTree[w.tab] + 1 end
    o[#o + 1] = e.level .. " " .. e.name .. (e.filler and "*" or "")
  end
  orders[#orders + 1] = b.id .. ": " .. table.concat(o, ", ")
end
-- the guide's order stays: Method Retribution takes one filler point at 34, then Champion of the Light
local ret
for _, b in ipairs(FlipForever.Guide.CLASSES.PALADIN.builds) do if b.id == "ret" then ret = b end end
local lv = TO:LevelPlan(ret, TO:Plan(ret, 60), 60) or {}
local at = {}
for _, e in ipairs(lv) do at[e.level] = e.name .. (e.filler and "*" or "") end
PAL_RET = (at[33] or "") .. "|" .. (at[34] or "") .. "|" .. (at[35] or "") .. "|" .. (at[40] or "") .. "|" .. (at[41] or "")
TO.Trees = savedTrees
PAL_BAD, PAL_MISSING, PAL_ORDERS = table.concat(bad, ", "), table.concat(missing, ", "), table.concat(orders, "\\n")
""")
print("Forever Paladin level orders:\n" + L("PAL_ORDERS"))
print("not in Forever's trees:", L("PAL_MISSING"))
assert L("PAL_BAD") == "", L("PAL_BAD")
assert L("PAL_MISSING") == "", L("PAL_MISSING")
assert L("PAL_RET") == "Unyielding Faith|Deflection*|Champion of the Light|Unsealed Wrath|Divine Strength", L("PAL_RET")

# --- GUI cleanup: one window size for every FlipForever window (Settings, Window size)
lua.execute("""
local FF = FlipForever
FlipForeverDB.settings.windowScale = nil
WS_DEFAULT = FF:WindowScale()
FF.Hub:Show("settings")
local seen = {}
for i = 1, 4 do FF.Hub:NextScale() seen[#seen + 1] = FF:WindowScale() end
WS_CYCLE = table.concat(seen, ",")
WS_N = #FF.windows
FlipForeverDB.settings.windowScale = nil
""")
print("window size:", L("WS_DEFAULT"), L("WS_CYCLE"), L("WS_N"))
# --- Gathering: Ore Farmer switched off for this character (but on for another) doesn't turn Gathering off
lua.execute("""
local ns = FlipForever.gatherNS
local sv = { C_AddOns, GetAddOnInfo, GetAddOnEnableState }
C_AddOns = { GetAddOnEnableState = function() return 1 end,
  GetAddOnInfo = function(n) return n, n, "", false, "DISABLED" end }
GO_OFF = ns.OreFarmerOn()
C_AddOns.GetAddOnInfo = function(n) return n, n, "", true, nil end
GO_ON = ns.OreFarmerOn()
C_AddOns.GetAddOnInfo = function(n) return nil, nil, nil, false, "MISSING" end
GO_MISSING = ns.OreFarmerOn()
C_AddOns, GetAddOnInfo, GetAddOnEnableState = sv[1], sv[2], sv[3]
local saved = ns.skipGather
ns.skipGather = true
GO_MSG = FlipForever:GatherOffReason()
ns.skipGather = saved
GO_READY = tostring(FlipForever:GatherOffReason())
""")
print("gathering guard:", L("GO_OFF"), L("GO_ON"), L("GO_MISSING"), L("GO_READY"))
assert L("GO_OFF") is False and L("GO_ON") is True and L("GO_MISSING") is False and "Ore Farmer" in L("GO_MSG")
assert L("WS_DEFAULT") == 0.9 and L("WS_CYCLE") == "1.0,1.1,0.8,0.9" and L("WS_N") >= 1, L("WS_CYCLE")
# --- talent overlay beta 3: key-talent builds ordered by tier, next point reachable; click a line to open its tree
lua.execute("""
local TO = FlipForever.TalentOverlay
local savedInfo = GetTalentInfo
TIERS = { 1, 1, 2, 3, 5 }   -- Improved Frostbolt, Precision, Frostbite, Ice Shards, Ice Lance
GetTalentInfo = function(tab, i) local t = TALENTS[i] return t[1], nil, TIERS[i], 1, t[2], t[3] end
TALENTS = { {"Improved Frostbolt", 5, 5}, {"Precision", 0, 3}, {"Frostbite", 0, 3}, {"Ice Shards", 0, 3}, {"Ice Lance", 0, 1} }
local key = { keyOnly = true, talents = { {"Ice Lance"}, {"Ice Shards"}, {"Precision"}, {"Frostbite"} } }
local plan = TO:Plan(key, 60)
local o = {}
for _, s in ipairs(plan.steps) do o[#o + 1] = s.name .. "=" .. s.state end
TO3_ORDER = table.concat(o, ",")
-- only key talents above tier 1 and 5 points spent: Frostbite (tier 2) is next, the rest wait
key = { keyOnly = true, talents = { {"Ice Lance"}, {"Ice Shards"}, {"Frostbite"} } }
plan = TO:Plan(key, 60)
o = {}
for _, s in ipairs(plan.steps) do o[#o + 1] = s.name .. "=" .. s.state end
TO3_ORDER2 = table.concat(o, ",")
-- no point spent yet: the first key talent is next, with the points its tier needs
TALENTS[1][2] = 0
key = { keyOnly = true, talents = { {"Ice Shards"}, {"Ice Lance"} } }
plan = TO:Plan(key, 60)
TO3_NEED = plan.steps[1].name .. ":" .. plan.steps[1].state .. ":" .. tostring(plan.steps[1].needPoints)
TALENTS[1][2] = 5
GetTalentInfo = savedInfo
-- clicking a line opens that tree's tab
TF.shown = true
TF.selectedTab = 1
CLICKED = nil
TalentFrameTab2 = CreateFrame("Button")
TalentFrameTab2.Click = function() CLICKED = 2 TF.selectedTab = 2 end
TO3_SAME = TO:ShowTree(1)
TO3_CLICK = TO:ShowTree(2) and CLICKED
TF.selectedTab = 1
TF.shown = false
""")
print("key-talent order:", L("TO3_ORDER"), "|", L("TO3_ORDER2"), "| need:", L("TO3_NEED"))
assert L("TO3_ORDER") == "Precision=next,Frostbite=todo,Ice Shards=todo,Ice Lance=todo"
assert L("TO3_ORDER2") == "Frostbite=next,Ice Shards=todo,Ice Lance=todo"
assert L("TO3_NEED") == "Ice Shards:next:10"
assert L("TO3_SAME") is True and L("TO3_CLICK") == 2

# --- talent overlay beta 4: tooltips on panel lines (game description + build pick) and on marked talents
lua.execute("""
local TO = FlipForever.TalentOverlay
local savedTip = GameTooltip
TIP4 = {}
GameTooltip = {
  SetOwner = function(self, o) self.owner = o TIP4 = {} end,
  SetTalent = function(self, tab, i) TIP4[#TIP4 + 1] = "talent " .. tab .. ":" .. i end,
  AddLine = function(self, t) TIP4[#TIP4 + 1] = t end,
  Show = function() end, Hide = function() end,
  IsOwned = function(self, o) return self.owner == o end,
}
UnitClass = function() return "Mage", "MAGE" end
TF.shown = true
TF.selectedTab = 1
TO:Refresh()
local row = FlipForeverTalentPanel.rows[2]
TO4_ROW = TO:RowTooltip(row) and table.concat(TIP4, "|")
-- a marked talent button adds the build's line to the game's tooltip
local b = TalentFrameTalent3
GameTooltip.owner = b
TIP4 = {}
for _, fn in ipairs(b.hooks.OnEnter or {}) do fn(b) end
TO4_BTN = table.concat(TIP4, "|")
TO4_HOOKS = #(b.hooks.OnEnter or {})
TO:Refresh()
TO4_HOOKS2 = #(b.hooks.OnEnter or {})
TF.shown = false
GameTooltip = savedTip
UnitClass = SAVED_CLASS
""")
print("row tooltip:", L("TO4_ROW"), "| button tooltip:", L("TO4_BTN"))
assert L("TO4_ROW").startswith("talent 1:1|") and "FlipForever build: pick 1 - 5/5 - done" in L("TO4_ROW") and "Click to open this tree." in L("TO4_ROW")
assert L("TO4_BTN").startswith("FlipForever build: pick 3") and L("TO4_HOOKS") == 1 and L("TO4_HOOKS2") == 1

assert L("TO2_TOGGLED") == 1 and L("TO2_LOW") == 1 and "level 10" in L("TO2_LOWMSG") and L("TO2_SLASH") == 2
# --- merchant: sell grey items and repair (button always there, automatic only when switched on)
lua.execute("""
local FF = FlipForever
local M = FF.Merchant
local oldCont, oldVendor, oldMoney = C_Container, FF.VendorPrice, GetMoney
MerchantFrame = CreateFrame("Frame", "MerchantFrame")
MerchantFrame.shown = true
local BAGS = { [0] = {
  [1] = { itemID = 1, stackCount = 3, quality = 0 },                    -- grey, 5c each
  [2] = { itemID = 2, stackCount = 1, quality = 1 },                    -- white: kept
  [3] = { itemID = 3, stackCount = 1, quality = 0, hasNoValue = true }, -- grey without value: kept
  [4] = { itemID = 4, stackCount = 1, quality = 0, isLocked = true },   -- locked: kept
} }
SOLD = {}
C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end,
  GetContainerItemInfo = function(bag, slot) return BAGS[bag] and BAGS[bag][slot] end,
  UseContainerItem = function(bag, slot) SOLD[#SOLD + 1] = BAGS[bag][slot].itemID end,
}
FF.VendorPrice = function(self, id) return 5 end
REPAIRED = 0
CanMerchantRepair = function() return true end
GetRepairAllCost = function() return 250, true end
RepairAllItems = function(guild) REPAIRED = REPAIRED + 1 end
GetMoney = function() return 10000 end
FlipForeverDB.settings.autoJunk, FlipForeverDB.settings.autoRepair = nil, nil
-- off at first: a visit sells and repairs nothing, the strip shows up
Fire("MERCHANT_SHOW")
M_OFF = #SOLD .. ":" .. REPAIRED
M_STRIP = FlipForeverMerchantStrip and FlipForeverMerchantStrip:IsShown()
-- the button sells only the grey item with a value
printed = {}
local n, gold = M:SellJunk()
M_SELL = n .. ":" .. gold .. ":" .. table.concat(SOLD, ",")
M_MSG = printed[#printed] or ""
-- switched on: both happen on the next visit
SOLD = {}
FlipForeverDB.settings.autoJunk, FlipForeverDB.settings.autoRepair = true, true
Fire("MERCHANT_SHOW")
M_ON = #SOLD .. ":" .. REPAIRED
-- not enough gold: no repair
GetMoney = function() return 100 end
M_POOR = M:Repair(true)
-- merchant window closed: nothing sold
MerchantFrame.shown = false
SOLD = {}
M:SellJunk(true)
M_CLOSED = #SOLD
FlipForeverDB.settings.autoJunk, FlipForeverDB.settings.autoRepair = nil, nil
C_Container, FF.VendorPrice, GetMoney = oldCont, oldVendor, oldMoney
CanMerchantRepair, GetRepairAllCost, RepairAllItems = nil, nil, nil
""")
print("merchant:", L("M_OFF"), L("M_SELL"), repr(L("M_MSG")), L("M_ON"), L("M_POOR"), L("M_CLOSED"))
assert L("M_OFF") == "0:0" and L("M_STRIP")
assert L("M_SELL") == "1:15:1" and "15" in L("M_MSG")
assert L("M_ON") == "1:1" and L("M_POOR") == 0 and L("M_CLOSED") == 0

# --- Settings: a switch for every feature; switching one off turns the feature off
lua.execute("""
local FF = FlipForever
local s = FlipForeverDB.settings
FF.Hub:Show("settings")
local f = FlipForeverHub
SW = {}
for _, c in ipairs(f.features or {}) do SW[#SW + 1] = c.key .. "=" .. tostring(c:GetChecked()) end
SW = table.concat(SW, ",")
-- click every switch off
for _, c in ipairs(f.features) do c:SetChecked(false) c:OnClick() end
-- merchant strip gone
MerchantFrame = MerchantFrame or CreateFrame("Frame", "MerchantFrame")
MerchantFrame.shown = true
FF.Merchant:RefreshStrip()
SW_STRIP = FlipForeverMerchantStrip and FlipForeverMerchantStrip:IsShown()
-- mailbox button not shown
Fire("MAIL_SHOW")
SW_MAIL = FlipForeverMailButton and FlipForeverMailButton:IsShown() or false
-- no gear line in tooltips
local oldUp = FF.Tooltip and FF.Tooltip.Upgrade
UPCALLS = 0
if FF.Tooltip then FF.Tooltip.Upgrade = function() UPCALLS = UPCALLS + 1 return { "x", "y" } end end
if FF.Tooltip and FF.Tooltip.Lines then pcall(FF.Tooltip.Lines, FF.Tooltip, 2589) end
if FF.Tooltip then FF.Tooltip.Upgrade = oldUp end
SW_OFF = tostring(s.merchantStrip) .. "," .. tostring(s.autoJunk) .. "," .. tostring(s.autoRepair) .. "," .. tostring(s.undercutCheck) .. "," .. tostring(s.mailButton) .. "," .. tostring(s.gearTooltip)
for _, c in ipairs(f.features) do s[c.key] = nil end
FF.Hub:Toggle()
""")
print("feature switches:", L("SW"), "| off:", L("SW_OFF"), "| strip:", L("SW_STRIP"), "| mail button:", L("SW_MAIL"), "| tooltip upgrade calls:", L("UPCALLS"))
assert L("SW") == "merchantStrip=true,autoJunk=false,autoRepair=false,undercutCheck=true,undercutFix=true,goldReserve=true,bagSpace=true,fastFlips=true,expirySaver=true,disenchant=true,vendorResale=true,watchList=true,ahSummary=true,loginRecap=true,goldGoals=true,restock=true,craftButton=true,profCooldowns=true,craftCostTooltip=true,bestPostTime=true,headStart=true,mailButton=true,mailOpenAll=true,sendToAlt=true,nodeTimers=true,quietChat=true,enemyAlert=true,bagValue=true,trainerReminder=true,levelInfo=true,talentOverlay=true,talentLevels=true,questHelper=true,advisorPins=true,questLogPin=true,levelRoute=true,dungeonAdvisor=true,advisorQuestSpots=true,combatBuffs=true,threatWarning=true,combatLearn=true,combatTips=true,combatGuide=true,combatTutorial=true,controller=true,combatShare=true,gearTooltip=true,gearStats=true"
assert L("SW_OFF") == "false,false,false,false,false,false"
assert not L("SW_STRIP") and not L("SW_MAIL") and L("UPCALLS") == 0

# --- trainer reminder: the class trainer's list is kept; the Advisor shows what you can learn now
lua.execute("""
local FF = FlipForever
local AD = FF.Advisor
SERVICES = {
  { "Frostbolt", "Rank 3", "available", 14, 1000 },
  { "Arcane Intellect", "Rank 2", "unavailable", 28, 5000 },
  { "Fireball", "Rank 2", "used", 12, 600 },
  { "Blink", "", "unavailable", 20, 2000 },
}
GetNumTrainerServices = function() return #SERVICES end
GetTrainerServiceInfo = function(i) local s = SERVICES[i] return s[1], s[2], s[3] end
GetTrainerServiceLevelReq = function(i) return SERVICES[i][4] end
GetTrainerServiceCost = function(i) return SERVICES[i][5] end
IsTradeskillTrainer = function() return false end
Fire("TRAINER_SHOW")
TR_SAVED = #(AD:CharStore().trainer.services)
local due, cost = FF.Trainer:Due(22)
TR_DUE = #due .. ":" .. cost .. ":" .. due[1].name .. ":" .. due[2].name
TR_WHY = FF.Trainer:Why(due)
-- the Advisor step at level 22
local oldLevel = UnitLevel
UnitLevel = function() return 22 end
local recs = AD:Compute()
TR_STEP = ""
for _, r in ipairs(recs) do if r.kind == "trainer" then TR_STEP = r.text end end
-- switched off: no step
FlipForeverDB.settings.trainerReminder = false
TR_OFF = ""
for _, r in ipairs((AD:Compute())) do if r.kind == "trainer" then TR_OFF = r.text end end
FlipForeverDB.settings.trainerReminder = nil
UnitLevel = oldLevel
-- profession trainers are ignored
IsTradeskillTrainer = function() return true end
TR_PROF = FF.Trainer:Read() == nil
AD:CharStore().trainer = nil
GetNumTrainerServices, GetTrainerServiceInfo, GetTrainerServiceLevelReq, GetTrainerServiceCost, IsTradeskillTrainer = nil, nil, nil, nil, nil
""")
print("trainer:", L("TR_SAVED"), L("TR_DUE"), "|", L("TR_STEP"), "|", L("TR_WHY"))
assert L("TR_SAVED") == 3 and L("TR_DUE") == "2:3000:Frostbolt:Blink"
assert "New at your class trainer: 2 spells" in L("TR_STEP") and L("TR_OFF") == "" and L("TR_PROF")
assert "Frostbolt (Rank 3), Blink" in L("TR_WHY")

# --- leveling: XP per hour this session, time to the next level, rested XP
lua.execute("""
local LV = FlipForever.Leveling
local oldLevel, oldNow = UnitLevel, NOW
local XP, XPMAX, LVL = 1000, 10000, 20
UnitXP = function() return XP end
UnitXPMax = function() return XPMAX end
UnitLevel = function() return LVL end
GetXPExhaustion = function() return 4500 end
NOW = 1000
LV:Start()
LV_EARLY = LV:Line()
-- 30 minutes later: 3,000 XP earned, then a level-up with 500 XP into the next level
NOW = 1000 + 1800
XP = 4000
Fire("PLAYER_XP_UPDATE")
LV_RATE = math.floor(LV:PerHour())
LV_LINE = LV:Line()
XP, XPMAX, LVL = 500, 11000, 21
LV:Update()
LV_GAINED = LV.gained
-- at the level cap or switched off: no line
LVL = 60
LV_CAP = LV:Line()
LVL = 21
FlipForeverDB.settings.levelInfo = false
LV_OFF = LV:Line()
FlipForeverDB.settings.levelInfo = nil
UnitLevel, NOW = oldLevel, oldNow
UnitXP, UnitXPMax, GetXPExhaustion = nil, nil, nil
""")
print("leveling:", repr(L("LV_EARLY")), "|", L("LV_LINE"), "| gained:", L("LV_GAINED"))
assert "first kills" in L("LV_EARLY") and "rested 4,500 XP" in L("LV_EARLY")
assert L("LV_RATE") == 6000 and "6,000 XP/hour" in L("LV_LINE") and "level 21 in 1 h 0 min" in L("LV_LINE")
assert L("LV_GAINED") == 9500 and L("LV_CAP") == "" and L("LV_OFF") == ""

# --- combat helper: threat warning (non-tanks near the aggro limit or tanked, tanks losing aggro)
lua.execute("""
local C = FlipForever.Combat
local s = FlipForeverDB.settings
local oldExists, oldAttack = UnitExists, UnitCanAttack
UnitExists = function(u) return u == "target" or u == "targettarget" end
UnitCanAttack = function() return true end
THREAT = { false, 1, 92 }
UnitDetailedThreatSituation = function() return THREAT[1], THREAT[2], THREAT[3] end
s.combatTank = false
TH_HIGH = C:ThreatWarning() or ""
THREAT = { false, 0, 40 }
TH_LOW = C:ThreatWarning() or ""
THREAT = { true, 3, 100 }
TH_TANKED = C:ThreatWarning() or ""
s.combatTank = true
THREAT = { false, 1, 80 }
TH_TANK_LOST = C:ThreatWarning() or ""
THREAT = { true, 3, 100 }
TH_TANK_OK = C:ThreatWarning() or ""
s.threatWarning = false
TH_OFF = C:ThreatWarning() or ""
s.threatWarning, s.combatTank = nil, nil
UnitExists, UnitCanAttack, UnitDetailedThreatSituation = oldExists, oldAttack, nil
""")
print("threat:", L("TH_HIGH"), "|", L("TH_TANKED"), "|", L("TH_TANK_LOST"))
assert "Threat 92%" in L("TH_HIGH") and L("TH_LOW") == "" and "attacking you" in L("TH_TANKED")
assert "lost aggro" in L("TH_TANK_LOST") and L("TH_TANK_OK") == "" and L("TH_OFF") == ""

# --- mailbox: open all mail (gold and items, one at a time; cash on delivery skipped; stops on full bags)
lua.execute("""
local MB = FlipForever.Mailbox
local oldHeader, oldMoney, oldCont = GetInboxHeaderInfo, TakeInboxMoney, C_Container
MAILS = {
  { money = 500, items = {} },                         -- gold only
  { money = 0, items = { "Linen Cloth", "Copper Ore" } }, -- two items
  { money = 0, cod = 900, items = { "Sword" } },       -- cash on delivery: skipped
  { money = 200, items = { "Silk" } },                 -- gold and an item
}
INBOX = MAILS
GetInboxHeaderInfo = function(i) local m = MAILS[i] local n = 0 for _ in pairs(m.items) do n = n + 1 end return nil, nil, "x", "y", m.money, m.cod or 0, 30, n end
GetInboxItem = function(i, a) return MAILS[i].items[a] end
local function landed(i) local m = MAILS[i] if m.money == 0 and #m.items == 0 then table.remove(MAILS, i) end end
TakeInboxMoney = function(i) local m = MAILS[i] C_Timer.After(0.1, function() m.money = 0 for k, x in ipairs(MAILS) do if x == m then landed(k) break end end end) end
TakeInboxItem = function(i, a) local m = MAILS[i] C_Timer.After(0.1, function() table.remove(m.items, a) for k, x in ipairs(MAILS) do if x == m then landed(k) break end end end) end
FREE = 10
C_Container = { GetContainerNumFreeSlots = function(bag) return bag == 0 and FREE or 0 end }
MailFrame = MailFrame or CreateFrame("Frame", "MailFrame")
Fire("MAIL_SHOW")
local mails, gold, items = MB:Open()
MB_OPEN = mails .. ":" .. gold .. ":" .. items
printed = {}
MB:OpenAll()
RunTimers(30)
MB_LEFT = #MAILS
MB_MSG = printed[#printed] or ""
-- bags full: stops with a message, gold still taken
MAILS = { { money = 0, items = { "Ore" } } }
FREE = 0
printed = {}
MB:OpenAll()
RunTimers(30)
MB_FULL = (printed[#printed] or "") .. " | left " .. #MAILS
-- switched off: the button hides
FlipForeverDB.settings.mailOpenAll = false
MB:Refresh()
MB_OFF = FlipForeverOpenAllButton:IsShown()
FlipForeverDB.settings.mailOpenAll = nil
INBOX = {}
GetInboxHeaderInfo, TakeInboxMoney, C_Container = oldHeader, oldMoney, oldCont
GetInboxItem, TakeInboxItem = nil, nil
""")
print("mailbox:", L("MB_OPEN"), "| left:", L("MB_LEFT"), "|", L("MB_MSG"), "|", L("MB_FULL"))
lua.execute("""
-- send to alt: trade goods and flip stock, not soulbound; 12 per mail; right-click cycles characters
local FF, MB = FlipForever, FlipForever.Mailbox
local oldCont, oldInst, oldPlan, oldProg = C_Container, C_Item.GetItemInfoInstant, FF.Plan, FF.Progress
local chars = FF:DB().chars
local saved = {} for k, v in pairs(chars) do saved[k] = v chars[k] = nil end
chars[UnitName("player")] = {} chars["Zed"] = {} chars["Bank"] = {}
local BAG = {}
for s = 1, 14 do BAG[s] = { itemID = 700 + s } end         -- 14 stacks of trade goods
BAG[15] = { itemID = 900 }                                  -- flip stock (on the sell list)
BAG[16] = { itemID = 901 }                                  -- other item: stays
BAG[17] = { itemID = 701, isBound = true }                  -- soulbound: stays
local picked, attached, sentTo = 0, 0, nil
C_Container = { GetContainerNumSlots = function(b) return b == 0 and 17 or 0 end,
  GetContainerItemInfo = function(b, s) return b == 0 and BAG[s] or nil end,
  PickupContainerItem = function() picked = picked + 1 end }
C_Item.GetItemInfoInstant = function(id) return id, "", "", "", 0, (id < 800) and 7 or 2, 0 end
FF.Plan = function() return { sell = { { id = 900 } } } end
FF.Progress = function() return { bought = {} } end
ClickSendMailItemButton = function() attached = attached + 1 end
SendMail = function(to) sentTo = to end
local a1 = MB:Alt()
local n = #MB:AltItems()
local a2 = MB:NextAlt()
local a3 = MB:NextAlt()
local ok = MB:SendToAlt()
local again = MB:SendToAlt()        -- busy until the server confirms
printed = {}
Fire("MAIL_SEND_SUCCESS")
FlipForeverDB.settings.sendToAlt = false
local off = MB:AltEnabled()
FlipForeverDB.settings.sendToAlt = nil
SEND_ALT = table.concat({ a1, n, a2, a3, tostring(ok), tostring(again), attached, picked, tostring(sentTo), printed[#printed] or "", tostring(off) }, "|")
for k in pairs(chars) do chars[k] = nil end for k, v in pairs(saved) do chars[k] = v end
FF:DB().sendAlt = nil
C_Container, C_Item.GetItemInfoInstant, FF.Plan, FF.Progress = oldCont, oldInst, oldPlan, oldProg
ClickSendMailItemButton, SendMail = nil, nil
""")
print("send to alt:", L("SEND_ALT"))
lua.execute("""
-- vendor resale: limited items remembered with the spot; only clear profits; /ff vendors pins the best spot
local FF, V, QH = FlipForever, FlipForever.VendorResale, FlipForever.QuestHelper
local oName, oPrice, oMap = UnitName, FF.PriceOf, C_Map
local SHOP = {
  { 101, 1000, 1, 2 },    -- recipe, 10s, 2 in stock; sells for 50s
  { 102, 1000, 1, -1 },   -- unlimited: not remembered
  { 103, 1000, 1, 1 },    -- sells for 11s: not enough margin
  { 104, 600, 5, 3 },     -- 5 for 6s (1.2s each), sells for 1.6s each: too little profit (< 50c)
}
UnitName = function(u) if u == "npc" then return "Recipe Seller" end return oName(u) end
GetMerchantNumItems = function() return #SHOP end
GetMerchantItemInfo = function(i) local s = SHOP[i] return "x", nil, s[2], s[3], s[4] end
GetMerchantItemLink = function(i) return "|Hitem:" .. SHOP[i][1] .. ":0|h" end
local AH = { [101] = 5000, [102] = 9000, [103] = 1100, [104] = 160 }
FF.PriceOf = function(_, id) return AH[id] end
C_Map = { GetBestMapForUnit = function() return 1429 end,
  GetPlayerMapPosition = function() return { GetXY = function() return 0.4, 0.6 end } end }
local spots = FF:DB().vendorSpots
FF:DB().vendorSpots = {}
printed = {}
Fire("MERCHANT_SHOW")
local s = FF:DB().vendorSpots["Recipe Seller"]
local kept = 0 for _ in pairs(s.items) do kept = kept + 1 end
local atShop = printed[1] or ""
local pins = QH:PinStore() local oldPins = {} for i, p in ipairs(pins) do oldPins[i] = p end for k in pairs(pins) do pins[k] = nil end
V:Command()
local pinned = QH:IsPinned(1429, 0.4, 0.6, "Recipe Seller")
V:Command()                     -- second call keeps the pin
local still = QH:IsPinned(1429, 0.4, 0.6, "Recipe Seller")
FlipForeverDB.settings.vendorResale = false
printed = {}
Fire("MERCHANT_SHOW")
local off = #printed
FlipForeverDB.settings.vendorResale = nil
VENDOR = table.concat({ kept, s.items[101].price, tostring(s.x), atShop, #V:Best(), V:Best()[1].total, tostring(pinned), tostring(still), off }, "|")
for k in pairs(pins) do pins[k] = nil end for i, p in ipairs(oldPins) do pins[i] = p end
FF:DB().vendorSpots = spots
UnitName, FF.PriceOf, C_Map = oName, oPrice, oMap
GetMerchantNumItems, GetMerchantItemInfo, GetMerchantItemLink = nil, nil, nil
""")
print("vendor resale:", L("VENDOR"))
lua.execute("""
-- auction session summary: log entries since the auction house opened, this character only; gold change
local FF, S = FlipForever, FlipForever.Session
local oMoney = GetMoney
local gold = 500000
GetMoney = function() return gold end
Fire("AUCTION_HOUSE_SHOW")
FF:Log({ e = "buy", id = 1, q = 10, p = 300 })
FF:Log({ e = "buy", id = 2, q = 2, p = 1000 })
FF:Log({ e = "post", id = 1, q = 10, p = 500 })
FF:Log({ e = "sold", name = "x" })
FF:Log({ e = "buy", id = 3, q = 5, p = 100, char = "Other" })
FF:DB().log[#FF:DB().log].char = "Other"
gold = 495000
printed = {}
Fire("AUCTION_HOUSE_CLOSED")
local s1 = printed[#printed] or ""
Fire("AUCTION_HOUSE_SHOW")
printed = {}
Fire("AUCTION_HOUSE_CLOSED")
local quiet = #printed
FlipForeverDB.settings.ahSummary = false
Fire("AUCTION_HOUSE_SHOW")
FF:Log({ e = "sold", name = "y" })
printed = {}
Fire("AUCTION_HOUSE_CLOSED")
local off = #printed
FlipForeverDB.settings.ahSummary = nil
GetMoney = oMoney
AHSUM = s1 .. "|" .. quiet .. "|" .. off
""")
print("ah summary:", L("AHSUM"))
lua.execute("""
-- gold goals: /ff goal sets them; progress from today's and this week's trades; switch hides it
local FF = FlipForever
local log = FF:DB().log
local saved = {} for i, e in ipairs(log) do saved[i] = e end for k in pairs(log) do log[k] = nil end
local s = FlipForeverDB.settings
SlashCmdList.FLIPFOREVER("goal day 50")
SlashCmdList.FLIPFOREVER("goal week 200")
local none = FF:GoalSuffix("day")
FF:Log({ e = "invoice", gross = 300000, cut = 15000 })
FF:Log({ e = "buy", q = 10, p = 3500 })
local day, week = FF:GoalSuffix("day"), FF:GoalSuffix("week")
FF:Log({ e = "invoice", gross = 300000, cut = 0 })
local reached = FF:GoalSuffix("day")
s.goldGoals = false
local off = FF:GoalSuffix("day")
s.goldGoals = nil
SlashCmdList.FLIPFOREVER("goal off")
GOALS = table.concat({ none, day, week, reached, off, tostring(s.goalDay) }, "|")
for k in pairs(log) do log[k] = nil end for i, e in ipairs(saved) do log[i] = e end
""")
print("gold goals:", L("GOALS"))
lua.execute("""
-- restock: crafted + posted lately + not up + not in bags -> one reminder per day
local FF, R, P = FlipForever, FlipForever.Restock, FlipForever.Professions
local oStore, oCount = P.Store, C_Item.GetItemCount
P.Store = function() return { Tailoring = { recipes = {
  { learned = true, out = 501 }, { learned = true, out = 502 }, { learned = true, out = 503 }, { learned = false, out = 504 } } } } end
local BAGS2 = { [503] = 2 }
C_Item.GetItemCount = function(id) return BAGS2[id] or 0 end
local log = FF:DB().log
local saved = {} for i, e in ipairs(log) do saved[i] = e end for k in pairs(log) do log[k] = nil end
FF:Log({ e = "post", id = 501, q = 4 })   -- gone: reminder
FF:Log({ e = "sold", id = 501 })
FF:Log({ e = "sold", id = 501 })
FF:Log({ e = "post", id = 502, q = 1 })   -- still up
FF:Log({ e = "post", id = 503, q = 1 })   -- still in bags
FF:Log({ e = "post", id = 504, q = 1 })   -- recipe not learned
FF:Log({ e = "post", id = 600, q = 1 })   -- not crafted (a flip)
FF:DB().restockSeen = nil
printed = {}
local n1 = R:Remind({ { id = 502 } })
local msg = printed[1] or ""
local n2 = R:Remind({ { id = 502 } })     -- same day: quiet
FF:DB().restockSeen = nil
FlipForeverDB.settings.restock = false
local n3 = R:Remind({})
FlipForeverDB.settings.restock = nil
RESTOCK = n1 .. "|" .. n2 .. "|" .. n3 .. "|" .. msg
for k in pairs(log) do log[k] = nil end for i, e in ipairs(saved) do log[i] = e end
FF:DB().restockSeen = nil
P.Store, C_Item.GetItemCount = oStore, oCount
""")
print("restock:", L("RESTOCK"))
lua.execute("""
-- enemy player alert: enemy players who can attack you, once per player and minute, quiet inside
local FF, A = FlipForever, FlipForever.EnemyAlert
local G = _G
local keep = {}
for _, k in ipairs({ "UnitExists", "UnitIsPlayer", "UnitIsDeadOrGhost", "UnitCanAttack", "UnitIsEnemy",
  "UnitName", "UnitLevel", "UnitClass", "UnitIsUnit", "IsInInstance", "GetTime", "PlaySound" }) do keep[k] = G[k] end
local U = { nameplate1 = { name = "Gruk", lvl = 24, class = "Warrior", enemy = true, attack = true },
  nameplate2 = { name = "Ally", lvl = 20, class = "Mage", enemy = false, attack = false },
  nameplate3 = { name = "Calm", lvl = -1, class = "Rogue", enemy = true, attack = false } }
local clock, inside, sounds = 100, false, 0
G.UnitExists = function(u) return U[u] ~= nil end
G.UnitIsPlayer = function(u) return U[u] ~= nil end
G.UnitIsDeadOrGhost = function() return false end
G.UnitCanAttack = function(u) return U[u] and U[u].attack end
G.UnitIsEnemy = function(_, u) return U[u] and U[u].enemy end
G.UnitName = function(u) return U[u] and U[u].name end
G.UnitLevel = function(u) return U[u] and U[u].lvl end
G.UnitClass = function(u) return U[u] and U[u].class end
G.UnitIsUnit = function() return false end
G.IsInInstance = function() return inside end
G.GetTime = function() return clock end
G.PlaySound = function() sounds = sounds + 1 end
A:Reset()
local r = {}
r[#r + 1] = A:Check("nameplate1") or "-"          -- line + sound
r[#r + 1] = A:Check("nameplate1") or "-"          -- same minute: quiet
r[#r + 1] = A:Check("nameplate1", true) or "-"    -- targets you: line, no sound (10 s gap)
r[#r + 1] = A:Check("nameplate2") or "-"          -- same faction
r[#r + 1] = A:Check("nameplate3") or "-"          -- not flagged, can't attack
clock = 200
inside = true
r[#r + 1] = A:Check("nameplate1") or "-"          -- dungeon/battleground: quiet
inside = false
FlipForeverDB.settings.enemyAlert = false
r[#r + 1] = A:Check("nameplate1") or "-"          -- switched off
FlipForeverDB.settings.enemyAlert = nil
r[#r + 1] = A:Check("nameplate1") or "-"          -- a minute later: again
ENEMY = table.concat(r, "#") .. "#" .. sounds
for k, v in pairs(keep) do G[k] = v end
A:Reset()
""")
print("enemy alert:", L("ENEMY"))
lua.execute("""
-- new realm head start: no scans here -> the other realm's price (same faction first), marked; never bought
local FF, P = FlipForever, FlipForever.Professions
local oKey = FF.RealmKey
FF.RealmKey = function() return "NewRealm - Alliance" end
local R = FlipForeverDB.realms
R["NewRealm - Alliance"] = nil
R["Old - Alliance"] = { scans = { { t = 10, d = "77701:100:300:1:1" } } }
R["Other - Horde"] = { scans = { { t = 9e9, d = "77701:100:800:1:1" } } }
local r = {}
local e, realm = FF:EstimateOf(77701)
r[#r + 1] = tostring(e) .. "@" .. tostring(realm)
local pp, est = FF:PlanPriceOf(77701)
r[#r + 1] = pp .. "/" .. tostring(est)
local u, src = P:UnitCost(77701)
r[#r + 1] = u .. "/" .. src
local tip = {}
for _, l in ipairs(FF.Tooltip:Lines(77701)) do tip[#tip + 1] = l[1] .. "=" .. l[2] end
r[#r + 1] = table.concat(tip, ";")
r[#r + 1] = P:EstimateNote() ~= "" and "note" or "nonote"
FlipForeverDB.settings.headStart = false
r[#r + 1] = tostring(FF:EstimateOf(77701)) .. "/" .. P:EstimateNote()
FlipForeverDB.settings.headStart = nil
FF:DB().scans[1] = { t = 20, d = "1:1:1:1:1" }   -- own scan arrived: estimates stop
r[#r + 1] = tostring(FF:EstimateOf(77701)) .. "/" .. tostring(FF:PlanPriceOf(77701))
HEAD = table.concat(r, "#")
R["NewRealm - Alliance"], R["Old - Alliance"], R["Other - Horde"] = nil, nil, nil
FF.RealmKey = oKey
""")
print("head start:", L("HEAD"))
lua.execute("""
-- profession cooldowns: transmutes merged into one entry, known crafts kept when ready, all characters listed
local FF, C = FlipForever, FlipForever.Cooldowns
local oTS, oName = C_TradeSkillUI, UnitName
local CD = { [17187] = 7200, [11479] = 7200, [18560] = 0, [3275] = 0 }
C_TradeSkillUI = { GetRecipeCooldown = function(id) return CD[id] end }
local chars = FF:DB().chars
local keep = {}
for k, v in pairs(chars) do keep[k] = v.cooldowns end
UnitName = function() return "Cdone" end
local recipes = { { id = 17187, name = "Transmute: Arcanite", learned = true }, { id = 11479, name = "Transmute: Iron to Gold", learned = true },
  { id = 18560, name = "Mooncloth", learned = true }, { id = 3275, name = "Linen Bandage", learned = true },
  { id = 99, name = "Transmute: Unlearned", learned = false } }
C:Read(recipes)
UnitName = function() return "Cdtwo" end
CD[18560] = 3 * 86400
C:Read({ recipes[3] })
local r = {}
for _, e in ipairs(C:List()) do r[#r + 1] = e.char .. ":" .. e.name .. ":" .. (e.ready - time() > 60 and "wait" or "ready") end
CDL = table.concat(r, ",") .. "#" .. C:Line()
FlipForeverDB.settings.profCooldowns = false
CDL = CDL .. "#" .. C:Line()
FlipForeverDB.settings.profCooldowns = nil
chars.Cdone, chars.Cdtwo = nil, nil
for k, v in pairs(keep) do if chars[k] then chars[k].cooldowns = v end end
C_TradeSkillUI, UnitName = oTS, oName
""")
print("cooldowns:", L("CDL"))
lua.execute("""
-- expiry saver: 2 expiries since the last sale -> compare with merchant / disenchant before posting
local FF, X, D = FlipForever, FlipForever.ExpirySaver, FlipForever.Disenchant
local oV, oDV, oDE, oName = FF.VendorPrice, D.Value, D.Enabled, FF.ItemName
local VEND, DEV = { [801] = 900 }, { [801] = 3000 }
FF.VendorPrice = function(_, id) return VEND[id] end
D.Value = function(_, id) return DEV[id] end
D.Enabled = function() return true end
FF.ItemName = function(_, id) return "item:" .. id end
local log = FF:DB().log
local saved = {} for i, e in ipairs(log) do saved[i] = e end for k in pairs(log) do log[k] = nil end
FF:Log({ e = "expired", id = 801 })
FF:Log({ e = "sold", id = 801 })
FF:Log({ e = "expired", id = 801 })
local r = { X:Streak(801) }
FF:Log({ e = "expired", name = "item:801" })   -- id unknown: matched by name
r[#r + 1] = X:Streak(801)
printed = {}
r[#r + 1] = tostring(X:Check(801, 2500, 1, 100, 0.05))   -- net ~2275 < DE 3000 -> hold
r[#r + 1] = (printed[1] or ""):find("Disenchanting gives") and "de" or "?"
printed = {}
r[#r + 1] = tostring(X:Check(801, 5000, 1, 100, 0.05))   -- net 4650 > 3000 -> post, with a note
r[#r + 1] = (printed[1] or ""):find("posting it at") and "note" or "?"
DEV[801] = nil
r[#r + 1] = tostring(X:Check(801, 1000, 1, 100, 0.05))   -- net 850 < merchant 900 -> hold
local tl = X:TooltipLines(801)
r[#r + 1] = (tl[1] and tl[1][1]:find("expired 2 times") and tl[1][2]) or "?"
FlipForeverDB.settings.expirySaver = false
r[#r + 1] = tostring(X:Check(801, 1000, 1, 100, 0.05)) .. "/" .. #X:TooltipLines(801)
FlipForeverDB.settings.expirySaver = nil
r[#r + 1] = X:Streak(802)
EXPS = table.concat(r, "#")
for k in pairs(log) do log[k] = nil end for i, e in ipairs(saved) do log[i] = e end
FF.VendorPrice, D.Value, D.Enabled, FF.ItemName = oV, oDV, oDE, oName
""")
print("expiry saver:", L("EXPS"))
lua.execute("""
-- quiet chat: RP realm -> lines kept (or sent to the FlipForever tab); /ff answers and alerts still print
local FF, Q = FlipForever, FlipForever.QuietChat
local oRules, oInfo, oN = FF.Ruleset, GetChatWindowInfo, NUM_CHAT_WINDOWS
local r = {}
Q.log, Q.told = {}, nil
FF.Ruleset = function() return nil end
printed = {}
FF:Print("normal realm")
r[#r + 1] = #printed
FF.Ruleset = function() return "RPPvP" end
printed = {}
FF:Print("kept one")
FF:Print("kept two")
r[#r + 1] = #printed .. "/" .. #Q.log                       -- one notice, two kept
printed = {}
FF:Loud("alert")
SlashCmdList.FLIPFOREVER("reserve")                          -- own command: answers in chat
r[#r + 1] = #printed
printed = {}
SlashCmdList.FLIPFOREVER("log")
r[#r + 1] = (printed[#printed] or ""):find("kept two") and "log" or "?"
local tab = { got = {} }
function tab:AddMessage(t) self.got[#self.got + 1] = t end
NUM_CHAT_WINDOWS = 2
GetChatWindowInfo = function(i) return i == 2 and "FlipForever" or "General" end
ChatFrame2 = tab
printed = {}
FF:Print("to the tab")
r[#r + 1] = #printed .. "/" .. #tab.got
FlipForeverDB.settings.quietChat = false
printed = {}
FF:Print("switched off")
r[#r + 1] = #printed
FlipForeverDB.settings.quietChat = nil
QUIET = table.concat(r, "#")
FF.Ruleset, GetChatWindowInfo, NUM_CHAT_WINDOWS, ChatFrame2 = oRules, oInfo, oN, nil
Q.log, Q.told = {}, nil
""")
print("quiet chat:", L("QUIET"))
assert L("QUIET") == "1#1/2#2#log#0/1#1", L("QUIET")
_x = L("EXPS").split("#")
assert _x[:7] == ["1", "2", "true", "de", "false", "note", "true"], _x
assert "merchant" in _x[7] and _x[8] == "false/0" and _x[9] == "0", _x
_c = L("CDL").split("#")
assert _c[0] == "Cdone:Mooncloth:ready,Cdone:Transmute:wait,Cdtwo:Mooncloth:wait", _c
assert _c[1].startswith("Cooldowns: Mooncloth |cff33ff99ready|r (Cdone)") and "Transmute 2 h (Cdone)" in _c[1] and "Mooncloth 3 days (Cdtwo)" in _c[1], _c
assert _c[2] == "", _c
_h = L("HEAD").split("#")
assert _h[0] == "300@Old - Alliance" and _h[1] == "300/true" and _h[2] == "300/estimate", _h
assert "estimate" in _h[3] and "from Old - Alliance" in _h[3] and _h[4] == "note", _h
assert _h[5] == "nil/" and _h[6] == "nil/nil", _h
assert L("ENEMY") == "Enemy player nearby: Gruk (level 24 Warrior).#-#Enemy player Gruk (level 24 Warrior) is targeting you!#-#-#-#-#Enemy player nearby: Gruk (level 24 Warrior).#2", L("ENEMY")
lua.execute("""
-- craft button: top skill-up (not a trainer recipe), capped by what the bags allow; profit mode only for the open profession
local FF, P = FlipForever, FlipForever.Professions
local oPlan, oProfit, oTS, oPF, oMode, oCur = P.Plan, P.ProfitList, C_TradeSkillUI, ProfessionsFrame, P.mode, P.current
local made = {}
local avail = 3
ProfessionsFrame = { IsShown = function() return true end }
C_TradeSkillUI = { GetBaseProfessionInfo = function() return { professionName = "Tailoring" } end,
  GetRecipeInfo = function(id) return { numAvailable = avail } end,
  CraftRecipe = function(id, n) made[#made + 1] = id .. "x" .. n end }
P.Plan = function() return { { recipe = { id = 11, name = "Linen Bolt" }, crafts = 5 } }, {} end
P.ProfitList = function() return { { recipe = { id = 21, name = "Fire Oil" }, crafts = 4, prof = "Alchemy" },
                                   { recipe = { id = 22, name = "Silk Bag" }, crafts = 2, prof = "Tailoring" } } end
P.mode, P.current = "skill", "Tailoring"
local a = tostring(P:CraftTop())        -- 3 of 5 (materials)
avail = 0
printed = {}
local b = tostring(P:CraftTop())        -- no materials
local bmsg = printed[#printed] or ""
avail = 9
P.mode = "profit"
local c = tostring(P:CraftTop())        -- Silk Bag: the open profession's best
P.Plan = function() return { { recipe = { id = 12, name = "New" }, crafts = 1, learnable = true } }, {} end
P.mode = "skill"
local d = tostring(P:CraftTop())        -- trainer recipe: nothing to craft
FlipForeverDB.settings.craftButton = false
local e = tostring(P:CraftTop())
FlipForeverDB.settings.craftButton = nil
CRAFT = table.concat({ a, b, c, d, e, table.concat(made, ",") }, "|") .. "|" .. bmsg
P.Plan, P.ProfitList, C_TradeSkillUI, ProfessionsFrame, P.mode, P.current = oPlan, oProfit, oTS, oPF, oMode, oCur
""")
print("craft button:", L("CRAFT"))
assert L("CRAFT").startswith("true|false|true|false|false|11x3,22x2|") and "materials for Linen Bolt" in L("CRAFT"), L("CRAFT")
assert L("RESTOCK").startswith("1|0|0|") and "item:501 is sold out (2 sold" in L("RESTOCK"), L("RESTOCK")
assert L("GOALS") == ("  ·  goal |cffffd2000%|r of 50g|  ·  goal |cffffd20050%|r of 50g|  ·  goal |cffffd20012%|r of 200g|"
                      "  ·  goal |cff33ff99110%|r of 50g||nil"), L("GOALS")
assert "bought 12 for" in L("AHSUM") and "posted 10 worth" in L("AHSUM") and "1 auction sold" in L("AHSUM") and "Gold: -" in L("AHSUM") and L("AHSUM").endswith("|0|0"), L("AHSUM")
assert L("VENDOR").startswith("3|1000|0.4|") and L("VENDOR").endswith("|1|7500|true|true|0") and "1 item here can sell for more" in L("VENDOR"), L("VENDOR")
assert L("SEND_ALT") == "Bank|15|Zed|Bank|true|false|12|12|Bank||cff33ff99FlipForever|r: Sent 12 stacks to Bank. Click again to send the rest (3).|false", L("SEND_ALT")
assert L("MB_OPEN") == "3:700:3" and L("MB_LEFT") == 1 and "7s 0c and 3 items" in L("MB_MSG")
assert "bags are full" in L("MB_FULL") and L("MB_FULL").endswith("left 1") and L("MB_OFF") is False

# --- bag value: merchant value, best-way value, items worth posting
lua.execute("""
local FF = FlipForever
local BV = FF.BagValue
local oldCont, oldVendor, oldPrice, oldName = C_Container, FF.VendorPrice, FF.PriceOf, FF.ItemName
local BAGS = { [0] = {
  { itemID = 1, stackCount = 20, quality = 1 },                 -- cloth: AH 50c each, vendor 10c -> post
  { itemID = 2, stackCount = 1, quality = 2, isBound = true },  -- soulbound: vendor only
  { itemID = 3, stackCount = 5, quality = 0 },                  -- grey: vendor only
  { itemID = 4, stackCount = 1, quality = 1 },                  -- AH barely above vendor: not worth it
} }
C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end,
  GetContainerItemInfo = function(bag, slot) return BAGS[bag] and BAGS[bag][slot] end,
}
local VENDOR = { [1] = 10, [2] = 500, [3] = 20, [4] = 100 }
local AH = { [1] = 50, [2] = 9000, [3] = 999, [4] = 120 }
FF.VendorPrice = function(self, id) return VENDOR[id] end
FF.PriceOf = function(self, id) return AH[id] end
FF.ItemName = function(self, id) return "Item" .. id end
BV.cache = nil
local v = BV:Get()
BV_NUMS = v.vendor .. ":" .. v.ah .. ":" .. #v.post .. ":" .. (v.post[1] and v.post[1].id or 0)
BV_LINE = BV:Line()
TIPL = {}
local tip = { AddLine = function(self, t) TIPL[#TIPL + 1] = t end, AddDoubleLine = function(self, a, b) TIPL[#TIPL + 1] = a .. " = " .. b end }
BV:Tooltip(tip)
BV_TIP = table.concat(TIPL, "|")
FlipForeverDB.settings.bagValue = false
BV_OFF = BV:Line()
FlipForeverDB.settings.bagValue = nil
BV.cache = nil
C_Container, FF.VendorPrice, FF.PriceOf, FF.ItemName = oldCont, oldVendor, oldPrice, oldName
""")
print("bag value:", L("BV_NUMS"), "|", L("BV_LINE"), "|", L("BV_TIP"))
# vendor 200+500+100+100 = 900; best way: cloth 20*47=940, bound 500, grey 100, item4 max(114,100)=114 -> 1654

# --- gathering node timers: spots gathered in the last 15 min are skipped by the next stop
lua.execute("""
local ns = FlipForever.gatherNS
local T = 100000
local route = { mapID = 1, W = 1000, H = 1000, pts = {
  { x = 0.10, y = 0.10, node = { lastMined = T - 60 } },      -- gathered a minute ago: waiting
  { x = 0.50, y = 0.50, node = { lastMined = T - 20 * 60 } }, -- back already
  { x = 0.90, y = 0.90, node = {} },                           -- never gathered
}, order = { 1, 2, 3 } }
local r, w, s = ns.RouteTimers(route, T)
NT_TIMERS = r .. ":" .. w .. ":" .. math.floor(s)
NT_WAIT = math.floor(ns.NodeWait(route.pts[1].node, T))
FlipForeverDB.settings.nodeTimers = false
NT_OFF = ns.NodeWait(route.pts[1].node, T)
FlipForeverDB.settings.nodeTimers = nil
""")
print("node timers:", L("NT_TIMERS"), L("NT_WAIT"), L("NT_OFF"))
assert L("NT_TIMERS") == "2:1:840" and L("NT_WAIT") == 840 and L("NT_OFF") == 0
assert L("BV_NUMS") == "900:1654:1:1" and "1 worth posting" in L("BV_LINE") and "Item1 x20" in L("BV_TIP") and L("BV_OFF") == ""

# --- quest helper: learns the giver, objective spots and the hand-in; arrow and map pins
lua.execute("""
local QH, FF = FlipForever.QuestHelper, FlipForever
local oldQL, oldPos, oldName, oldSet = C_QuestLog, FF.Arrow.PlayerPos, UnitName, FF.Arrow.SetTarget
FlipForeverDB.quests = nil
POS = { 1411, 0.50, 0.50 }
FF.Arrow.PlayerPos = function() return POS[1], POS[2], POS[3] end
NPC = "Gornek"
UnitName = function(unit) if unit == "npc" then return NPC end return "Tester" end
QLOG = {}
C_QuestLog = {
  GetNumQuestLogEntries = function() return #QLOG end,
  GetInfo = function(i) local q = QLOG[i] return q and { title = q.title, questID = q.id } end,
  IsComplete = function(id) for _, q in ipairs(QLOG) do if q.id == id then return q.complete end end return false end,
  GetQuestObjectives = function(id) for _, q in ipairs(QLOG) do if q.id == id then return q.objs end end return {} end,
}
ARROWED = nil
FF.Arrow.SetTarget = function(self, m, x, y, label) ARROWED = m .. ":" .. x .. ":" .. y .. ":" .. label end
-- take the quest from Gornek at 50,50
Fire("QUEST_DETAIL")
QLOG[1] = { id = 788, title = "Cutting Teeth", objs = { { text = "Mottled Boar slain: 0/10", numFulfilled = 0, finished = false } } }
Fire("QUEST_ACCEPTED", 788)
Fire("QUEST_LOG_UPDATE")                    -- first look: no point
QH_EMPTY = QH:Spot(QH:Log()[1]) == nil
-- two kills, at 40,60 and 44,64
POS = { 1411, 0.40, 0.60 }
QLOG[1].objs[1].numFulfilled = 1
Fire("QUEST_LOG_UPDATE")
POS = { 1411, 0.44, 0.64 }
QLOG[1].objs[1].numFulfilled = 2
Fire("QUEST_LOG_UPDATE")
local s = QH:Spot(QH:Log()[1])
QH_OBJ = s.kind .. ":" .. string.format("%.2f,%.2f", s.x, s.y) .. ":" .. s.label
-- done: the hand-in goes back to the giver (no hand-in seen yet), with a chat line
QLOG[1].objs[1].numFulfilled, QLOG[1].objs[1].finished, QLOG[1].complete = 10, true, true
PRINTED = {}
local oldPrint = FF.Print
FF.Print = function(self, msg) PRINTED[#PRINTED + 1] = msg end
Fire("QUEST_LOG_UPDATE")
FF.Print = oldPrint
QH_READY_MSG = PRINTED[1] or ""
s = QH:Spot(QH:Log()[1])
QH_TURNIN_GUESS = s.kind .. ":" .. string.format("%.2f,%.2f", s.x, s.y) .. ":" .. s.label
QH:Next()
QH_ARROW = ARROWED
-- a world map showing zone 1411: one pin at the giver
local canvas = CreateFrame("Frame")
canvas.GetWidth = function() return 1000 end
canvas.GetHeight = function() return 600 end
WorldMapFrame = CreateFrame("Frame")
WorldMapFrame.GetMapID = function() return 1411 end
WorldMapFrame.GetCanvas = function() return canvas end
WorldMapFrame.shown = true
QH_PINS = QH:RefreshMap()
WorldMapFrame.GetMapID = function() return 1412 end
QH_PINS_OTHER = QH:RefreshMap()
-- handed in to Gornek, now standing at 52,48
POS = { 1411, 0.52, 0.48 }
Fire("QUEST_COMPLETE")
Fire("QUEST_TURNED_IN", 788, 100, 0)
QH_TURNIN = FlipForeverDB.quests[788].turnin.n .. ":" .. FlipForeverDB.quests[788].turnin.x
-- the next character with the same quest done goes to the learned hand-in
s = QH:Spot(QH:Log()[1])
QH_TURNIN2 = s.label
-- minimap: 1000 x 1000 yard map, 100 yards to the edge of a 140 px minimap
local oldNS, oldCMap, oldCMini = FF.gatherNS, C_Map, C_Minimap
FF.gatherNS = nil
C_Map = { GetMapWorldSize = function() return 1000, 1000 end }
C_Minimap = { GetViewRadius = function() return 100 end }
Minimap = CreateFrame("Frame")
Minimap.GetWidth = function() return 140 end
local n, pins = QH:RefreshMinimap()                    -- standing on the hand-in spot
local p = pins[1]
QH_MM1 = n .. ":" .. string.format("%.0f,%.0f", p.ox + 0, p.oy + 0) .. ":" .. tostring(p.outside)
POS = { 1411, 0.40, 0.48 }                           -- 120 yards west of it: on the edge (64 px east), faded
n, pins = QH:RefreshMinimap()
p = pins[1]
QH_MM2 = n .. ":" .. string.format("%.0f,%.0f", p.ox + 0, p.oy + 0) .. ":" .. tostring(p.outside)
POS = { 1412, 0.40, 0.48 }                           -- another map: none
QH_MM3 = QH:RefreshMinimap()
FF.gatherNS, C_Map, C_Minimap, Minimap = oldNS, oldCMap, oldCMini, nil
-- switched off: no arrow, no pins
FlipForeverDB.settings.questHelper = false
ARROWED = nil
QH:Next()
QH_OFF = (ARROWED == nil) and QH:RefreshMap() == 0
-- an Advisor step pinned on the map shows even with the quest helper off; its own switch hides it
WorldMapFrame.GetMapID = function() return 1411 end
local on = QH:TogglePin(1411, 0.3, 0.7, "Gornek", "Talk to Gornek")
local shown = QH:RefreshMap()
FlipForeverDB.settings.advisorPins = false
local hidden = QH:RefreshMap()
FlipForeverDB.settings.advisorPins = nil
local off = QH:TogglePin(1411, 0.3, 0.7, "Gornek", "Talk to Gornek")
ADV_PIN = tostring(on) .. ":" .. shown .. ":" .. hidden .. ":" .. tostring(off) .. ":" .. #QH:PinStore() .. ":" .. QH:RefreshMap()
FlipForeverDB.settings.questHelper = nil
WorldMapFrame = nil
C_QuestLog, FF.Arrow.PlayerPos, UnitName, FF.Arrow.SetTarget = oldQL, oldPos, oldName, oldSet
""")
print("quest helper:", L("QH_OBJ"), "|", L("QH_TURNIN_GUESS"), "|", L("QH_ARROW"), "| pins:", L("QH_PINS"), L("QH_PINS_OTHER"))
print("quest ready line:", L("QH_READY_MSG"), "| hand-in:", L("QH_TURNIN"), "|", L("QH_TURNIN2"))
assert L("QH_EMPTY") and L("QH_OBJ") == "objective:0.42,0.62:Mottled Boar slain: 0/10"
assert L("QH_TURNIN_GUESS") == "turnin:0.50,0.50:Hand in (quest giver): Gornek"
assert L("QH_ARROW") == "1411:0.5:0.5:Cutting Teeth - Hand in (quest giver): Gornek"
assert "Cutting Teeth" in L("QH_READY_MSG") and L("QH_PINS") == 1 and L("QH_PINS_OTHER") == 0
assert L("QH_TURNIN") == "Gornek:0.52" and L("QH_TURNIN2") == "Hand in: Gornek" and L("QH_OFF")
print("minimap quest pins:", L("QH_MM1"), "|", L("QH_MM2"), "|", L("QH_MM3"))
assert L("QH_MM1") == "1:0,0:false" and L("QH_MM2") == "1:64,0:true" and L("QH_MM3") == 0
lua.execute("""
-- one window style: position saved under its key, Escape closes it unless turned off
local FF = FlipForever
FlipForeverDB.settings.testPos = nil
local n0 = #UISpecialFrames
local w = FF:Window("FlipForeverTestWin", 200, 100, { pos = "testPos", default = { "CENTER", 0, 0 } })
local n1 = #UISpecialFrames
FF:Window("FlipForeverTestWin2", 200, 100, { escape = false, close = false })
WIN = (n1 - n0) .. ":" .. (#UISpecialFrames - n1) .. ":" .. tostring(w.close ~= nil)
""")
print("window style:", L("WIN"))
assert L("WIN") == "1:0:true", L("WIN")
print("advisor map pin:", L("ADV_PIN"))
assert L("ADV_PIN") == "true:1:0:false:0:0"
lua.execute("""
-- controller support: pad names, keyboard keys unchanged, switch off = raw names, next-spot binding
local FF = FlipForever
local oldGBT, oldSet, oldPos = GetBindingText, FF.Arrow.SetTarget, FF.Arrow.PlayerPos
GetBindingText = function(key) return (key:gsub("PAD1$", "A")) end
local l1, l2, l3 = FF:KeyLabel("PAD1"), FF:KeyLabel("SHIFT-PAD1"), FF:KeyLabel("NUMPADPLUS")
FlipForeverDB.settings.controller = false
local l4 = FF:KeyLabel("PAD1")
FlipForeverDB.settings.controller = nil
GetBindingText = nil
local l5 = FF:KeyLabel("PAD1")
GetBindingText = oldGBT
PAD_LABEL = table.concat({ l1, l2, l3, l4, l5 }, ",")
local b = CreateFrame("Button")
local hit = 0
b.SetHitRectInsets = function(_, l) hit = l end
FF:PadFriendly(b, nil)
PAD_HIT = hit
local QH = FF.QuestHelper
local target
FF.Arrow.SetTarget = function(_, m, x, y, label) target = label end
local ps = QH:PinStore() for k in pairs(ps) do ps[k] = nil end
FlipForeverDB.settings.questHelper = false
local none = QH:NextSpot()
QH:TogglePin(1411, 0.3, 0.7, "Gornek", "Talk to Gornek")
QH:NextSpot()
NEXT_SPOT = tostring(none) .. ":" .. tostring(target)
local ps = QH:PinStore() for k in pairs(ps) do ps[k] = nil end
FlipForeverDB.settings.questHelper = nil
FF.Arrow.SetTarget = oldSet
""")
lua.execute("""
-- leveling route: step by race, faction and level; map by learned name first; switch brings back "Level in:"
local FF, AD = FlipForever, FlipForever.Advisor
local oU = { UnitRace, UnitFactionGroup, UnitLevel, UnitClass }
local race, fac, lvl = "Tauren", "Horde", 14
UnitRace = function() return race, race end
UnitFactionGroup = function() return fac end
UnitLevel = function() return lvl end
UnitClass = function() return "Druid", "DRUID" end
local function zoneLine()
  for _, r in ipairs(AD:Compute()) do
    if r.kind == "zone" then return r.text:gsub("^|T.-|t ", ""), r.target end
  end
end
local t1, g1 = zoneLine()
lvl = 3
local t2 = zoneLine()
lvl = 14
FlipForeverDB.mapNames = FlipForeverDB.mapNames or {}
FlipForeverDB.mapNames[99001] = "The Barrens"
local _, g3 = zoneLine()
FlipForeverDB.mapNames[99001] = nil
race, lvl = "Skyborne", 13
local t4, g4 = zoneLine()
race, fac, lvl = "Human", "Alliance", 59
local t5 = zoneLine()
lvl = 60
local _, _, r60 = AD:RouteStep(AD:Player())
t5 = t5 .. ':' .. tostring(r60)
FlipForeverDB.settings.levelRoute = false
lvl = 14
local t6 = zoneLine()
FlipForeverDB.settings.levelRoute = nil
ROUTE = table.concat({ t1, g1 and (g1.mapID .. "@" .. g1.x) or "-", t2, g3 and g3.mapID or "-", t4, tostring(g4), t5, t6 }, "|")
UnitRace, UnitFactionGroup, UnitLevel, UnitClass = oU[1], oU[2], oU[3], oU[4]
""")
print("route:", L("ROUTE"))
assert L("ROUTE") == ("Route (level 11-17): The Crossroads, The Barrens|1413@0.52|Route (level 1-5): Camp Narache, Mulgore|99001|"
                      "Route (level 12-17): Level in The Barrens (Crossroads) or Silverpine Forest.|nil|"
                      "Route (level 58-60): Light's Hope Chapel, Eastern Plaguelands:nil|Level in: Westfall, Loch Modan or Darkshore"), L("ROUTE")
lua.execute("""
-- dungeon advisor: weak slots and armor pick the dungeon; arrow to the entrance; switch brings back the list
local FF, AD, DD = FlipForever, FlipForever.Advisor, FlipForever.DungeonData
local oU = { UnitRace, UnitFactionGroup, UnitLevel, UnitClass, AD.Gear }
local lvl, cls = 22, "WARRIOR"
UnitRace = function() return "Human", "Human" end
UnitFactionGroup = function() return "Alliance" end
UnitLevel = function() return lvl end
UnitClass = function() return cls, cls end
AD.Gear = function()
  return {}, { [5] = { slot = 5, label = "Chest" }, [16] = { slot = 16, label = "Main hand", id = 1, quality = 1, ilvl = 10 },
               [7] = { slot = 7, label = "Legs", id = 2, quality = 2, ilvl = 20 } }
end
local function line()
  for _, r in ipairs(AD:Compute()) do
    if r.kind == "dungeon" then return (r.text:gsub("^|T.-|t ", "")), r.target, r.why end
  end
end
local t1, g1, w1 = line()
cls = "MAGE"
local t2 = line()
local e = DD:Best(22, "Alliance", "WARRIOR", {})
FlipForeverDB.settings.dungeonAdvisor = false
cls = "WARRIOR"
local t3 = line()
FlipForeverDB.settings.dungeonAdvisor = nil
DUNGEON = table.concat({ t1, g1 and (g1.mapID .. "@" .. g1.x .. ":" .. g1.label) or "-", tostring(w1:find("Mutant Scale Breastplate", 1, true) ~= nil),
  t2, tostring(e), t3, tostring(DD:Fits({ "Chest", "Cloth" }, "Plate")), tostring(DD:Armor("HUNTER", 40)) }, "|")
UnitRace, UnitFactionGroup, UnitLevel, UnitClass, AD.Gear = oU[1], oU[2], oU[3], oU[4], oU[5]
""")
print("dungeon:", L("DUNGEON"))
assert L("DUNGEON") == ("Dungeon for upgrades: Wailing Caverns - Chest, Main hand (entrance: The Barrens)|1413@0.46:Wailing Caverns|true|"
                        "Dungeon for upgrades: The Deadmines - Chest, Main hand (entrance: Westfall)|nil|"
                        "Dungeons for your level: The Deadmines, Wailing Caverns, Shadowfang Keep|false|Mail"), L("DUNGEON")
xml = (ADDON / "Bindings.xml").read_text(encoding="utf-8")
print("controller:", L("PAD_LABEL"), "| hit", L("PAD_HIT"), "|", L("NEXT_SPOT"))
assert L("PAD_LABEL") == "A,SHIFT-A,NUMPADPLUS,PAD1,PAD1" and L("PAD_HIT") == -5
assert L("NEXT_SPOT") == "nil:Talk to Gornek - Gornek"
for name in ("CLICK FlipForeverCombatButton:LeftButton", "CLICK FlipForeverEmergencyButton:LeftButton",
             "FLIPFOREVER_NEXT_SPOT", "FLIPFOREVER_ARROW_CLEAR"):
    assert f'name="{name}"' in xml, name
assert "QuestHelper:NextSpot()" in xml and "Arrow:SetManual()" in xml
lua.execute("""
-- crafting cost in tooltips: a known recipe makes the item -> material cost next to the price
local FF, P, TT = FlipForever, FlipForever.Professions, FlipForever.Tooltip
local oStore, oPrice, oEst = P.Store, FF.PriceOf, FF.EstimateOf
local PR = { [2589] = 100, [2996] = 2000 }
FF.PriceOf = function(_, id) return PR[id] end
FF.EstimateOf = function() return nil end
P.Store = function() return { Tailoring = { recipes = {
  { id = 1, name = "Bolt of Linen Cloth", learned = true, out = 2996, outQty = 1, mats = { { 2589, 2 } } },
  { id = 2, name = "Linen Bag", learned = true, out = 4238, outQty = 1, mats = { { 2996, 3 }, { 9999, 1 } } },
  { id = 3, name = "Unlearned", learned = false, out = 2997, mats = { { 2589, 1 } } } } } } end
local r = {}
local c, name, prof, unk = P:CraftCostOf(2996)
r[#r + 1] = table.concat({ c, name, prof, tostring(unk) }, ",")
c, name, prof, unk = P:CraftCostOf(4238)
r[#r + 1] = c .. "," .. tostring(unk)
r[#r + 1] = tostring(P:CraftCostOf(2997))
local function line(id)
  for _, l in ipairs(TT:Lines(id)) do if l[1]:find("crafting cost") then return l[2] end end
  return "none"
end
r[#r + 1] = line(2996)
PR[2996] = 150
r[#r + 1] = line(2996)
FlipForeverDB.settings.craftCostTooltip = false
r[#r + 1] = line(2996)
FlipForeverDB.settings.craftCostTooltip = nil
CRAFTTT = table.concat(r, "#")
P.Store, FF.PriceOf, FF.EstimateOf = oStore, oPrice, oEst
""")
print("craft cost tooltip:", L("CRAFTTT"))
assert L("CRAFTTT").split("#")[:3] == ["200,Bolt of Linen Cloth,Tailoring,false", "6000,true", "nil"], L("CRAFTTT")
assert "profit" in L("CRAFTTT").split("#")[3] and "cheaper to buy" in L("CRAFTTT").split("#")[4], L("CRAFTTT")
assert L("CRAFTTT").split("#")[5] == "none", L("CRAFTTT")
lua.execute("""
-- login recap: auctions that ended while away (minus ones settled while playing), mail flag
local FF, R = FlipForever, FlipForever.LoginRecap
local me = UnitName("player")
local log = FF:DB().log
local saved = {} for i, e in ipairs(log) do saved[i] = e end for k in pairs(log) do log[k] = nil end
local oMail = HasNewMail
local NOW, OUT = 1000000, 1000000 - 30 * 3600   -- logged out 30 h ago
local function add(e) e.char = e.char or me log[#log + 1] = e end
add({ e = "post", id = 1, p = 100, q = 2, dur = 2, t = OUT - 3600 })      -- ends 23 h after logout -> counted
add({ e = "post", id = 2, p = 500, q = 1, dur = 1, t = OUT - 3600 })      -- sold before logout -> settled
add({ e = "sold", id = 2, t = OUT - 600 })
add({ e = "post", id = 3, p = 900, q = 1, dur = 1, t = OUT - 20 * 3600 }) -- ended before logout -> not counted
add({ e = "post", id = 4, p = 700, q = 1, dur = 2, t = OUT - 3600, char = "Alt" }) -- other character
FF:DB().chars[me] = FF:DB().chars[me] or {}
FF:DB().chars[me].logout = OUT
local r = {}
local n, v = R:Ended(me, OUT, NOW)
r[#r + 1] = n .. "," .. v
HasNewMail = function() return true end
r[#r + 1] = R:Line(NOW) or "nil"
FF:DB().chars[me].logout = NOW - 60                 -- short break -> no recap
r[#r + 1] = tostring(R:Line(NOW))
FF:DB().chars[me].logout = OUT
FlipForeverDB.settings.loginRecap = false
r[#r + 1] = tostring(R:Line(NOW))
FlipForeverDB.settings.loginRecap = nil
LRECAP = table.concat(r, "#")
HasNewMail = oMail
FF:DB().chars[me].logout = nil
for k in pairs(log) do log[k] = nil end for i, e in ipairs(saved) do log[i] = e end
""")
print("login recap:", L("LRECAP"))
lr = L("LRECAP").split("#")
assert lr[0] == "1,200" and "1 of your auctions ended" in lr[1] and "new mail" in lr[1] and "30 h" in lr[1], lr
assert lr[2] == "nil" and lr[3] == "nil", lr
lua.execute("""
-- watch list: /ff watch adds, scans and browse rows alert once per 10 min at or below the price
local FF, W = FlipForever, FlipForever.WatchList
local list = W:List()
for k in pairs(list) do list[k] = nil end
W:Reset()
FF:DB().names[2589] = "Linen Cloth"
local r = {}
r[#r + 1] = table.concat({ W:ParseMoney("2g"), W:ParseMoney("1.5"), W:ParseMoney("50s"), W:ParseMoney("1g50s"), tostring(W:ParseMoney("x")) }, ",")
printed = {}
SlashCmdList.FLIPFOREVER("watch linen cloth 50s")
r[#r + 1] = tostring(list[2589])
SlashCmdList.FLIPFOREVER("watch |cffffffff|Hitem:2592::::|h[Wool Cloth]|h|r 1g")
r[#r + 1] = tostring(list[2592])
r[#r + 1] = tostring(W:Seen(2589, 6000, 100))                 -- above the price
r[#r + 1] = (W:Seen(2589, 4000, 100) or "nil"):find("Linen Cloth is listed at") and "alert" or "?"
r[#r + 1] = tostring(W:Seen(2589, 3000, 200))                 -- within 10 min
FF:AddScan("full", { [2592] = { min = 9000, p25 = 9000, qty = 5, n = 1 } })
r[#r + 1] = W.lastScanHit or "scan"
printed = {}
FF:AddScan("full", { [2589] = { min = 100, p25 = 100, qty = 5, n = 1 } }) -- still quiet for 2589 (GetTime based)
SlashCmdList.FLIPFOREVER("watch remove 2592")
r[#r + 1] = tostring(list[2592])
FlipForeverDB.settings.watchList = false
r[#r + 1] = tostring(W:Seen(2589, 1, 99999))
FlipForeverDB.settings.watchList = nil
WATCHL = table.concat(r, "#")
for k in pairs(list) do list[k] = nil end
""")
print("watch list:", L("WATCHL"))
wl = L("WATCHL").split("#")
assert wl[0] == "20000,15000,5000,15000,nil" and wl[1] == "5000" and wl[2] == "10000", wl
assert wl[3] == "nil" and wl[4] == "alert" and wl[5] == "nil" and wl[7] == "nil" and wl[8] == "nil", wl
print("ALL ADDON TESTS PASSED")

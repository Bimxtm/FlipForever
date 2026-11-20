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
function GetInboxInvoiceInfo(i) local m = INBOX[i] return "seller", m.name, "Buyer", m.bid, m.bid, m.dep, m.cut, 0, 0, 0, m.count end
function GetInboxHeaderInfo(i) return nil, nil, "AH", "Sold", INBOX[i].bid, 0, INBOX[i].daysLeft end
"""
lua.execute(MOCK)
toc = (ADDON / "FlipForever.toc").read_text(encoding="utf-8").splitlines()
files = [l.strip() for l in toc if l.strip().endswith(".lua")]
print("load order from TOC:", files)
shared_ns = lua.table()   # WoW gives every file of one addon the same private table
for f in files:
    src = (ADDON / f.replace("\\", "/")).read_text(encoding="utf-8")
    fn = lua.eval("function(src, name) local f, err = load(src, '@'..name) if not f then error(err) end return f end")(src, f)
    fn("FlipForever", shared_ns)
print("all files compile and load")

L = lua.eval
lua.execute("""
Fire("ADDON_LOADED", "FlipForever")
FlipForeverDB.settings.livePlanning = false   -- in-game planning is tested on its own (Beta 4 block)
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
assert any("Spend 2 talent points" in a and "Ice Shards (1/3)" in a for a in adv), "talent advice"
assert any("Hypnotic" not in a for a in adv)
assert any("Coldspire Staff" in a for a in adv), "gear advice"
assert any("Learn Tailoring + Enchanting" in a for a in adv), "profession advice"
assert any("Weak slots" in a and "Main hand (white)" in a for a in adv), "weak slot"
assert any("Dungeons for your level" in a and "Shadowfang Keep" in a for a in adv), "dungeon"
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
assert any("Ice Lance (0/1)" in a for a in adv)
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
assert [r["name"] for r in _rows] == ["Silk Cloth", "Linen Cloth", "Wool Cloth"] and _rows[2]["live"] is True
assert _rows[0]["status"] in ("deal", "watching") and _rows[1]["status"] == "watching"
assert L("ROWS2")[2].status == "skipped" and L("REM_SKIPPED") == 0 and L("REM_OK") == 5 and L("REM_BACK") == 3
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
if ns then ns.PlayerPos, ns.MapSize = oldPP, oldMS end
C_Map = oldMap
""")
import math as _m
print("arrow: rot north", round(L("ROT_N"), 3), "dist", L("DIST"), "| rot east", round(L("ROT_E") % (2 * _m.pi), 3), "| manual", dict(L("MANUAL")), "| shown", L("SHOWN"))
assert abs(L("ROT_N") + _m.pi / 2) < 1e-9 and abs(L("DIST") - 100) < 1e-9
assert abs(L("ROT_E") % (2 * _m.pi)) < 1e-9 and L("OTHER") is None
assert abs(L("MANUAL").x - 0.6) < 1e-9 and L("MANUAL").mapID == 77 and L("SHOWN") and L("CLEARED") is True

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
print("ALL ADDON TESTS PASSED")

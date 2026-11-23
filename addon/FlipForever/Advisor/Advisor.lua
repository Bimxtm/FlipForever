-- FlipForever Advisor: "what should I do right now?" for your race, class and chosen build.
-- Reads the real state of your character - level, talents, spells learned (class quests),
-- equipped gear and bags, quest log, professions, gold - and re-checks after every
-- level-up, quest turn-in, gear change, talent point, skill-up and zone change.
-- Everything is read-only: it never changes anything in the game.
local FF = FlipForever
local G = FF.Guide
local _, ns = ... -- shared with the Gathering module (zone gold/hour)
local AD = {}
FF.Advisor = AD

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

-- Character --------------------------------------------------------------------------------------
function AD:Player()
  local raceName = plain(UnitRace("player")) or "?"
  local className, classToken = UnitClass("player")
  return {
    name = UnitName("player"),
    race = raceName,
    className = plain(className) or "?",
    class = plain(classToken) or "?",
    level = plain(UnitLevel("player")) or 1,
    faction = plain(UnitFactionGroup("player")) or "Neutral",
    money = GetMoney() or 0,
  }
end

function AD:ClassData(p) return G.CLASSES[p.class] end

function AD:CharStore()
  local db = FF:DB()
  local name = UnitName("player") or "?"
  db.chars[name] = db.chars[name] or {}
  return db.chars[name]
end

function AD:Build(p)
  local cd = self:ClassData(p)
  if not cd then return nil end
  local want = self:CharStore().build
  for _, b in ipairs(cd.builds) do
    if b.id == want then return b end
  end
  return cd.builds[1]
end

function AD:CycleBuild(step)
  local p = self:Player()
  local cd = self:ClassData(p)
  if not cd then return end
  local cur = self:Build(p)
  local idx = 1
  for i, b in ipairs(cd.builds) do if b == cur then idx = i end end
  idx = (idx - 1 + step) % #cd.builds + 1
  self:CharStore().build = cd.builds[idx].id
  self:Refresh()
end

-- Spellbook (to tell whether a class quest is done: you know its reward spell) -------------------
function AD:KnownSpells()
  local known = {}
  -- keyed by the client's name and by the English one the guide data uses (Spells.lua)
  local S = FF.Spells
  local function add(name)
    name = plain(name)
    if name then
      known[name] = true
      if S then known[S:English(name)] = true end
    end
  end
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and Enum and Enum.SpellBookSpellBank then
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
      if info then
        for j = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
          local ok, name = pcall(C_SpellBook.GetSpellBookItemName, j, Enum.SpellBookSpellBank.Player)
          if ok then add(name) end
        end
      end
    end
  elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
    for t = 1, GetNumSpellTabs() do
      local _, _, offset, num = GetSpellTabInfo(t)
      for j = offset + 1, offset + num do add(GetSpellBookItemName(j, BOOKTYPE_SPELL or "spell")) end
    end
  end
  return known
end

-- Items you have (equipped or in bags), by name -------------------------------------------------
local SLOT_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulders", [5] = "Chest", [6] = "Waist", [7] = "Legs",
  [8] = "Feet", [9] = "Wrists", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket",
  [15] = "Back", [16] = "Main hand", [17] = "Off hand", [18] = "Ranged" }

function AD:Gear()
  local owned, slots = {}, {}
  for slot, label in pairs(SLOT_NAMES) do
    local id = plain(GetInventoryItemID("player", slot))
    local entry = { slot = slot, label = label }
    if id then
      local name = C_Item.GetItemNameByID(id)
      if name then owned[name] = true end
      entry.id, entry.name = id, name
      entry.quality = plain(GetInventoryItemQuality("player", slot))
      local link = GetInventoryItemLink("player", slot)
      if link and C_Item.GetDetailedItemLevelInfo then entry.ilvl = plain(C_Item.GetDetailedItemLevelInfo(link)) end
    end
    slots[slot] = entry
  end
  for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
    for s = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, s)
      local id = info and plain(info.itemID)
      local name = id and C_Item.GetItemNameByID(id)
      if name then owned[name] = true end
    end
  end
  return owned, slots
end

function AD:EmptyBagSlots()
  local empty = 0
  for bag = 1, (NUM_BAG_SLOTS or 4) do
    if (C_Container.GetContainerNumSlots(bag) or 0) == 0 then empty = empty + 1 end
  end
  return empty
end

-- Quest log titles (to say "it's already in your quest log") ------------------------------------
function AD:QuestTitles()
  local titles = {}
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      local t = info and not info.isHeader and plain(info.title)
      if t then titles[#titles + 1] = t end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() do
      local t, _, _, isHeader = GetQuestLogTitle(i)
      t = plain(t)
      if t and not isHeader then titles[#titles + 1] = t end
    end
  end
  return titles
end

local function inQuestLog(titles, text)
  for _, t in ipairs(titles) do
    if text:find(t, 1, true) then return true end
  end
  return false
end

-- Professions -----------------------------------------------------------------------------------
function AD:Professions()
  local list = {}
  if GetProfessions and GetProfessionInfo then
    local p1, p2, arch, fish, cook = GetProfessions()
    for _, idx in ipairs({ p1, p2 }) do
      if idx then
        local name, _, rank, maxRank = GetProfessionInfo(idx)
        name = plain(name)
        if name then list[#list + 1] = { name = name, rank = plain(rank) or 0, max = plain(maxRank) or 0 } end
      end
    end
    list.secondary = { fishing = fish ~= nil, cooking = cook ~= nil }
  elseif GetNumSkillLines and GetSkillLineInfo then
    local PRIMARY = { Mining = 1, Herbalism = 1, Skinning = 1, Alchemy = 1, Blacksmithing = 1, Enchanting = 1,
      Engineering = 1, Leatherworking = 1, Tailoring = 1 }
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
      if not isHeader and PRIMARY[name] then list[#list + 1] = { name = name, rank = rank or 0, max = maxRank or 0 } end
    end
  end
  return list
end

-- Talents (classic three-tree API; skipped quietly if the client has another system) --------------
function AD:Talents()
  local ranks, unspent, ok = {}, nil, false
  if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
    for tab = 1, GetNumTalentTabs() do
      for i = 1, GetNumTalents(tab) do
        local r = { pcall(GetTalentInfo, tab, i) }
        if r[1] and type(r[2]) == "string" then
          ranks[r[2]] = { rank = tonumber(r[6]) or 0, max = tonumber(r[7]) or 1 }
          ok = true
        end
      end
    end
  end
  if UnitCharacterPoints then
    local okp, pts = pcall(UnitCharacterPoints, "player")
    if okp and type(pts) == "number" then unspent = pts end
  end
  if unspent == nil and GetUnspentTalentPoints then
    local okp, pts = pcall(GetUnspentTalentPoints)
    if okp and type(pts) == "number" then unspent = pts end
  end
  return ok and ranks or nil, unspent
end

function AD:NextTalent(build, ranks, level)
  if not (build and build.talents and ranks) then return nil end
  for _, t in ipairs(build.talents) do
    local name, want, minLevel = t[1], t[2], t[3]
    local cur = ranks[name]
    if cur then
      local target = math.min(want or cur.max, cur.max)
      if cur.rank < target and (minLevel or 0) <= level then
        return name, cur.rank, target
      end
    end
  end
  return nil
end

-- Where your talent points should go: follows the build's order point by point from what you
-- have now. Builds that only name their key talents are taken lower tiers first, and a talent
-- is only picked once its tier is open (5 points per tier in that tree).
-- Returns { { name, add, tree, cur, target }, ... }, points left over (or nil without talent data).
function AD:SpendPlan(build, points, level)
  if not (build and build.talents and points and points > 0) then return nil end
  if not (GetNumTalentTabs and GetNumTalents and GetTalentInfo) then return nil end
  local where, spent, names = {}, {}, {}
  local okT, tabs = pcall(GetNumTalentTabs)
  for tab = 1, (okT and tonumber(tabs) or 0) do
    spent[tab] = 0
    if GetTalentTabInfo then
      local r = { pcall(GetTalentTabInfo, tab) }
      if r[1] and type(r[2]) == "string" then names[tab] = r[2] end
    end
    local okN, n = pcall(GetNumTalents, tab)
    for i = 1, (okN and tonumber(n) or 0) do
      local r = { pcall(GetTalentInfo, tab, i) }
      if r[1] and type(r[2]) == "string" then
        local rank = tonumber(r[6]) or 0
        where[r[2]] = { tab = tab, tier = tonumber(r[4]) or 1, rank = rank, max = tonumber(r[7]) or 1 }
        spent[tab] = spent[tab] + rank
      end
    end
  end
  if not next(where) then return nil end
  local list = {}
  for i, t in ipairs(build.talents) do list[i] = { t = t, i = i } end
  if build.keyOnly then
    table.sort(list, function(a, b)
      local wa, wb = where[a.t[1]], where[b.t[1]]
      local ta, tb = wa and wa.tier or 99, wb and wb.tier or 99
      if ta ~= tb then return ta < tb end
      return a.i < b.i
    end)
  end
  local rank, out, byName, left = {}, {}, {}, points
  for name, w in pairs(where) do rank[name] = w.rank end
  local progress = true
  while left > 0 and progress do
    progress = false
    for _, e in ipairs(list) do
      local name, want, minLevel = e.t[1], e.t[2], e.t[3]
      local w = where[name]
      if w and (minLevel or 0) <= (level or 60) then
        local target = math.min(want or w.max, w.max)
        if rank[name] < target and (spent[w.tab] or 0) >= (w.tier - 1) * 5 then
          local give = math.min(target - rank[name], left)
          local o = byName[name]
          if not o then
            o = { name = name, add = 0, tree = names[w.tab], cur = rank[name], target = target }
            byName[name] = o
            out[#out + 1] = o
          end
          o.add = o.add + give
          rank[name] = rank[name] + give
          spent[w.tab] = spent[w.tab] + give
          left = left - give
          progress = true
          break           -- start over from the top: a new tier may be open now
        end
      end
    end
  end
  return out, left
end

-- "Benediction +2 (Retribution)" for one entry of SpendPlan
function AD:SpendText(o, color)
  local s = (color and "|cffffd200" .. o.name .. "|r" or o.name) .. " +" .. o.add
  if o.tree then s = s .. " (" .. o.tree .. ")" end
  return s
end

-- open the game's Talents window (outside fights)
function AD:OpenTalents()
  if InCombatLockdown and InCombatLockdown() then return false end
  if FF.TalentOverlay and FF.TalentOverlay.Open then return FF.TalentOverlay:Open() end
  local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
  if not (_G.PlayerTalentFrame or _G.TalentFrame) and load then pcall(load, "Blizzard_TalentUI") end
  if type(ToggleTalentFrame) == "function" then pcall(ToggleTalentFrame) return true end
  return false
end

-- Leveling route (RouteData.lua; switch levelRoute) ------------------------------------------------
-- map IDs by zone name: the ones seen while playing first (any client, WoW: Forever's own zones),
-- then the usual IDs of the classic zones
local ROUTE_MAPS = {
  ["Elwynn Forest"] = 1429, ["Dun Morogh"] = 1426, ["Teldrassil"] = 1438, ["Durotar"] = 1411, ["Mulgore"] = 1412,
  ["Tirisfal Glades"] = 1420, ["Westfall"] = 1436, ["Loch Modan"] = 1432, ["Darkshore"] = 1439, ["The Barrens"] = 1413,
  ["Silverpine Forest"] = 1421, ["Redridge Mountains"] = 1433, ["Wetlands"] = 1437, ["Duskwood"] = 1431,
  ["Hillsbrad Foothills"] = 1424, ["Stonetalon Mountains"] = 1442, ["Ashenvale"] = 1440, ["Thousand Needles"] = 1441,
  ["Stranglethorn Vale"] = 1434, ["Tanaris"] = 1446, ["Feralas"] = 1444, ["Un'Goro Crater"] = 1449, ["Felwood"] = 1448,
  ["Burning Steppes"] = 1428, ["Winterspring"] = 1452, ["Eastern Plaguelands"] = 1423, ["Silithus"] = 1451,
  ["Orgrimmar"] = 1454, ["Stormwind City"] = 1453, ["Badlands"] = 1418, ["Desolace"] = 1443,
  ["Swamp of Sorrows"] = 1435, ["Searing Gorge"] = 1427,
}

function AD:ZoneMap(zone)
  if not zone then return nil end
  for id, name in pairs(FlipForeverDB.mapNames or {}) do
    if name == zone then return id end
  end
  return ROUTE_MAPS[zone]
end

-- the route step for this character (nil when the switch is off or there is no route data)
function AD:RouteStep(p)
  local R = FF.RouteData
  if not R or FlipForeverDB.settings.levelRoute == false or (p.level or 1) >= 60 then return nil end
  local _, token = UnitRace("player")
  local race = (token and R.START[plain(token)]) and plain(token) or p.race
  return R:Current(race, p.faction, p.level or 1)
end

-- arrow target of a step: { mapID, x, y, label } when its zone's map and the hub's spot are known
function AD:RouteTarget(step)
  local m = step and step[5] and self:ZoneMap(step[3])
  if not m then return nil end
  return { mapID = m, x = step[5] / 100, y = step[6] / 100, label = step[4] or step[3] }
end

-- remember the name of every map you are on (also used for the route's map lookup)
local function noteZone()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return end
  local m = plain(C_Map.GetBestMapForUnit("player"))
  local info = m and C_Map.GetMapInfo(m)
  local name = info and plain(info.name)
  if name then
    FlipForeverDB.mapNames = FlipForeverDB.mapNames or {}
    FlipForeverDB.mapNames[m] = name
  end
end
pcall(FF.On, FF, "ZONE_CHANGED_NEW_AREA", function() pcall(noteZone) end)

-- The recommendations ------------------------------------------------------------------------------
local ICON = {
  talent = "|TInterface\\Icons\\Ability_Marksmanship:14|t", quest = "|TInterface\\GossipFrame\\AvailableQuestIcon:14|t",
  gear = "|TInterface\\Icons\\INV_Sword_04:14|t", dungeon = "|TInterface\\Icons\\INV_Misc_Key_03:14|t",
  zone = "|TInterface\\Icons\\INV_Misc_Map_01:14|t", prof = "|TInterface\\Icons\\Trade_BlackSmithing:14|t",
  gold = "|TInterface\\Icons\\INV_Misc_Coin_01:14|t", bag = "|TInterface\\Icons\\INV_Misc_Bag_08:14|t",
  soon = "|TInterface\\Icons\\Spell_Holy_BorrowedTime:14|t", gather = "|TInterface\\Icons\\INV_Ore_Copper_01:14|t",
  trainer = "|TInterface\\Icons\\INV_Misc_Book_09:14|t",
}

local function factionOK(f, p) return f == nil or f == p.faction end

-- English plural "s"; other languages use a neutral form in their translation
local function S(n) if FF.TRANSLATIONS[FF:Language()] then return "" end return FF:Plural(n) end

function AD:Compute()
  local p = self:Player()
  local cd = self:ClassData(p)
  local build = self:Build(p)
  local recs = {}
  -- why each kind of step is suggested (shown when you hover the step)
  local src = build and G.SOURCES[build.source]
  local WHY = {
    talent = src and ("Talent order of your chosen build (" .. build.name .. "), from " .. src .. ".") or "Pick a build to get a talent order.",
    quest = "Class quests unlock spells or gear for your class at this level (" .. G.SOURCES.wiki .. ").",
    soon = "Coming up soon for your class or build, so you can plan for it.",
    gear = "An upgrade for a weak or empty slot at your level, with where it comes from.",
    dungeon = "Dungeons whose level range matches yours right now.",
    zone = "Questing zones that match your level and faction.",
    prof = src and ("Professions that suit your class, from " .. src .. ".") or "Professions that suit your class.",
    gold = "Gold milestones: mount at 40 (100g), dual spec (50g), riding at 60 (1,000g).",
    bag = "Counted from your bags right now.",
    gather = "Measured from your own gathering, valued at FlipForever's auction prices.",
  }
  local function add(prio, kind, text, why, target)
    recs[#recs + 1] = { prio = prio, kind = kind, text = ICON[kind] .. " " .. text, why = why or WHY[kind], target = target }
  end
  local L = p.level

  local known = self:KnownSpells()
  local owned, slots = self:Gear()
  local titles = self:QuestTitles()
  local profs = self:Professions()

  -- talents
  local ranks, unspent = self:Talents()
  local nextName, cur, target = self:NextTalent(build, ranks, L)
  local spend, free = nil, 0
  if unspent and unspent > 0 then spend, free = self:SpendPlan(build, unspent, L) end
  if spend and #spend > 0 then
    local parts, lines = {}, {}
    for k, o in ipairs(spend) do
      if k <= 3 then parts[#parts + 1] = self:SpendText(o, true) end
      lines[#lines + 1] = ("%d. %s (%d/%d)"):format(k, self:SpendText(o), o.cur + o.add, o.target)
    end
    if #spend > 3 then parts[#parts + 1] = FF:T("%d more"):format(#spend - 3) end
    if (free or 0) > 0 then
      lines[#lines + 1] = FF:T("%d point%s left that the build does not place yet - spend them where you like."):format(free, S(free))
    end
    add(100, "talent", FF:T("Spend %d talent point%s for %s: %s"):format(unspent, S(unspent), build.name, table.concat(parts, ", ")),
      FF:T("Where your points go, in the order of %s:"):format(build.name) .. "\n" .. table.concat(lines, "\n")
        .. "\n" .. FF:T("Click to open the Talents window."))
    recs[#recs].action = function() AD:OpenTalents() end
  elseif unspent and unspent > 0 then
    if nextName then
      add(100, "talent", FF:T("Spend %d talent point%s - next for %s: |cffffd200%s|r (%d/%d)"):format(unspent, S(unspent), build.name, nextName, cur, target))
    else
      add(100, "talent", FF:T("Spend %d talent point%s - follow %s (see Build details)"):format(unspent, S(unspent), build and build.name or "your build"))
    end
    recs[#recs].action = function() AD:OpenTalents() end
  elseif nextName then
    add(20, "talent", FF:T("Next talent for %s: %s (%d/%d)"):format(build.name, nextName, cur, target))
  end

  if cd then
    -- class quests that are due and not done yet
    for _, q in ipairs(cd.quests) do
      if factionOK(q.faction, p) and q.level <= L then
        local done = (q.done and known[q.done]) or false
        if q.items then for _, it in ipairs(q.items) do if owned[it] then done = true end end end
        if not done then
          -- where it starts, and the arrow if we know where that NPC stands
          local start = FF.QuestStarts and FF.QuestStarts:Find(p.class, q.text, p.faction, p.race)
          local why, target
          if start then
            why = ("Starts with %s (%s)%s."):format(start.npc, start.zone, start.after and (", " .. start.after) or "")
            local m, x, y = FF.QuestStarts:Locate(start)
            if m then
              target = { mapID = m, x = x, y = y, label = start.npc }
              why = why .. " Click to point the waypoint arrow there."
            end
          end
          -- already in the quest log: its next spot learned from your play (objective or hand-in) wins
          local QH = FF.QuestHelper
          if QH and QH:Enabled() and FlipForeverDB.settings.advisorQuestSpots ~= false then
            for _, lq in ipairs(QH:Log()) do
              if q.text:find(lq.title, 1, true) then
                local s = QH:Spot(lq)
                if s then
                  target = { mapID = s.m, x = s.x, y = s.y, label = s.label }
                  why = (why and (why .. " ") or "") .. FF:T("Next: %s (learned from your play). Click to point the waypoint arrow there."):format(s.label)
                end
                break
              end
            end
          end
          add(90, "quest", FF:T("Class quest (level %d): %s%s"):format(q.level, q.text, inQuestLog(titles, q.text) and " |cff33ff99- in your quest log|r" or "")
            .. (start and (" |cff888888- " .. start.npc:match("^[^/]+"):gsub("%s+$", "") .. "|r") or ""), why, target)
        end
      elseif factionOK(q.faction, p) and q.level <= L + 2 then
        add(30, "soon", FF:T("At level %d: %s"):format(q.level, q.text))
      end
    end

    -- weapon / gear upgrades from the build's list
    local profNames = {}
    for _, pr in ipairs(profs) do profNames[pr.name] = true end
    local picks = {}
    for _, g in ipairs(cd.gear) do
      local name, lvl, where, fac, needProf = g[1], g[2], g[3], g[4], g[5]
      if factionOK(fac, p) and lvl <= L + 2 and lvl >= L - 12 and not owned[name] then
        picks[#picks + 1] = { name = name, lvl = lvl, where = where, needProf = needProf, has = not needProf or profNames[needProf] }
      end
    end
    table.sort(picks, function(a, b) return a.lvl > b.lvl end)
    for i = 1, math.min(3, #picks) do
      local g = picks[i]
      local prof = g.needProf and (g.has and "" or (" |cffff8800(needs " .. g.needProf .. ")|r")) or ""
      add(80 - i, "gear", ("Get |cffa335ee%s|r (level %d) - %s%s"):format(g.name, g.lvl, g.where, prof))
    end
  end

  -- weak gear slots
  local weakSet = {}
  if L >= 12 then
    local weak = {}
    for _, s in pairs(slots) do
      if s.slot ~= 2 and s.slot ~= 11 and s.slot ~= 12 and s.slot ~= 13 and s.slot ~= 14 and s.slot ~= 17 and s.slot ~= 18 then
        local why
        if not s.id then why = "empty"
        elseif (s.quality or 2) <= 1 and L >= 15 then why = "white"
        elseif s.ilvl and s.ilvl < L - 12 then why = "old" end
        -- the weapon matters most, then outdated items, then empty slots
        if why then weakSet[s.label] = true end
        if why then weak[#weak + 1] = { order = (s.slot == 16 and 0 or (why == "empty" and 2 or 1)), text = s.label .. " (" .. why .. ")" } end
      end
    end
    if #weak > 0 then
      table.sort(weak, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.text < b.text end)
      local parts = {}
      for i = 1, math.min(5, #weak) do parts[i] = weak[i].text end
      add(60, "gear", FF:T("Weak slots: ") .. table.concat(parts, ", ") .. (#weak > 5 and (" +" .. (#weak - 5) .. " more") or "") .. " - quest greens, or check the auction house")
    end
  end

  -- dungeon and zone for your level
  local dungeons = {}
  for _, d in ipairs(G.DUNGEONS) do
    if factionOK(d[4], p) and L >= d[1] and L <= d[2] then dungeons[#dungeons + 1] = d[3] end
  end
  -- dungeon advisor (DungeonData.lua; switch dungeonAdvisor): the dungeon with the most upgrades for your weak slots
  local DD = FF.DungeonData
  local best, hits, bestSlots
  if DD and FlipForeverDB.settings.dungeonAdvisor ~= false then
    best, hits, bestSlots = DD:Best(L, p.faction, p.class, weakSet)
  end
  if best then
    local lines = { "Upgrades for your weak slots in " .. best[1] .. " (level " .. best[2] .. "-" .. best[3] .. "):" }
    for _, s in ipairs(bestSlots) do lines[#lines + 1] = s .. ": " .. table.concat(hits[s], ", ") end
    lines[#lines + 1] = "Entrance: " .. best[5] .. ". Click to point the arrow there."
    local m = self:ZoneMap(best[5])
    local target = m and { mapID = m, x = best[6] / 100, y = best[7] / 100, label = best[1] } or nil
    add(50, "dungeon", ("Dungeon for upgrades: %s - %s (entrance: %s)"):format(best[1], table.concat(bestSlots, ", "), best[5]),
      table.concat(lines, "\n"), target)
  elseif #dungeons > 0 then
    add(50, "dungeon", FF:T("Dungeons for your level: ") .. table.concat(dungeons, ", ", 1, math.min(3, #dungeons)))
  end
  local zones = {}
  for _, list in ipairs({ G.ZONES[p.faction] or {}, G.ZONES.Both }) do
    for _, z in ipairs(list) do
      if L >= z[1] and L <= z[2] then zones[#zones + 1] = z[3] end
    end
  end
  local step = self:RouteStep(p)
  if step then
    local where = step[3] and (step[4] and (step[4] .. ", " .. step[3]) or step[3])
    local target = self:RouteTarget(step)
    -- a step with a zone: "Route: hub, zone" and its text below; without one, the text is the line
    local why = where and (step[7] .. (target and (" " .. FF:T("Click to point the waypoint arrow there.")) or "")) or nil
    local head = L < step[1] and FF:T("Route from level %d: %s"):format(step[1], where or step[7])
      or FF:T("Route (level %d-%d): %s"):format(step[1], step[2], where or step[7])
    add(46, "zone", head, why, target)
  elseif #zones > 0 then add(45, "zone", FF:T("Level in: ") .. zones[1] .. (zones[2] and (" (or " .. zones[2] .. ")") or "")) end

  -- professions
  if #profs < 2 and cd then
    local missing = {}
    for _, name in ipairs(cd.professions) do
      local have = false
      for _, pr in ipairs(profs) do if pr.name == name then have = true end end
      if not have then missing[#missing + 1] = name end
    end
    if #missing > 0 then
      add(55, "prof", FF:T("Learn %s - suits your class (%s)"):format(table.concat(missing, " + "), cd.profNote))
    end
  end
  -- the profession planner's cheapest next skill-up, for each profession it has read
  if FF.Professions then
    for name in pairs(FF.Professions:Store()) do
      local ok, step = pcall(FF.Professions.TopStep, FF.Professions, name)
      if ok and step then add(40, "prof", step .. " - Professions planner",
        "The cheapest next skill-up from the Professions planner, priced with your auction scans.") end
    end
    -- the best affordable gear upgrade on the auction house (GearFinder.lua)
    local gstep = FF.Gear and FF.Gear:TopStep()
    if gstep then
      add(75, "gear", gstep .. " - FlipForever window, Gear tab",
        "Better than what you wear in that slot for your class's stats, usable at your level, and within a quarter of your gold.")
    end
    -- the most profitable craft across all professions you've opened
    local okP, profit = pcall(FF.Professions.ProfitList, FF.Professions)
    local best = okP and profit and profit[1]
    if best then
      add(38, "prof", FF:T("Craft for profit: %dx %s, about +%s each - Professions planner, profit view"):format(
        best.crafts, best.recipe.name, FF:Money(best.profit)),
        "Sells for more than its materials after the AH cut and deposit, and sells at least 3 a day.")
    end
  end
  for _, pr in ipairs(profs) do
    if (pr.name == "Mining" or pr.name == "Herbalism") and ns and ns.db and not ns.skipGather then
      -- your best measured zone (gold per hour of actual farming there, at your skill, at FlipForever prices)
      local bestMap, bestRate = nil, 0
      if ns.ZoneRate then
        for mapID in pairs(ns.db.zoneStats or {}) do
          local rate = ns.ZoneRate(mapID)
          if rate and rate > bestRate then bestMap, bestRate = mapID, rate end
        end
      end
      if bestMap then
        local zoneName = ns.MapName and ns.MapName(bestMap) or ("map " .. bestMap)
        add(25, "gather", FF:T("Best farming zone so far: |cffffd200%s|r, about %s/hour from your own runs - open Gathering to plan a loop"):format(
          zoneName, FF:Money(math.floor(bestRate))))
      else
        add(25, "gather", FF:T("%s %d: open Gathering to plan a farming loop here (farm 10+ min in a zone to learn its gold/hour)"):format(pr.name, pr.rank))
      end
      break
    end
  end

  -- class trainer: spells you can learn now (known from your last visit to the trainer)
  if FF.Trainer and FF.Trainer:Enabled() then
    local due, cost = FF.Trainer:Due(L)
    if #due > 0 then
      add(80, "trainer", FF:T("New at your class trainer: %d spell%s for %s"):format(#due, S(#due), FF:Money(cost)), FF.Trainer:Why(due))
    end
  end

  -- bags
  local emptyBags = self:EmptyBagSlots()
  if emptyBags > 0 then
    add(70, "bag", FF:T("%d empty bag slot%s - buy or craft bags (starting zones give a free 6-slot bag around level 7)"):format(emptyBags, S(emptyBags)))
  end

  -- gold milestones
  for _, m in ipairs(G.MILESTONES) do
    local done = m.done and known[m.done]
    if not done and L >= m.level - 8 then
      local have = p.money / 10000
      if L >= m.level and have >= m.gold then
        add(85, "gold", FF:T("You can afford it now: %s - visit the trainer"):format(m.text))
      elseif L >= m.level then
        add(65, "gold", FF:T("Save up: %s - you have %dg of %dg"):format(m.text, math.floor(have), m.gold))
      else
        add(35, "gold", FF:T("Start saving for level %d: %s - you have %dg"):format(m.level, m.text, math.floor(have)))
      end
    end
  end

  -- next power spike
  if cd then
    for _, s in ipairs(cd.spikes) do
      if s[1] > L then
        add(15, "soon", FF:T("Next power spike at level %d: %s"):format(s[1], s[2]))
        break
      end
    end
  end

  table.sort(recs, function(a, b) return a.prio > b.prio end)
  return recs, p, cd, build
end

-- Snapshot for the desktop app ---------------------------------------------------------------------
function AD:Save(recs, p, build)
  local store = self:CharStore()
  local lines = {}
  for i = 1, math.min(12, #recs) do
    lines[i] = recs[i].text:gsub("|T.-|t%s*", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  end
  -- the gear finder's and the crafting finder's top picks, for the app
  local gear, crafts = {}, {}
  for i, r in ipairs(FF.Gear and FF.Gear.results or {}) do
    if i > 5 then break end
    gear[i] = { name = r.name, slot = FF.Gear.SLOT_NAMES[r.slot], price = r.price, pct = r.pct and math.floor(r.pct * 100 + 0.5) or nil }
  end
  local okP, list = pcall(FF.Professions.ProfitList, FF.Professions)
  for i, e in ipairs(okP and list or {}) do
    if i > 5 then break end
    crafts[i] = { name = e.recipe.name, prof = e.prof, crafts = e.crafts, profit = math.floor(e.profit), perDay = math.floor(e.perDay * 10 + 0.5) / 10 }
  end
  -- your auctions as last checked at the auction house (Auctions.lua), kept until the next check
  local A = FF.Auctions
  if A and A.owned then
    local under = {}
    for i, u in ipairs(A.undercut or {}) do
      if i > 5 then break end
      under[i] = { name = u.name, mine = u.mine, now = u.now, qty = u.qty }
    end
    store.auctions = { t = A.checked or time(), up = A.owned, undercut = under, n = #(A.undercut or {}) }
  end
  store.advisor = { t = time(), level = p.level, race = p.race, class = p.class, className = p.className,
    build = build and build.name or nil, source = build and G.SOURCES[build.source] or nil, steps = lines,
    gear = gear, crafts = crafts, auctions = store.auctions }
  store.level, store.race, store.class = p.level, p.race, p.class
end

-- Window ----------------------------------------------------------------------------------------------
local frame
local ROWS = 14

local function makeFrame()
  local f = FF:Window("FlipForeverAdvisor", 470, 470, { pos = "advisorPos", default = { "CENTER", 0, 60 } })
  local close = f.close

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOPLEFT", 14, -12)
  f.who = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.who:SetPoint("TOPLEFT", 14, -36)
  f.who:SetPoint("RIGHT", -14, 0)
  f.who:SetJustifyH("LEFT")

  local prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  prev:SetSize(26, 22)
  prev:SetPoint("TOPLEFT", 14, -58)
  prev:SetText(FF:T("<"))
  prev:SetScript("OnClick", function() AD:CycleBuild(-1) end)
  local nxt = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  nxt:SetSize(26, 22)
  nxt:SetPoint("LEFT", prev, "RIGHT", 4, 0)
  nxt:SetText(FF:T(">"))
  nxt:SetScript("OnClick", function() AD:CycleBuild(1) end)
  f.build = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.build:SetPoint("LEFT", nxt, "RIGHT", 8, 0)
  f.build:SetPoint("RIGHT", f, "RIGHT", -14, 0)
  f.build:SetJustifyH("LEFT")
  f.source = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.source:SetPoint("TOPLEFT", 14, -84)
  f.source:SetPoint("RIGHT", -14, 0)
  f.source:SetJustifyH("LEFT")

  f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.header:SetPoint("TOPLEFT", 14, -104)
  f.header:SetText(FF:T("Do this next:"))

  f.rows = {}
  for i = 1, ROWS do
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 16, -104 - i * 22)
    fs:SetPoint("RIGHT", -14, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    f.rows[i] = fs
    -- hover a step to see the full text and why it's suggested
    local hit = CreateFrame("Frame", nil, f)
    hit:SetPoint("TOPLEFT", fs, "TOPLEFT", -2, 3)
    hit:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 2, -3)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(self)
      local r = f.recs and f.recs[i]
      if not (r and fs:IsShown()) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(r.text, 1, 1, 1, true)
      if r.why then GameTooltip:AddLine(r.why, 0.6, 0.8, 1, true) end
      local QH = FF.QuestHelper
      if r.target and QH and QH:PinsEnabled() then
        local t = r.target
        GameTooltip:AddLine(QH:IsPinned(t.mapID, t.x, t.y, t.label) and FF:T("Pinned on the map. Right-click: remove.")
          or FF:T("Right-click: pin on the map and minimap."), 0.6, 0.6, 0.6, true)
      end
      GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- click a step that has a place (a quest giver you've met): the waypoint arrow points there
    hit:SetScript("OnMouseUp", function(_, button)
      local r = f.recs and f.recs[i]
      local QH = FF.QuestHelper
      if button == "RightButton" then
        -- right-click a step that has a place: pin it on the world map and minimap
        if r and r.target and QH and QH:PinsEnabled() then
          local t = r.target
          QH:TogglePin(t.mapID, t.x, t.y, t.label, r.text)
          if GameTooltip then GameTooltip:Hide() end
        end
        return
      end
      if r and r.action then r.action() return end
      if r and r.target and FF.Arrow then FF.Arrow:SetTarget(r.target.mapID, r.target.x, r.target.y, r.target.label) end
    end)
    fs.hit = hit
  end

  -- details page (talent order, stats, professions, gear list, sources)
  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 14, -104)
  scroll:SetPoint("BOTTOMRIGHT", -34, 44)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(410, 10)
  scroll:SetScrollChild(content)
  f.detailText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.detailText:SetPoint("TOPLEFT")
  f.detailText:SetWidth(410)
  f.detailText:SetJustifyH("LEFT")
  f.detailText:SetSpacing(3)
  f.detailContent = content
  f.scroll = scroll
  scroll:Hide()

  local details = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  details:SetSize(130, 24)
  details:SetPoint("BOTTOMLEFT", 14, 12)
  details:SetText(FF:T("Build details"))
  details:SetScript("OnClick", function()
    f.showDetails = not f.showDetails
    details:SetText(f.showDetails and "Next steps" or "Build details")
    AD:Refresh()
  end)
  local refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  refresh:SetSize(100, 24)
  refresh:SetPoint("LEFT", details, "RIGHT", 6, 0)
  refresh:SetText(FF:T("Re-check"))
  refresh:SetScript("OnClick", function() AD:Refresh() end)
  local settings = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  settings:SetSize(80, 22)
  settings:SetPoint("TOPRIGHT", -30, -10)
  settings:SetText(FF:T("Settings"))
  settings:SetScript("OnClick", function() FF.Hub:Show("settings") end)
  -- shown while steps are pinned on the map (right-click a step)
  f.clearPins = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.clearPins:SetSize(80, 22)
  f.clearPins:SetPoint("RIGHT", settings, "LEFT", -4, 0)
  f.clearPins:SetText(FF:T("Clear pins"))
  f.clearPins:SetScript("OnClick", function()
    local QH = FF.QuestHelper
    if QH then wipe(QH:PinStore()) QH:RefreshAll() end
    FF:Print(FF:T("Map pins cleared."))
    AD:Refresh()
  end)
  -- controller: bigger click areas for the gamepad cursor
  FF:PadFriendly(prev, nxt, details, refresh, settings, f.clearPins)
  f.clearPins:Hide()
  local auto = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  auto:SetSize(22, 22)
  auto:SetPoint("LEFT", refresh, "RIGHT", 10, 0)
  auto.text = auto:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  auto.text:SetPoint("LEFT", auto, "RIGHT", 2, 0)
  auto.text:SetText(FF:T("Pop up on level-up"))
  auto:SetScript("OnClick", function(self) FlipForeverDB.settings.advisorPopup = self:GetChecked() and true or false end)
  f.auto = auto
  local combat = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  combat:SetSize(22, 22)
  combat:SetPoint("BOTTOMRIGHT", -120, 36)
  combat.text = combat:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  combat.text:SetPoint("LEFT", combat, "RIGHT", 2, 0)
  combat.text:SetText(FF:T("Combat helper"))
  combat:SetScript("OnClick", function(self)
    FF.Combat:Toggle()
    self:SetChecked(FF.Combat:Enabled())
  end)
  f.combat = combat
  f:Hide()
  return f
end

local function detailsText(p, cd, build)
  if not cd then return "No guide data for your class yet." end
  local out = {}
  local function line(s) out[#out + 1] = s end
  line("|cffffd200" .. build.name .. "|r  -  " .. (G.SOURCES[build.source] or ""))
  local ROLE = { leveling = "Leveling", dps = "Damage (dungeons and raids)", tank = "Tank", healer = "Healer", pvp = "PvP" }
  if build.role or build.points then
    line(((build.role and ROLE[build.role]) or "") .. (build.points and ("   |cff888888points " .. build.points .. "|r") or ""))
  end
  if build.note then line(build.note) end
  if build.rotation then line("|cffffd200Rotation|r  " .. build.rotation) end
  line(" ")
  line(build.keyOnly and "|cffffd200Key talents|r |cff888888(the guide gives no pick order)|r" or "|cffffd200Talent order|r")
  if build.talents then
    for i, t in ipairs(build.talents) do
      line(("%d. %s%s%s"):format(i, t[1], t[2] and (" " .. t[2] .. " pts") or "", t[3] and (" (from level " .. t[3] .. ")") or ""))
    end
  else
    line("This guide shows its talents only as a picture - follow it on the guide's page.")
  end
  -- the talent for every level of this build (Talents window: By level)
  local TO = FF.TalentOverlay
  if build.talents and TO and TO:LevelsEnabled() then
    local ok, levels = pcall(function() return TO:LevelPlan(build, TO:Plan(build, p.level), p.level) end)
    if ok and levels and #levels > 0 then
      line(" ")
      line("|cffffd200By level|r |cff888888(one point per level from 10)|r")
      for _, l in ipairs(TO:LevelRanges(levels)) do line(l) end
    end
  end
  line(" ")
  line("|cffffd200Stats|r  " .. (build.stats or cd.stats))
  line("|cffffd200Professions|r  " .. table.concat(cd.professions, " + ") .. ". " .. cd.profNote)
  line(" ")
  line("|cffffd200Class quests|r")
  for _, q in ipairs(cd.quests) do
    if factionOK(q.faction, p) then line(("L%d  %s"):format(q.level, q.text)) end
  end
  if #cd.quests == 0 then line("none listed in the guides") end
  local _, i, route = AD:RouteStep(p)
  if route then
    line(" ")
    line("|cffffd200Leveling route|r")
    for k = i, math.min(i + 3, #route) do
      local s = route[k]
      line(("L%d-%d  %s"):format(s[1], s[2], s[3] and ((s[4] and (s[4] .. ", ") or "") .. s[3]) or s[7]))
    end
  end
  line(" ")
  line("|cffffd200Gear to hunt|r")
  for _, g in ipairs(cd.gear) do
    if factionOK(g[4], p) then line(("L%d  %s - %s"):format(g[2], g[1], g[3])) end
  end
  line(" ")
  line("|cffffd200Power spikes|r")
  for _, s in ipairs(cd.spikes) do line(("L%d  %s"):format(s[1], s[2])) end
  line(" ")
  for _, tip in ipairs(G.PROF_TIPS) do line(tip) end
  return table.concat(out, "\n")
end

function AD:Refresh()
  local ok, recs, p, cd, build = pcall(self.Compute, self)
  if not ok then
    FF:Print(FF:T("|cffff5555advisor error:|r ") .. tostring(recs))
    FF:RecordError("advisor", recs)
    return
  end
  pcall(self.Save, self, recs, p, build)
  self.last = recs
  if not (frame and frame:IsShown()) then return end
  frame.title:SetText(FF:T("|cff33ff99Flip|rForever Advisor"))
  local raceTip = ""
  for key, tip in pairs(G.RACES) do
    if p.race:find(key, 1, true) then raceTip = "  |cffaaaaaa" .. tip .. "|r" end
  end
  frame.who:SetText(FF:T("%s - level %d %s %s (%s)%s"):format(p.name or "?", p.level, p.race, p.className, p.faction, raceTip))
  if build then
    local cdBuilds = cd and #cd.builds or 1
    frame.build:SetText(FF:T("Following: |cffffd200%s|r  (%d option%s)"):format(build.name, cdBuilds, FF:Plural(cdBuilds)))
    frame.source:SetText(FF:T("Source: ") .. (G.SOURCES[build.source] or "?"))
  else
    frame.build:SetText(FF:T("No guide data for this class"))
    frame.source:SetText(FF:T(""))
  end
  frame.auto:SetChecked(FlipForeverDB.settings.advisorPopup ~= false)
  if FF.Combat then frame.combat:SetChecked(FF.Combat:Enabled()) end
  if frame.showDetails then
    for _, fs in ipairs(frame.rows) do fs:Hide() end
    frame.header:Hide()
    frame.detailText:SetText(detailsText(p, cd, build))
    frame.detailContent:SetHeight((frame.detailText:GetStringHeight() or 0) + 10)
    frame.scroll:Show()
  else
    frame.scroll:Hide()
    frame.header:Show()
    frame.recs = recs
    local QH = FF.QuestHelper
    local pinsOn = QH and QH:PinsEnabled()
    for i, fs in ipairs(frame.rows) do
      local r = recs[i]
      local t = r and r.target
      local pinned = pinsOn and t and QH:IsPinned(t.mapID, t.x, t.y, t.label)
      fs:SetText(r and ((pinned and "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12|t " or "") .. r.text) or "")
      fs:Show()
    end
  end
  if frame.clearPins then
    local QH = FF.QuestHelper
    if QH and QH:PinsEnabled() and #QH:PinStore() > 0 then frame.clearPins:Show() else frame.clearPins:Hide() end
  end
end

-- opening the window: any error is shown and kept for bug reports instead of failing silently
local function open(toggle)
  local ok, err = pcall(function()
    frame = frame or makeFrame()
    if toggle and frame:IsShown() then frame:Hide() return end
    frame:Show()
    AD:Refresh()
  end)
  if not ok then
    FF:Print("|cffff5555advisor error:|r " .. tostring(err))
    FF:RecordError("advisor window", err)
  end
end

function AD:Toggle() open(true) end
function AD:Show() open(false) end

-- Re-check whenever something relevant changes (debounced) ----------------------------------------
local pending = false
local function schedule()
  if pending then return end
  pending = true
  C_Timer.After(1, function()
    pending = false
    AD:Refresh()
  end)
end

for _, ev in ipairs({ "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "PLAYER_EQUIPMENT_CHANGED", "CHARACTER_POINTS_CHANGED",
  "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "ZONE_CHANGED_NEW_AREA", "PLAYER_MONEY",
  "QUEST_ACCEPTED" }) do
  pcall(FF.On, FF, ev, schedule)
end

FF:On("PLAYER_LEVEL_UP", function(level)
  C_Timer.After(2, function()
    AD:Refresh()
    local recs = AD.last or {}
    FF:Print(FF:T("|cffffd200Level %s!|r Next steps:"):format(tostring(level)))
    for i = 1, math.min(3, #recs) do print("   " .. recs[i].text) end
    if FlipForeverDB.settings.advisorPopup ~= false and not InCombatLockdown() then AD:Show() end
  end)
end)

-- Zone names for the desktop app's Gathering tab (the gathering data only stores map numbers)
local function saveMapNames()
  local db = rawget(_G, "OreFarmerDB")
  if not (db and C_Map and C_Map.GetMapInfo) then return end
  FlipForeverDB.mapNames = FlipForeverDB.mapNames or {}
  for _, list in ipairs({ db.zoneStats or {}, db.nodes or {} }) do
    for mapID in pairs(list) do
      local info = C_Map.GetMapInfo(mapID)
      local name = info and plain(info.name)
      if name then FlipForeverDB.mapNames[mapID] = name end
    end
  end
end

FF:On("PLAYER_LOGOUT", function() pcall(saveMapNames) end)

FF:On("PLAYER_LOGIN", function()
  C_Timer.After(4, function() AD:Refresh() pcall(saveMapNames) end)
end)

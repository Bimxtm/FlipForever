-- Where class quests start, and where NPCs stand.
-- Start NPCs and zones are from Warcraft Wiki quest pages (classic-era quests used by WoW: Forever).
-- Map positions: the addon remembers where every NPC you talk to stands (you're next to them when
-- a quest or gossip window opens), so a quest giver you've met once can get the waypoint arrow.
local FF = FlipForever
local Q = {}
FF.QuestStarts = Q

-- match: part of the Advisor's quest text. Per faction (or "Both"), optionally per race.
Q.DATA = {
  WARRIOR = {
    { match = "Defensive Stance",
      races = {
        Human = { npc = "Bartleby", zone = "Stormwind" },
        ["Night Elf"] = { npc = "Vorlus Vilehoof", zone = "Darnassus" },
        Dwarf = { npc = "Muren Stormpike", zone = "Dun Morogh", after = "then Vejrek (level 11)" },
        Undead = { npc = "Ulag the Cleaver", zone = "Tirisfal Glades" },
      },
      Horde = { npc = "Sorek / Krang Stonehoof / Tarshaw Jaggedscar", zone = "Orgrimmar, Thunder Bluff or the Barrens",
      after = "then Uzzek near Far Watch Post (the Barrens)" } },
    { match = "Berserker Stance", Alliance = { npc = "Wu Shen / Kelv Sternhammer", zone = "Stormwind or Ironforge" },
      Horde = { npc = "Baltus Fowler / Torm Ragetotem / Sorek", zone = "Undercity, Thunder Bluff or Orgrimmar" } },
    { match = "Whirlwind Axe", Both = { npc = "Bath'rah the Windwatcher", zone = "Alterac Mountains" } },
  },
  PALADIN = {
    { match = "Redemption", Alliance = { npc = "Brother Wilhelm / Azar Stronghammer / Brandur Ironhammer / Lord Grayson Shadowbreaker",
      zone = "Elwynn Forest, Dun Morogh, Ironforge or Stormwind" } },
    { match = "Test of Righteousness", Alliance = { npc = "Duthorian Rall", zone = "Stormwind", after = "then Jordan Stilwell in Ironforge" } },
  },
  ROGUE = {
    { match = "Blade of Cunning", races = {
        Human = { npc = "Master Mathias Shaw", zone = "Stormwind" },
        Dwarf = { npc = "Onin MacHammar", zone = "Ironforge", after = "then Hulfdan Blackbeard" },
        Gnome = { npc = "Onin MacHammar", zone = "Ironforge", after = "then Hulfdan Blackbeard" },
        ["Night Elf"] = { npc = "Syurna", zone = "Teldrassil" },
        Orc = { npc = "Kaplak", zone = "Orgrimmar (Cleft of Shadow)", after = "then Therzok" },
        Troll = { npc = "Kaplak", zone = "Orgrimmar (Cleft of Shadow)", after = "then Therzok" },
        Undead = { npc = "Marion Call", zone = "Undercity (Rogues' Quarter)", after = "then Mennet Carkad" } } },
  },
  WARLOCK = {
    { match = "Voidwalker", races = {
        Human = { npc = "Remen Marcot", zone = "Stormwind", after = "then Gakin the Darkbinder (Mage Quarter)" },
        Gnome = { npc = "Remen Marcot", zone = "Stormwind", after = "then Gakin the Darkbinder (Mage Quarter)" },
        Orc = { npc = "Ophek", zone = "Orgrimmar", after = "then Gan'rul Bloodeye" },
        Troll = { npc = "Ophek", zone = "Orgrimmar", after = "then Gan'rul Bloodeye" },
        Undead = { npc = "Ageron Kargal", zone = "Undercity", after = "then Carendin Halgar" } } },
    { match = "Succubus", Alliance = { npc = "Lago Blackwrench", zone = "Stormwind", after = "then Gakin the Darkbinder" },
      races = {
        Orc = { npc = "Gan'rul Bloodeye", zone = "Orgrimmar", after = "then Cazul (Cleft of Shadow)" },
        Troll = { npc = "Gan'rul Bloodeye", zone = "Orgrimmar", after = "then Cazul (Cleft of Shadow)" },
        Undead = { npc = "Carendin Halgar", zone = "Undercity", after = "then Godrick Farsan" } } },
    { match = "Soran'ruk", Both = { npc = "Doan Karhan", zone = "the Barrens" } },
    { match = "Felhunter", Alliance = { npc = "Gakin the Darkbinder", zone = "Stormwind (Mage Quarter)" },
      races = {
        Orc = { npc = "Gan'rul Bloodeye", zone = "Orgrimmar" }, Troll = { npc = "Gan'rul Bloodeye", zone = "Orgrimmar" },
        Undead = { npc = "Carendin Halgar", zone = "Undercity" } } },
    { match = "Felsteed", races = {
        Human = { npc = "Demisette Cloyce", zone = "Stormwind" }, Gnome = { npc = "Briarthorn", zone = "Ironforge" },
        Orc = { npc = "Zevrost", zone = "Orgrimmar" }, Troll = { npc = "Zevrost", zone = "Orgrimmar" },
        Undead = { npc = "Kaal Soulreaper", zone = "Undercity" } } },
  },
  HUNTER = {
    { match = "Taming the Beast",
      races = {
        Dwarf = { npc = "Grif Wildheart", zone = "Dun Morogh (near Kharanos)" },
        ["Night Elf"] = { npc = "Dazalar", zone = "Teldrassil (Dolanaar)", map = 1438, x = 56.7, y = 59.5 },
        Orc = { npc = "Thotar", zone = "Durotar (near Razor Hill)" },
        Troll = { npc = "Thotar", zone = "Durotar (near Razor Hill)" },
        Tauren = { npc = "Yaw Sharpmane", zone = "Mulgore (near Bloodhoof Village)" },
      } },
  },
  SHAMAN = {
    { match = "Call of Water", races = {
        Orc = { npc = "Swart", zone = "Durotar", after = "then Islen Waterseer in the Barrens" },
        Troll = { npc = "Swart", zone = "Durotar", after = "then Islen Waterseer in the Barrens" },
        Tauren = { npc = "Xanis Flameweaver", zone = "Thunder Bluff" } } },
    { match = "Call of Air", races = {
        Orc = { npc = "Searn Firewarder", zone = "Orgrimmar", after = "then Prate Cloudseer in Thousand Needles" },
        Troll = { npc = "Searn Firewarder", zone = "Orgrimmar", after = "then Prate Cloudseer in Thousand Needles" },
        Tauren = { npc = "Xanis Flameweaver", zone = "Thunder Bluff", after = "then Prate Cloudseer in Thousand Needles" } } },
  },
  DRUID = {
    { match = "Bear Form", Alliance = { npc = "Denatharion / Kal", zone = "Darnassus or Dolanaar (Teldrassil)", after = "then Mathrengyl Bearwalker" },
      Horde = { npc = "Gennia Runetotem", zone = "Bloodhoof Village (Mulgore)", after = "then Turak Runetotem" } },
    { match = "Cure Poison", Alliance = { npc = "Mathrengyl Bearwalker", zone = "Darnassus", after = "then Dendrite Starblaze in Moonglade" },
      Horde = { npc = "Turak Runetotem", zone = "Thunder Bluff", after = "then Dendrite Starblaze in Moonglade" } },
    { match = "Aquatic Form", Alliance = { npc = "Mathrengyl Bearwalker", zone = "Darnassus", after = "then Dendrite Starblaze in Moonglade" },
      Horde = { npc = "Turak Runetotem", zone = "Thunder Bluff", after = "then Dendrite Starblaze in Moonglade" } },
  },
}

-- where a class quest starts for this character: { npc, zone, after, map, x, y } or nil
function Q:Find(class, text, faction, race)
  for _, e in ipairs(Q.DATA[class] or {}) do
    if text and text:find(e.match, 1, true) then
      -- race-specific start first, then the faction's, then one for everyone
      return (e.races and e.races[race]) or e[faction] or e.Both
    end
  end
  return nil
end

-- NPC positions you've seen ---------------------------------------------------------------------
function Q:Positions()
  FlipForeverDB.npcPos = FlipForeverDB.npcPos or {}
  return FlipForeverDB.npcPos
end

function Q:Remember(name)
  if not name or name == "" or not (FF.Arrow and FF.Arrow.PlayerPos) then return end
  local mapID, x, y = FF.Arrow.PlayerPos()
  if mapID and x and y then self:Positions()[name] = { m = mapID, x = x, y = y, t = time() } end
end

-- a map position for a start entry: the guide's, else any of its NPCs you've met
function Q:Locate(start)
  if not start then return nil end
  if start.map and start.x then return start.map, start.x / 100, start.y / 100 end
  local known = self:Positions()
  for name in (start.npc or ""):gmatch("[^/]+") do
    local p = known[(name:gsub("^%s+", ""):gsub("%s+$", ""))]
    if p then return p.m, p.x, p.y end
  end
  return nil
end

local function remember()
  local name = UnitName and UnitName("npc")
  if issecretvalue and name ~= nil and issecretvalue(name) then return end
  Q:Remember(name)
end
for _, ev in ipairs({ "QUEST_DETAIL", "QUEST_GREETING", "QUEST_PROGRESS", "GOSSIP_SHOW" }) do
  pcall(FF.On, FF, ev, remember)
end

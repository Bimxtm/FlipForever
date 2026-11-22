-- Leveling route: one step per town or camp, by start area, then faction, then shared from 30 on.
-- Written for FlipForever from the zone list in GuideData (G.ZONES) and general zone knowledge.
-- Step: { from, to, zone, hub, x, y, text, faction = optional "Alliance" | "Horde" }
--   x, y: the hub on the zone map (0-100), nil when not known yet (learned as you play).
--   zone nil: a choice of zones, no arrow.
-- Map IDs are found by zone name at run time, so WoW: Forever's own zones work too.
local FF = FlipForever
local R = {}
FF.RouteData = R

-- start area by race (Skyborne start on Zephras Isle)
R.START = {
  Human = "elwynn", Dwarf = "dunmorogh", Gnome = "dunmorogh", ["Night Elf"] = "teldrassil", NightElf = "teldrassil",
  Orc = "durotar", Troll = "durotar", Tauren = "mulgore", Undead = "tirisfal", Scourge = "tirisfal",
  Skyborne = "zephras",
}

R.LEGS = {
  elwynn = {
    { 1, 5, "Elwynn Forest", "Northshire Abbey", 48, 42, "Do the abbey quests, then walk south to Goldshire." },
    { 5, 11, "Elwynn Forest", "Goldshire", 42, 65, "Quests around Goldshire and eastern Elwynn; set your hearth at the inn." },
    { 11, 17, "Westfall", "Sentinel Hill", 56, 47, "Take the quests at Sentinel Hill and grab the flight path." },
  },
  dunmorogh = {
    { 1, 5, "Dun Morogh", "Coldridge Valley", 28, 69, "Do the valley quests, then go through the tunnel to Kharanos." },
    { 5, 11, "Dun Morogh", "Kharanos", 46, 52, "Quests around Kharanos; set your hearth at the inn." },
    { 11, 17, "Loch Modan", "Thelsamar", 35, 47, "Take the quests in Thelsamar and grab the flight path." },
  },
  teldrassil = {
    { 1, 5, "Teldrassil", "Shadowglen", 58, 44, "Do the Shadowglen quests, then follow the road to Dolanaar." },
    { 5, 11, "Teldrassil", "Dolanaar", 56, 59, "Quests around Dolanaar; set your hearth at the inn." },
    { 11, 17, "Darkshore", "Auberdine", 37, 44, "Take the boat from Rut'theran Village; quests in Auberdine." },
  },
  durotar = {
    { 1, 5, "Durotar", "Valley of Trials", 43, 68, "Do the valley quests, then walk north to Razor Hill." },
    { 5, 11, "Durotar", "Razor Hill", 52, 43, "Quests around Razor Hill; set your hearth at the inn." },
    { 11, 17, "The Barrens", "The Crossroads", 52, 30, "Take the quests at the Crossroads and grab the flight path." },
  },
  mulgore = {
    { 1, 5, "Mulgore", "Camp Narache", 44, 77, "Do the camp quests, then follow the road to Bloodhoof Village." },
    { 5, 11, "Mulgore", "Bloodhoof Village", 47, 58, "Quests around Bloodhoof Village; set your hearth at the inn." },
    { 11, 17, "The Barrens", "The Crossroads", 52, 30, "Take the quests at the Crossroads and grab the flight path." },
  },
  tirisfal = {
    { 1, 5, "Tirisfal Glades", "Deathknell", 32, 65, "Do the Deathknell quests, then follow the road east to Brill." },
    { 5, 11, "Tirisfal Glades", "Brill", 61, 52, "Quests around Brill; set your hearth at the inn." },
    { 11, 15, "Silverpine Forest", "The Sepulcher", 43, 41, "Take the quests at the Sepulcher." },
    { 15, 17, "The Barrens", "The Crossroads", 52, 30, "Take the zeppelin to Durotar and go on to the Crossroads." },
  },
  zephras = {
    { 1, 12, "Zephras Isle", nil, nil, nil, "Quest through Zephras Isle; it takes you to level 12." },
    { 12, 17, nil, nil, nil, nil, "Level in Westfall, Loch Modan or Darkshore.", faction = "Alliance" },
    { 12, 17, nil, nil, nil, nil, "Level in The Barrens (Crossroads) or Silverpine Forest.", faction = "Horde" },
  },
  Alliance = {
    { 17, 21, "Redridge Mountains", "Lakeshire", 27, 45, "Take the quests in Lakeshire." },
    { 21, 25, "Wetlands", "Menethil Harbor", 10, 59, "Take the quests in Menethil Harbor and grab the flight path." },
    { 25, 28, "Duskwood", "Darkshire", 74, 46, "Take the quests in Darkshire (or Astranaar in Ashenvale)." },
    { 28, 32, "Hillsbrad Foothills", "Southshore", 51, 58, "Take the quests in Southshore." },
  },
  Horde = {
    { 17, 20, "The Barrens", "The Crossroads", 52, 30, "Finish the Crossroads quests and the southern Barrens." },
    { 20, 24, "Stonetalon Mountains", "Sun Rock Retreat", 47, 61, "Take the quests at Sun Rock Retreat." },
    { 24, 28, "Ashenvale", "Splintertree Post", 73, 61, "Take the quests at Splintertree Post." },
    { 28, 30, "Thousand Needles", "Freewind Post", 46, 51, "Take the quests at Freewind Post." },
    { 30, 32, "Hillsbrad Foothills", "Tarren Mill", 62, 20, "Take the quests at Tarren Mill." },
  },
  Both = {
    { 32, 38, "Stranglethorn Vale", "Nesingwary's Expedition", 35, 10, "Hunting quests at Nesingwary's camp; Arathi Highlands and Desolace are good too." },
    { 38, 42, nil, nil, nil, nil, "Shen'dralas or the Riverglades (new zones), or Stranglethorn Vale from Booty Bay." },
    { 42, 46, "Tanaris", "Gadgetzan", 52, 28, "Take the quests in Gadgetzan and grab the flight path." },
    { 46, 49, "Feralas", "Feathermoon Stronghold", 31, 43, "Take the quests at Feathermoon Stronghold.", faction = "Alliance" },
    { 46, 49, "Feralas", "Camp Mojache", 75, 44, "Take the quests at Camp Mojache.", faction = "Horde" },
    { 49, 52, "Un'Goro Crater", "Marshal's Refuge", 43, 8, "Take the quests at Marshal's Refuge." },
    { 52, 54, "Felwood", "Emerald Sanctuary", 51, 82, "Take the quests at the Emerald Sanctuary." },
    { 54, 56, "Burning Steppes", "Morgan's Vigil", 85, 69, "Take the quests at Morgan's Vigil.", faction = "Alliance" },
    { 54, 56, "Burning Steppes", "Flame Crest", 65, 24, "Take the quests at Flame Crest.", faction = "Horde" },
    { 56, 58, "Winterspring", "Everlook", 61, 38, "Take the quests in Everlook." },
    { 58, 60, "Eastern Plaguelands", "Light's Hope Chapel", 81, 59, "Take the quests at Light's Hope Chapel; Silithus and Mount Hyjal are good too." },
  },
}

-- the whole route for a race and faction, in order
function R:Route(race, faction)
  local out = {}
  local function add(leg)
    for _, s in ipairs(R.LEGS[leg] or {}) do
      if not s.faction or s.faction == faction then out[#out + 1] = s end
    end
  end
  add(R.START[race] or (faction == "Horde" and "durotar" or "elwynn"))
  add(faction)
  add("Both")
  return out
end

-- the current step (the first one not outgrown) and the ones after it
function R:Current(race, faction, level)
  local route = self:Route(race, faction)
  for i, s in ipairs(route) do
    if level < s[2] then return s, i, route end
  end
  return route[#route], #route, route
end

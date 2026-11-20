-- FlipForever Gathering module (was the separate Ore Farmer addon).
if select(2, ...).skipGather then return end
-- Ore Farmer: what can be farmed.
-- Names are English (enUS). Skill levels are the classic ones, which WoW Forever
-- keeps. Anything new you gather (an ore or herb this list doesn't know) is
-- learned automatically from what you loot.
local _, ns = ...

ns.CATEGORIES = {
  { key = "mining",    label = "Mining",     skillLine = 186 },
  { key = "herbalism", label = "Herbalism",  skillLine = 182 },
  { key = "fishing",   label = "Fishing",    skillLine = 356 },
  { key = "treasure",  label = "Treasure" },
}
ns.CategoryByKey = {}
for _, c in ipairs(ns.CATEGORIES) do ns.CategoryByKey[c.key] = c end

ns.ORES = {} -- every farmable resource, all categories (name kept for saved data)
ns.OreByKey = {}
ns.NodeToOre = {}
ns.ItemToOre = {}

local function add(def)
  ns.ORES[#ns.ORES + 1] = def
  ns.OreByKey[def.key] = def
  for _, name in ipairs(def.nodes or {}) do ns.NodeToOre[name] = def.key end
  if def.item and not ns.ItemToOre[def.item] then ns.ItemToOre[def.item] = def.key end
  return def
end

-- Mining ------------------------------------------------------------------
for _, d in ipairs({
  { "copper",      "Copper",            1,   2770,  2840,  { 0.90, 0.55, 0.25 }, { "Copper Vein" } },
  { "tin",         "Tin",               65,  2771,  3576,  { 0.72, 0.76, 0.70 }, { "Tin Vein" } },
  { "incendicite", "Incendicite",       65,  3340,  nil,   { 1.00, 0.35, 0.20 }, { "Incendicite Mineral Vein" } },
  { "silver",      "Silver",            75,  2775,  2842,  { 0.85, 0.90, 1.00 }, { "Silver Vein", "Ooze Covered Silver Vein" } },
  { "bloodstone",  "Lesser Bloodstone", 75,  4278,  nil,   { 0.80, 0.12, 0.18 }, { "Lesser Bloodstone Deposit" } },
  { "iron",        "Iron",              125, 2772,  3575,  { 0.66, 0.46, 0.40 }, { "Iron Deposit" } },
  { "indurium",    "Indurium",          150, 5833,  nil,   { 0.45, 0.68, 0.45 }, { "Indurium Mineral Vein" } },
  { "gold",        "Gold",              155, 2776,  3577,  { 1.00, 0.82, 0.00 }, { "Gold Vein", "Ooze Covered Gold Vein" } },
  { "mithril",     "Mithril",           175, 3858,  3860,  { 0.30, 0.90, 0.65 }, { "Mithril Deposit", "Ooze Covered Mithril Deposit" } },
  { "truesilver",  "Truesilver",        230, 7911,  6037,  { 0.55, 0.80, 1.00 }, { "Truesilver Deposit", "Ooze Covered Truesilver Deposit" } },
  { "darkiron",    "Dark Iron",         230, 11370, 11371, { 0.60, 0.25, 0.70 }, { "Dark Iron Deposit" } },
  { "thorium",     "Small Thorium",     245, 10620, 12359, { 0.20, 0.75, 0.75 }, { "Small Thorium Vein", "Ooze Covered Thorium Vein" } },
  { "richthorium", "Rich Thorium",      275, 10620, 12359, { 0.15, 0.55, 0.95 }, { "Rich Thorium Vein", "Ooze Covered Rich Thorium Vein" } },
}) do
  add({ key = d[1], cat = "mining", label = d[2], skill = d[3], item = d[4], ore = d[4], bar = d[5], color = d[6], nodes = d[7] })
end

-- Herbalism (node name = herb name) ---------------------------------------
for _, d in ipairs({
  { "Peacebloom", 1, 2447 }, { "Silverleaf", 1, 765 }, { "Earthroot", 15, 2449 },
  { "Mageroyal", 50, 785 }, { "Briarthorn", 70, 2450 }, { "Stranglekelp", 85, 3820 },
  { "Bruiseweed", 100, 2453 }, { "Wild Steelbloom", 115, 3355 }, { "Grave Moss", 120, 3369 },
  { "Kingsblood", 125, 3356 }, { "Liferoot", 150, 3357 }, { "Fadeleaf", 160, 3818 },
  { "Goldthorn", 170, 3821 }, { "Khadgar's Whisker", 185, 3358 }, { "Wintersbite", 195, 3819 },
  { "Firebloom", 205, 4625 }, { "Purple Lotus", 210, 8831 }, { "Arthas' Tears", 220, 8836 },
  { "Sungrass", 230, 8838 }, { "Blindweed", 235, 8839 }, { "Ghost Mushroom", 245, 8845 },
  { "Gromsblood", 250, 8846 }, { "Golden Sansam", 260, 13464 }, { "Dreamfoil", 270, 13463 },
  { "Mountain Silversage", 280, 13465 }, { "Plaguebloom", 285, 13466 }, { "Icecap", 290, 13467 },
  { "Black Lotus", 300, 13468 },
}) do
  -- Herbs go from light to dark green with skill, so similar herbs look alike.
  local t = d[2] / 300
  add({ key = "herb:" .. d[1]:lower(), cat = "herbalism", label = d[1], skill = d[2], item = d[3], ore = d[3],
        color = { 0.35 + 0.4 * (1 - t), 0.95 - 0.35 * t, 0.25 + 0.5 * t }, nodes = { d[1] } })
end

-- Fishing -----------------------------------------------------------------
-- Pools are recorded when the game shows their name. Every catch also marks a
-- "fishing spot" where you stood, so your best fishing places show up too.
add({ key = "fish:spot", cat = "fishing", label = "Fishing spot (where you fished)", skill = 0,
      color = { 0.30, 0.65, 1.00 }, nodes = {}, noRoute = true, merge = 30 })
for _, d in ipairs({
  { "Floating Wreckage", 1 }, { "Floating Debris", 1 }, { "Patch of Elemental Water", 1 },
  { "Oily Blackmouth School", 1 }, { "Firefin Snapper School", 1 }, { "Sagefish School", 1 },
  { "Greater Sagefish School", 1 }, { "Stonescale Eel Swarm", 1 }, { "Schooner Wreckage", 1 },
  { "Waterlogged Wreckage", 1 }, { "Bloodsail Wreckage", 1 },
}) do
  add({ key = "pool:" .. d[1]:lower(), cat = "fishing", label = d[1], skill = 0,
        color = { 0.10, 0.85, 0.95 }, nodes = { d[1] }, merge = 25 })
end

-- Treasure ----------------------------------------------------------------
add({ key = "chest", cat = "treasure", label = "Treasure chests", skill = 0, color = { 0.95, 0.75, 0.30 },
      nodes = { "Battered Chest", "Large Battered Chest", "Tattered Chest", "Solid Chest", "Large Solid Chest",
                "Large Iron Bound Chest", "Mithril Bound Chest", "Large Mithril Bound Chest", "Buccaneer's Strongbox" } })
add({ key = "footlocker", cat = "treasure", label = "Footlockers", skill = 0, color = { 0.80, 0.60, 0.40 },
      nodes = { "Battered Footlocker", "Waterlogged Footlocker", "Dented Footlocker", "Mossy Footlocker", "Scarlet Footlocker" } })

-- Gems and stones from veins, plus a couple of popular bars (for prices).
ns.GEMS   = { 774, 818, 1210, 1206, 1705, 1529, 3864, 7909, 7910, 12361, 12364, 12799, 12800 }
ns.STONES = { 2835, 2836, 2838, 7912, 12365 }
ns.EXTRA  = { 2841, 3859 }

-- Something new: a node name ending in Vein/Deposit, or an ore/herb item this
-- list doesn't know. cat decides where it goes; item (optional) its loot.
function ns.RegisterCustomOre(name, cat, item)
  local key = ns.NodeToOre[name] or ("x:" .. name)
  if not ns.OreByKey[key] then
    cat = cat or "mining"
    local color = cat == "herbalism" and { 0.6, 1.0, 0.6 } or { 0.95, 0.95, 0.95 }
    add({ key = key, cat = cat, label = name, skill = 0, color = color, nodes = { name }, item = item, ore = item, custom = true })
  end
  if ns.db then ns.db.custom[name] = { cat = cat, item = item } end
  return key
end

function ns.OreKeyForNodeName(name)
  if type(name) ~= "string" or name == "" then return nil end
  local key = ns.NodeToOre[name]
  if key then return key end
  if name:find("Vein$") or name:find("Deposit$") then return ns.RegisterCustomOre(name, "mining") end
  return nil
end

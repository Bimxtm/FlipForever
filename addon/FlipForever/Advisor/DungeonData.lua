-- Dungeon advisor data: entrances and notable drops per slot (plan in docs/DUNGEON_ADVISOR.md).
-- Written for FlipForever from general dungeon knowledge; a first set of well-known drops per dungeon.
-- Entry: { name, from, to, faction, zone, x, y, drops }
--   faction: nil for both; zone/x/y: the entrance on that zone's map (0-100).
--   drops: { slot, armor, level, item }; slot = Advisor slot label, armor = Cloth/Leather/Mail/Plate or nil.
-- WoW: Forever's own dungeons have no drops listed yet: they show in the level list only.
local FF = FlipForever
local D = {}
FF.DungeonData = D

D.LIST = {
  { "Ragefire Chasm", 13, 18, "Horde", "Orgrimmar", 52, 49, {
    { "Main hand", nil, 16, "Cursed Felblade" },
    { "Shoulders", "Cloth", 16, "Feline Mantle" },
    { "Wrists", "Mail", 15, "Cavedweller Bracers" },
  } },
  { "The Deadmines", 15, 22, nil, "Westfall", 42.6, 71.8, {
    { "Main hand", nil, 24, "Cruel Barb" },
    { "Main hand", nil, 23, "Smite's Mighty Hammer" },
    { "Main hand", nil, 21, "Cookie's Tenderizer" },
    { "Chest", "Cloth", 23, "Corsair's Overshirt" },
    { "Back", nil, 24, "Cape of the Brotherhood" },
    { "Legs", "Leather", 24, "Blackened Defias Leggings" },
    { "Waist", "Leather", 23, "Blackened Defias Belt" },
    { "Feet", "Leather", 23, "Blackened Defias Boots" },
  } },
  { "Wailing Caverns", 17, 24, nil, "The Barrens", 46, 36, {
    { "Main hand", nil, 24, "Wingblade" },
    { "Main hand", nil, 23, "Crescent Staff" },
    { "Back", nil, 23, "Glowing Lizardscale Cloak" },
    { "Chest", "Leather", 25, "Armor of the Fang" },
    { "Legs", "Leather", 25, "Leggings of the Fang" },
    { "Feet", "Leather", 24, "Boots of the Fang" },
    { "Chest", "Mail", 24, "Mutant Scale Breastplate" },
    { "Hands", "Cloth", 22, "Serpent Gloves" },
  } },
  { "Shadowfang Keep", 20, 26, nil, "Silverpine Forest", 44.8, 67.8, {
    { "Main hand", nil, 24, "Shadowfang" },
    { "Main hand", nil, 25, "Meteor Shard" },
    { "Main hand", nil, 26, "Odo's Ley Staff" },
    { "Chest", "Cloth", 26, "Robes of Arugal" },
    { "Waist", "Cloth", 27, "Belt of Arugal" },
    { "Legs", "Cloth", 25, "Necromancer Leggings" },
    { "Back", nil, 24, "Wolfmaster Cape" },
  } },
  { "Blackfathom Deeps", 22, 28, nil, "Ashenvale", 14.2, 14.0, {
    { "Main hand", nil, 28, "Strike of the Hydra" },
    { "Head", "Mail", 29, "Fire Hardened Coif" },
    { "Wrists", "Cloth", 28, "Glowing Magical Bracelets" },
  } },
  { "The Stockade", 25, 29, nil, "Stormwind City", 40.5, 55.8, {
    { "Main hand", nil, 26, "Iron Knuckles" },
  } },
  { "Gnomeregan", 29, 38, nil, "Dun Morogh", 24.5, 39.5, {
    { "Main hand", nil, 34, "Electrocutioner Leg" },
    { "Main hand", nil, 33, "Manual Crowd Pummeler" },
    { "Main hand", nil, 36, "Hydrocane" },
    { "Head", "Cloth", 37, "Electromagnetic Gigaflux Reactivator" },
    { "Legs", "Leather", 32, "Triprunner Dungarees" },
  } },
  { "Razorfen Kraul", 29, 38, nil, "The Barrens", 42.3, 89.9, {
    { "Main hand", nil, 33, "Corpsemaker" },
    { "Main hand", nil, 30, "Swinetusk Shank" },
  } },
  { "Scarlet Monastery", 30, 46, nil, "Tirisfal Glades", 84.5, 30.5, {
    { "Main hand", nil, 37, "Illusionary Rod" },
    { "Chest", "Cloth", 37, "Robe of Doan" },
    { "Shoulders", "Cloth", 37, "Mantle of Doan" },
    { "Chest", "Mail", 33, "Ironspine's Ribcage" },
    { "Main hand", nil, 37, "Ravager" },
    { "Shoulders", "Mail", 40, "Herod's Shoulder" },
    { "Head", "Mail", 40, "Raging Berserker's Helm" },
    { "Legs", "Mail", 38, "Scarlet Leggings" },
    { "Main hand", nil, 42, "Mograine's Might" },
    { "Main hand", nil, 42, "Hand of Righteousness" },
    { "Head", "Cloth", 42, "Whitemane's Chapeau" },
  } },
  { "Uldaman", 36, 51, nil, "Badlands", 44.6, 12.1, {
    { "Main hand", nil, 42, "Grimlok's Charge" },
    { "Main hand", nil, 43, "Galgann's Firehammer" },
    { "Main hand", nil, 45, "The Rockpounder" },
  } },
  { "Zul'Farrak", 40, 54, nil, "Tanaris", 38.7, 20.0, {
    { "Main hand", nil, 44, "Witch Doctor's Cane" },
    { "Main hand", nil, 47, "Gahz'rilla Fang" },
    { "Main hand", nil, 48, "Sul'thraze the Lasher" },
    { "Chest", "Leather", 45, "Jinxed Hoodoo Skin" },
    { "Head", "Cloth", 47, "Embalmed Shroud" },
  } },
  { "Maraudon", 45, 55, nil, "Desolace", 29.1, 62.5, {
    { "Hands", "Plate", 46, "Rockgrip Gauntlets" },
    { "Legs", "Leather", 47, "Infernal Trickster Leggings" },
    { "Feet", "Leather", 47, "Albino Crocscale Boots" },
    { "Main hand", nil, 51, "Princess Theradras' Scepter" },
    { "Legs", "Mail", 51, "Elemental Rockridge Leggings" },
  } },
  { "Sunken Temple", 50, 60, nil, "Swamp of Sorrows", 69.6, 53.5, {} },
  { "Blackrock Depths", 52, 60, nil, "Searing Gorge", 35.4, 84.4, {
    { "Chest", "Mail", 52, "Savage Gladiator Chain" },
    { "Head", "Mail", 52, "Savage Gladiator Helm" },
    { "Head", "Plate", 56, "Golem Skull Helm" },
    { "Chest", "Cloth", 56, "Robes of the Royal Crown" },
    { "Main hand", nil, 57, "Lord General's Sword" },
    { "Main hand", nil, 57, "Angerforge's Battle Axe" },
    { "Main hand", nil, 60, "Ironfoe" },
  } },
  { "Blackrock Spire", 55, 60, nil, "Searing Gorge", 35.4, 84.4, {
    { "Main hand", nil, 58, "Dal'Rend's Sacred Charge" },
    { "Shoulders", "Leather", 58, "Truestrike Shoulders" },
  } },
}

-- armor kinds by class token: before 40, at 40 and above
local ARMOR = {
  MAGE = { "Cloth", "Cloth" }, PRIEST = { "Cloth", "Cloth" }, WARLOCK = { "Cloth", "Cloth" },
  ROGUE = { "Leather", "Leather" }, DRUID = { "Leather", "Leather" },
  HUNTER = { "Leather", "Mail" }, SHAMAN = { "Leather", "Mail" },
  WARRIOR = { "Mail", "Plate" }, PALADIN = { "Mail", "Plate" },
}
local RANK = { Cloth = 1, Leather = 2, Mail = 3, Plate = 4 }

-- the armor kind a class should wear at a level (nil: unknown class, any armor counts)
function D:Armor(class, level)
  local a = ARMOR[class]
  return a and a[(level or 1) >= 40 and 2 or 1] or nil
end

-- does a drop fit this armor kind? Weapons and jewellery always; armor only at the class's own kind
-- (lower kinds are not an upgrade, higher ones can't be worn)
function D:Fits(drop, armor)
  if not drop[2] or not armor then return true end
  return RANK[drop[2]] == RANK[armor]
end

-- best dungeon for these weak slot labels ({ ["Chest"] = true, ... }).
-- returns entry, { slot = { item names } }, slot list (sorted), or nil
function D:Best(level, faction, class, weak)
  local armor = self:Armor(class, level)
  local best, bestHits, bestSlots, bestScore, bestDist
  for _, d in ipairs(self.LIST) do
    if (d[4] == nil or d[4] == faction) and level >= d[2] and level <= d[3] then
      local hits, slots = {}, {}
      for _, drop in ipairs(d[8]) do
        local s = drop[1]
        if weak[s] and self:Fits(drop, armor) and drop[3] >= level - 5 and drop[3] <= level + 3 then
          if not hits[s] then hits[s] = {} slots[#slots + 1] = s end
          table.insert(hits[s], drop[4])
        end
      end
      local score = #slots
      local dist = math.abs((d[2] + d[3]) / 2 - level)
      if score > 0 and (not best or score > bestScore or (score == bestScore and dist < bestDist)) then
        best, bestHits, bestSlots, bestScore, bestDist = d, hits, slots, score, dist
      end
    end
  end
  if not best then return nil end
  table.sort(bestSlots)
  return best, bestHits, bestSlots
end

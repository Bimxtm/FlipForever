-- FlipForever Advisor: guide data for WoW: Forever (full release, 4 Nov 2026).
-- Collected 20 Nov 2026 from post-launch guides. Every build says where it comes from;
-- builds from guides written for the beta (level cap 30) are marked as such.
--
-- talents: in the order the guide takes them. { name, ranks (nil = max), level (earliest) }
-- quests:  done = a spell you learn from it (checked in your spellbook) or items = rewards
-- gear:    { name, level, where, faction ("Alliance"/"Horde"/nil), prof (needs a profession) }
local FF = FlipForever
local G = {}
FF.Guide = G

G.SOURCES = {
  method = "Method.gg leveling guides (updated 14-19 Nov 2026, after launch)",
  wct    = "Warcraft Tavern leveling guides (read again 22 Nov 2026; some builds still written for the beta, level cap 30)",
  cc     = "Conquest Capped leveling guide (15 Nov 2026)",
  fdb    = "FoReverDB leveling guide (5 Nov 2026)",
  wiki   = "Warcraft Wiki: World of Warcraft: Forever (20 Nov 2026)",
  ts     = "Timesaver professions guide (live data, 8 Nov 2026)",
}

-- Classes ---------------------------------------------------------------------------------------
G.CLASSES = {}

G.CLASSES.WARRIOR = {
  stats = "Weapon damage > Strength / Attack Power > Stamina > Agility > Armor (Warcraft Tavern). Method: the weapon is 95-100% of your damage while leveling.",
  professions = { "Mining", "Blacksmithing" }, profNote = "Blacksmithing for weapon stones; Skinning for the camp chair buff; First Aid (Method).",
  spikes = { {14, "Revenge and Demoralizing Shout"}, {20, "Victory Rush and Retaliation"}, {36, "Whirlwind"} },
  quests = {
    { level = 10, text = "Defensive Stance class quest (gives Sunder Armor, Taunt, Defensive Stance, then a one-hander)", done = "Defensive Stance" },
    { level = 30, text = "Berserker Stance quest (Fray Island gauntlet)", done = "Berserker Stance" },
    { level = 30, text = "Whirlwind Axe chain in Alterac Mountains (Method: very hard at 30)", items = { "Whirlwind Axe" } },
  },
  gear = {
    { "Axe of Orgrimmar", 14, "Ragefire Chasm", "Horde" },
    { "Ironforge Greathammer", 14, "Hall of Thanes (new dungeon, Ironforge)", "Alliance" },
    { "Forsaken Greataxe", 18, "Ruins of Lordaeron (new dungeon)", "Horde" },
    { "Heavehammer", 27, "Excavation Site: Wetlands (new dungeon)" },
    { "Whirlwind Axe", 30, "class quest in Alterac Mountains" },
    { "Masons Fraternity Ring", 44, "quest reward" },
    { "Highborne Research Tablet", 50, "quest reward (trinket)", "Alliance" },
  },
  builds = {
    { id = "arms", name = "Arms (two-hander)", source = "method", note = "Method: best in groups and dungeons.",
      talents = { {"Improved Rend"}, {"Tactical Mastery"}, {"Deep Wounds"}, {"Bloodthrill"}, {"Sweeping Strikes"},
                  {"Weaponmaster"}, {"Mortal Strike"}, {"Unbridled Wrath"}, {"Enrage"} } },
    { id = "prot", name = "Protection (one-hand + shield)", source = "method", note = "Method: best for solo leveling.",
      talents = { {"Shield Specialization"}, {"Improved Thunder Clap"}, {"Improved Bloodrage"}, {"Master of Defense", nil, 20},
                  {"Improved Revenge"}, {"Vanguard"}, {"Bastion"}, {"Focused Rage"} } },
    { id = "arms_wct", name = "Arms (Warcraft Tavern)", source = "wct",
      note = "Beta-era (level 30) build: Deflection, then max Two-Handed Weapon Specialization, Anger Management, Bloodthrill.",
      talents = { {"Deflection"}, {"Two-Handed Weapon Specialization"}, {"Anger Management"}, {"Bloodthrill"} } },
  },
}

G.CLASSES.PALADIN = {
  stats = "Retribution: Strength / Attack Power > Stamina > Spell Power > Intellect > Armor (Warcraft Tavern, beta).",
  professions = { "Blacksmithing", "Mining" }, profNote = "Blacksmithing is the only source of mail Spell Power gear; Cooking for XP food (Method).",
  spikes = { {20, "Consecration and Blessing of Kings - Method: your kit is essentially complete"}, {44, "Hammer of Wrath"} },
  quests = {
    { level = 12, text = "Redemption class quest", done = "Redemption" },
    { level = 20, text = "Verigan's Fist (Test of Righteousness)", items = { "Verigan's Fist" }, faction = "Alliance" },
    { level = 20, text = "Wolfsbane class quest (starts with Diplomatic Incident)", items = { "Wolfsbane" }, faction = "Horde" },
  },
  gear = {
    { "Forsaken Greataxe", 15, "Ruins of Lordaeron (new dungeon)", "Horde" },
    { "Ironforge Greathammer", 16, "Hall of Thanes (new dungeon, Ironforge)", "Alliance" },
    { "Seedcloud Buckler", 19, "quest reward (shield)" },
    { "Acolyte's Silvered Chain Helm", 20, "Blacksmithing", nil, "Blacksmithing" },
    { "Verigan's Fist", 20, "class quest", "Alliance" },
    { "Wolfsbane", 20, "class quest", "Horde" },
    { "Heavehammer", 31, "Excavation Site: Wetlands (new dungeon)" },
    { "Bonebiter", 34, "quest reward", "Alliance" },
  },
  builds = {
    { id = "ret", name = "Retribution", source = "method", note = "Method: Pursuit of Justice by level 21 is the top priority. Dual spec at 40 (50g).",
      talents = { {"Benediction"}, {"Sanctified Judgement"}, {"Improved Judgement"}, {"Pursuit of Justice", nil, nil},
                  {"Seal of Command"}, {"Conviction"}, {"Sacred Arbiter"}, {"Two-Handed Weapon Specialization"},
                  {"Vengeance"}, {"Champion of the Light"}, {"Unyielding Faith", 1}, {"Unsealed Wrath"},
                  {"Divine Strength"}, {"Improved Seals"}, {"Holy Conduit"}, {"Precision"} } },
  },
}

G.CLASSES.HUNTER = {
  stats = "Agility > Attack Power > Crit > Strength > Intellect > Spirit > Stamina > Armor (Warcraft Tavern).",
  professions = { "Leatherworking", "Skinning" }, profNote = "Leatherworking first: soulbound leveling gear from level 10 (Method). Cooking, First Aid, Fishing as extras.",
  spikes = { {10, "your first pet"}, {18, "Multi-Shot"}, {20, "Aimed Shot"}, {25, "Summon Hawk - two hawks at once (Method: core)"}, {26, "Rapid Fire"}, {30, "Feign Death and Intimidation"} },
  quests = {
    { level = 10, text = "Taming the Beast - get your first pet", done = "Call Pet" },
  },
  gear = {
    { "Rough Boomstick", 5, "Engineering 50", nil, "Engineering" },
    { "Venomstrike", 19, "Lord Serpentis, Wailing Caverns" },
    { "Golemsight Long Gun", 28, "Excavation Site: Wetlands (new dungeon)" },
    { "Master Hunter's Rifle", 28, "Hemet's quest chain (41 recommended)" },
    { "Quilboar Blaster", 29, "quest reward", "Horde" },
    { "Truthseeker's Bow", 40, "turn in 25 library books" },
    { "Thorium Rifle", 47, "Engineering 260", nil, "Engineering" },
    { "Dark Iron Rifle", 50, "Engineering 275", nil, "Engineering" },
  },
  builds = {
    { id = "bm", name = "Beast Mastery (31/20 Marksmanship)", source = "method", note = "Method and Warcraft Tavern both call BM the smoothest leveling spec.",
      talents = { {"Deadly Aspects"}, {"Focused Fire"}, {"Improved Revive Pet"}, {"Endurance Training", 1}, {"Pathfinding", nil, 20},
                  {"Unleashed Fury"}, {"Summon Hawk", nil, 25}, {"Bestial Swiftness"}, {"Frenzy", 4}, {"Intimidation"},
                  {"Bestial Discipline"}, {"Bestial Wrath"},
                  {"Lethal Attacks", nil, 41}, {"Careful Aim"}, {"Rapid Killing"}, {"Efficiency"}, {"Trueshot Aura"}, {"Mortal Shots", 4} } },
  },
}

G.CLASSES.ROGUE = {
  stats = "Crit > Agility > Attack Power > Strength > Stamina > Armor (Method).",
  professions = { "Skinning", "Mining" }, profNote = "Method: Skinning + Mining, Blacksmithing in a city, then Leatherworking to 60. First Aid recommended.",
  spikes = { {10, "Dual Wield and Slice and Dice - Method: huge damage boost"}, {20, "Poisons (Warcraft Tavern)"}, {22, "Vanish"}, {26, "Cheap Shot"} },
  quests = {
    { level = 10, text = "Class quest: Blade of Cunning", items = { "Blade of Cunning" } },
    { level = 30, text = "Class quest: Ruby-Adorned Blade", items = { "Ruby-Adorned Blade" } },
  },
  gear = {
    { "Cruel Barb", 18, "The Deadmines", "Alliance" },
    { "Outlaw Sabre", 24, "quest reward", "Horde" },
    { "Meteor Shard", 24, "Shadowfang Keep" },
  },
  builds = {
    { id = "combat", name = "Combat (solo)", source = "method",
      note = "Method recommends Combat solo and Subtlety in groups; switch to Subtlety if you loot a strong dagger by 30. Method shows its talents only as pictures, so follow the tree on the guide page.",
      talents = nil },
    { id = "sub_bleed", name = "Subtlety Bleed (Warcraft Tavern)", source = "wct", note = "Beta-era build. Needs a dagger.",
      talents = { {"Opportunity", nil, 10}, {"Master of Deception"}, {"Setup"}, {"Improved Ambush", nil, 15}, {"Dirty Deeds"},
                  {"Premeditation", nil, 20}, {"Serrated Blades"}, {"Initiative"}, {"Ghostly Strike", nil, 25},
                  {"Preparation", nil, 30}, {"Hemorrhage"}, {"Boot Knife", nil, 35}, {"Thousand Cuts", nil, 40} } },
  },
}

G.CLASSES.PRIEST = {
  stats = "Intellect / Spell Damage > Stamina / Spirit > Armor; Shadow adds Shadow Power (Warcraft Tavern, beta).",
  professions = { "Tailoring", "Enchanting" }, profNote = "Method: only worth it to craft wands (Lesser and Greater Magic Wand); otherwise crafting isn't worth it while leveling.",
  spikes = { {10, "Mind Blast"}, {32, "Shadow Word: Death"}, {40, "Shadowform and Mind Flay - Method: respec to Shadow now"} },
  quests = {},
  gear = {
    { "Lesser Magic Wand", 5, "Enchanting", nil, "Enchanting" },
    { "Greater Magic Wand", 13, "Enchanting - about 50% more damage (Method)", nil, "Enchanting" },
    { "Gravestone Scepter", 18, "quest: Blackfathom Villainy" },
    { "Charred Wand", 19, "quest: Dangerous" },
    { "Wand of Mana Concentration", 27, "quest: Arcanic Enigma (City of Dalaran)" },
  },
  builds = {
    { id = "lvl_shadow", name = "Leveling build, Shadow from 40", source = "method",
      note = "Method: a mana-efficient build to 39, then respec to Shadow at 40 (Shadowform). Method shows talents only as pictures; the wand is your key slot until 40.",
      talents = { {"Shadowform", 1, 40} } },
  },
}

G.CLASSES.SHAMAN = {
  stats = "Agility > Strength > Stamina > Intellect (Method). Warcraft Tavern's beta guide disagrees for Enhancement.",
  professions = { "Leatherworking", "Skinning" }, profNote = "Method: Dark Leather Boots around 10, Brawler's Leather Hood around 20; Cooking and First Aid.",
  spikes = { {10, "Searing Totem"}, {20, "Ghost Wolf"}, {25, "Stormstrike"}, {30, "Windfury Weapon - Call of Air is the biggest mid-level upgrade"}, {40, "Rage of the Farseer"} },
  quests = {
    { level = 10, text = "Call of Fire (Searing Totem)", done = "Searing Totem" },
    { level = 20, text = "Call of Water (Healing Stream Totem)", done = "Healing Stream Totem" },
    { level = 30, text = "Call of Air - weapon reward", items = { "Rage of the Storm", "Lightning's Grasp", "Tidebringer's Claw" } },
  },
  gear = {
    { "Ironforge Greathammer", 16, "Hall of Thanes quest reward", "Alliance" },
    { "Smite's Mighty Hammer", 18, "The Deadmines" },
    { "Rockslicer", 18, "The Deadmines" },
    { "Corpsemaker", 29, "Razorfen Kraul" },
    { "Rage of the Storm", 30, "Call of Air quest" },
  },
  builds = {
    { id = "enh", name = "Enhancement", source = "method",
      note = "Method: strongest leveling spec. Rockbiter with 1H+shield or a 2H until 30, then Windfury Weapon on a 2H. Method shows the full tree only as pictures.",
      talents = { {"Stormstrike", 1, 25}, {"Improved Ghost Wolf", 2} } },
    { id = "ele_wct", name = "Elemental (Warcraft Tavern)", source = "wct",
      note = "Beta-era. Lava Burst, Flame Shock, Searing or Magma Totem, Lightning Bolt as filler.", talents = nil },
  },
}

G.CLASSES.MAGE = {
  stats = "Intellect / Spell Damage > Stamina / Spirit > Armor (Warcraft Tavern).",
  professions = { "Tailoring", "Enchanting" }, profNote = "Method: Tailoring then Enchanting; Cooking, First Aid, Fishing as extras.",
  spikes = { {10, "Frost Nova"}, {20, "Blizzard, Blink, Ice Lance and teleports"}, {24, "Counterspell"}, {26, "Cone of Cold"}, {40, "Ice Barrier and portals"} },
  quests = {},
  gear = {
    { "Greater Magic Wand", 13, "Enchanting", nil, "Enchanting" },
    { "Coldspire Staff", 19, "quest reward" },
    { "Filigreed Silky Circlet", 25, "quest reward" },
    { "Gravestone Scepter", 27, "quest reward" },
    { "Icefury Wand", 30, "quest reward (40 recommended)" },
    { "Orb of the Forgotten Seer", 32, "quest reward" },
    { "Hypnotic Blade", 34, "quest reward" },
  },
  builds = {
    { id = "frost", name = "Frost, then Arcane (33/18)", source = "method", note = "Method: Frost through about 42, then the last 18 points into Arcane.",
      talents = { {"Improved Frostbolt"}, {"Precision"}, {"Frostbite"}, {"Ice Shards", 3}, {"Ice Lance", 1, 20}, {"Ice Block", 1, 25},
                  {"Shatter"}, {"Fingers of Frost"}, {"Improved Cone of Cold"}, {"Winter's Chill"}, {"Cold Snap"}, {"Ice Barrier"},
                  {"Improved Channeling", nil, 43}, {"Arcane Concentration"}, {"Missile Barrage"}, {"Arcane Subtlety"},
                  {"Arcane Blast", 1, 57}, {"Arcane Meditation"} } },
  },
}

G.CLASSES.WARLOCK = {
  stats = "Spell Power / Shadow damage > wand DPS (until 30) > Spirit / Intellect > Stamina (Warcraft Tavern).",
  professions = { "Tailoring", "Enchanting" }, profNote = "Method: Tailoring + Enchanting.",
  spikes = { {10, "Voidwalker"}, {20, "Succubus / Incubus"}, {30, "Felhunter"}, {40, "Felsteed"} },
  quests = {
    { level = 10, text = "Voidwalker class quest", done = "Summon Voidwalker" },
    { level = 20, text = "Succubus / Incubus class quest", done = "Summon Succubus" },
    { level = 20, text = "Staff or Orb of Soran'ruk quest", items = { "Staff of Soran'ruk", "Orb of Soran'ruk" } },
    { level = 30, text = "Felhunter class quest", done = "Summon Felhunter" },
    { level = 40, text = "Felsteed class quest", done = "Summon Felsteed" },
    { level = 50, text = "Trolls of a Feather (Soul Harvester)", items = { "Soul Harvester" } },
    { level = 60, text = "Dreadsteed (long chain)", done = "Summon Dreadsteed" },
  },
  gear = {
    { "Lesser Magic Wand", 5, "Enchanting", nil, "Enchanting" },
    { "Greater Magic Wand", 13, "Enchanting", nil, "Enchanting" },
    { "Cookie's Stirring Rod", 17, "The Deadmines" },
    { "Staff of Soran'ruk", 20, "class quest (+34 Shadow/Fire)" },
    { "Gravestone Scepter", 22, "quest reward" },
    { "Necrotic Wand", 30, "quest reward" },
    { "Soul Harvester", 50, "quest: Trolls of a Feather" },
  },
  builds = {
    { id = "aff", name = "Affliction (41/7/3)", source = "wct",
      note = "Warcraft Tavern's level 60 Affliction build (undated). Method's warlock guide only covers up to level 30 so far.",
      talents = { {"Improved Corruption", 5, 10}, {"Suppression", 3}, {"Unholy Power", 5, 18}, {"Demonic Energies", 2},
                  {"Improved Drains", 3, 25}, {"Amplify Curse"}, {"Improved Bane of Agony", 2}, {"Suppression"},
                  {"Pandemic", 3, 31}, {"Improved Life Tap", 1}, {"Siphon Life", nil, 37}, {"Soul Siphon", 3},
                  {"Improved Life Tap", 2, 41}, {"Shadow Mastery", 5}, {"Wrack", nil, 47}, {"Malevolence", 5, 48},
                  {"Fel Concentration", 3}, {"Nightfall", 2}, {"Improved Shadow Bolt", 3} } },
  },
}

G.CLASSES.DRUID = {
  stats = "Feral: Strength / Agility / Attack Power > Stamina / Intellect / Spirit > Armor (Warcraft Tavern).",
  professions = { "Leatherworking", "Skinning" }, profNote = "Method: Leatherworking + Skinning (Camp Tent gives rested XP), or Herbalism + Alchemy.",
  spikes = { {10, "Bear Form"}, {20, "Cat Form, Prowl, Rip, Shred"}, {30, "Travel Form and Leader of the Pack"}, {40, "Dire Bear, Moonkin, mount and dual spec"} },
  quests = {
    { level = 10, text = "Bear Form class quest (Heeding the Call; Skyborne: The Great Ursera Spirit)", done = "Bear Form" },
    { level = 14, text = "Cure Poison quest (Lessons Anew)", done = "Cure Poison" },
    { level = 16, text = "Aquatic Form quest (A Lesson to Learn)", done = "Aquatic Form" },
    { level = 20, text = "Cat Form (The Great Cat Spirit; Skyborne: The Great Windborne Cat Spirit)", done = "Cat Form" },
    { level = 50, text = "A Better Ingredient (Sunken Temple)", items = { "Grizzled Pelt", "Moonshadow Stave", "Forest's Embrace" } },
  },
  gear = {
    { "Serpent's Shoulders", 18, "quest reward" },
    { "Smite's Mighty Hammer", 18, "The Deadmines" },
    { "Defender of Dalaran", 30, "quest reward", "Alliance" },
    { "Ghostshard Talisman", 30, "quest reward" },
    { "Dark Hooded Cape", 34, "quest reward" },
    { "The Pacifier", 36, "quest reward" },
    { "Grimlok's Charge", 42, "Uldaman" },
  },
  builds = {
    { id = "feral", name = "Feral", source = "method", note = "Method: fastest and most popular. Method says these talents may still change.",
      talents = { {"Ferocity"}, {"Feline Swiftness"}, {"Savage Fury"}, {"Leader of the Pack"}, {"Predatory Strikes"},
                  {"Primal Bite"}, {"Shifting Power"} } },
  },
}

-- Races -----------------------------------------------------------------------------------------
G.RACES = {
  Tauren = "Cultivation makes Herbalism extra good (Warcraft Wiki).",
  Dwarf = "Find Treasure racial - good with Mining (Warcraft Wiki).",
  Gnome = "Engineering Specialization racial - Engineering is a natural pick.",
  Skyborne = "Skyborne start on Zephras Isle (1-12) and ride Galestrider mounts from level 40.",
}

-- Where to level (Conquest Capped / FoReverDB) --------------------------------------------------
G.ZONES = {
  Alliance = {
    { 1, 12, "Elwynn Forest, Dun Morogh, Teldrassil or Zephras Isle (Skyborne)" },
    { 12, 18, "Westfall, Loch Modan or Darkshore" },
    { 18, 21, "Redridge Mountains" },
    { 21, 25, "Wetlands" },
    { 24, 28, "Ashenvale or Duskwood" },
    { 24, 37, "Hillsbrad Foothills" },
  },
  Horde = {
    { 1, 12, "Durotar, Mulgore, Tirisfal Glades or Zephras Isle (Skyborne)" },
    { 12, 16, "The Barrens (Crossroads) or Silverpine Forest" },
    { 16, 21, "Northern Barrens" },
    { 18, 28, "Stonetalon Mountains" },
    { 25, 28, "Ashenvale" },
    { 28, 30, "Thousand Needles" },
    { 24, 37, "Hillsbrad Foothills" },
  },
  Both = {
    { 30, 40, "Arathi Highlands, Desolace, Stranglethorn Vale or Alterac Mountains" },
    { 35, 45, "Shen'dralas or the Riverglades (new zones)" },
    { 40, 50, "Tanaris, Feralas, The Hinterlands or Searing Gorge" },
    { 48, 55, "Un'Goro Crater, Felwood, Azshara or Blasted Lands" },
    { 50, 60, "Burning Steppes, the Plaguelands, Winterspring or Silithus" },
    { 55, 60, "Mount Hyjal" },
  },
}

G.DUNGEONS = {
  { 13, 18, "Ragefire Chasm", "Horde" },
  { 13, 18, "Hall of Thanes (new, Ironforge)", "Alliance" },
  { 15, 20, "Ruins of Lordaeron (new)" },
  { 15, 22, "The Deadmines" },
  { 17, 24, "Wailing Caverns" },
  { 20, 26, "Shadowfang Keep" },
  { 22, 28, "Blackfathom Deeps" },
  { 25, 29, "The Stockade" },
  { 26, 31, "Excavation Site: Wetlands (new)" },
  { 28, 33, "City of Dalaran (new)" },
  { 29, 38, "Gnomeregan or Razorfen Kraul" },
  { 30, 46, "Scarlet Monastery" },
  { 35, 40, "The Drowned City (new)" },
  { 36, 51, "Uldaman" },
  { 40, 45, "Krol'dok Stronghold (new)" },
  { 40, 54, "Zul'Farrak" },
  { 45, 55, "Maraudon" },
  { 48, 53, "Alcaz Prison (new)" },
  { 50, 60, "Sunken Temple" },
  { 52, 60, "Blackrock Depths" },
  { 55, 60, "Blackmaw Hold (new) or Blackrock Spire" },
  { 58, 60, "Shaper's Terrace (new)" },
}

-- Things to save up for (Conquest Capped / Warcraft Wiki) ---------------------------------------
G.MILESTONES = {
  { level = 40, gold = 100, text = "Apprentice Riding + first mount (100g)", done = "Apprentice Riding" },
  { level = 40, gold = 50, text = "Dual talent spec at your class trainer (50g)" },
  { level = 60, gold = 1000, text = "Journeyman Riding (1,000g)", done = "Journeyman Riding" },
}

G.PROF_TIPS = {
  "For gold in the first weeks, guides recommend two gathering professions (Mining + Herbalism or Mining + Skinning) - Timesaver, 8 Nov.",
  "Cheapest crafters to level 1-300 right now: Alchemy, Enchanting, Engineering (Timesaver's AH scan).",
}

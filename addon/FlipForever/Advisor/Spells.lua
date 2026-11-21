-- Spell names in the client's language.
--
-- The guide data, rotations and class quests name spells in English. On other clients the
-- spellbook and /cast use the translated names, so every English name is looked up through its
-- spell ID (rank 1; the name is the same for every rank). Spells without an ID here keep their
-- English name. On English clients nothing changes.
local FF = FlipForever
local S = {}
FF.Spells = S

S.ID = {
  -- warrior
  ["Battle Shout"] = 6673, ["Rend"] = 772, ["Mortal Strike"] = 12294, ["Heroic Strike"] = 78,
  ["Thunder Clap"] = 6343, ["Sunder Armor"] = 7386, ["Shield Slam"] = 23922, ["Bloodthirst"] = 23881,
  ["Whirlwind"] = 1680, ["Sweeping Strikes"] = 12292, ["Concussion Blow"] = 12809, ["Taunt"] = 355,
  ["Demoralizing Shout"] = 1160, ["Berserker Stance"] = 2458, ["Defensive Stance"] = 71,
  -- paladin
  ["Seal of Command"] = 20375, ["Seal of Righteousness"] = 21084, ["Judgement"] = 20271,
  ["Consecration"] = 26573, ["Holy Shield"] = 20925, ["Holy Shock"] = 20473, ["Exorcism"] = 879,
  ["Hammer of Wrath"] = 24275, ["Repentance"] = 20066, ["Redemption"] = 7328, ["Righteous Defense"] = 31789,
  -- hunter
  ["Hunter's Mark"] = 1130, ["Serpent Sting"] = 1978, ["Arcane Shot"] = 3044, ["Aimed Shot"] = 19434,
  ["Multi-Shot"] = 2643, ["Auto Shot"] = 75, ["Raptor Strike"] = 2973, ["Rapid Fire"] = 3045,
  ["Bestial Wrath"] = 19574, ["Mongoose Bite"] = 1495, ["Call Pet"] = 883,
  -- rogue
  ["Hemorrhage"] = 16511, ["Sinister Strike"] = 1752, ["Slice and Dice"] = 5171, ["Eviscerate"] = 2098,
  ["Backstab"] = 53, ["Blade Flurry"] = 13877, ["Adrenaline Rush"] = 13750, ["Ghostly Strike"] = 14278,
  ["Cheap Shot"] = 1833, ["Rupture"] = 1943, ["Garrote"] = 703, ["Mutilate"] = 1329,
  -- priest
  ["Power Word: Shield"] = 17, ["Shadow Word: Pain"] = 589, ["Mind Blast"] = 8092, ["Mind Flay"] = 15407,
  ["Smite"] = 585, ["Holy Fire"] = 14914, ["Devouring Plague"] = 2944, ["Vampiric Embrace"] = 15286,
  ["Shadow Word: Death"] = 32379, ["Penance"] = 47540,
  -- shaman
  ["Lightning Shield"] = 324, ["Flame Shock"] = 8050, ["Stormstrike"] = 17364, ["Earth Shock"] = 8042,
  ["Lightning Bolt"] = 403, ["Frost Shock"] = 8056, ["Chain Lightning"] = 421, ["Elemental Mastery"] = 16166,
  ["Healing Stream Totem"] = 5394, ["Searing Totem"] = 3599, ["Lava Burst"] = 51505, ["Cure Poison"] = 526,
  -- mage
  ["Frostbolt"] = 116, ["Fireball"] = 133, ["Fire Blast"] = 2136, ["Ice Lance"] = 30455,
  ["Arcane Missiles"] = 5143, ["Arcane Blast"] = 30451, ["Presence of Mind"] = 12043, ["Combustion"] = 11129,
  ["Cone of Cold"] = 120, ["Arcane Power"] = 12042, ["Pyroblast"] = 11366, ["Scorch"] = 2948,
  ["Frostfire Bolt"] = 44614, ["Frost Nova"] = 122,
  -- warlock
  ["Shadow Bolt"] = 686, ["Immolate"] = 348, ["Corruption"] = 172, ["Curse of Agony"] = 980,
  ["Conflagrate"] = 17962, ["Shadowburn"] = 17877, ["Drain Soul"] = 1120, ["Siphon Life"] = 18265,
  ["Searing Pain"] = 5676, ["Soul Fire"] = 6353, ["Incinerate"] = 29722, ["Summon Voidwalker"] = 697,
  ["Summon Succubus"] = 712, ["Summon Felhunter"] = 691, ["Summon Felsteed"] = 5784, ["Summon Dreadsteed"] = 23161,
  -- druid
  ["Moonfire"] = 8921, ["Wrath"] = 5176, ["Starfire"] = 2912, ["Insect Swarm"] = 5570, ["Rake"] = 1822,
  ["Claw"] = 1082, ["Rip"] = 1079, ["Ferocious Bite"] = 22568, ["Maul"] = 6807, ["Swipe"] = 779,
  ["Lacerate"] = 33745, ["Bear Form"] = 5487, ["Dire Bear Form"] = 9634, ["Cat Form"] = 768, ["Aquatic Form"] = 1066,
  ["Demoralizing Roar"] = 99, ["Growl"] = 6795, ["Faerie Fire (Feral)"] = 16857,
  -- riding
  ["Apprentice Riding"] = 33388, ["Journeyman Riding"] = 33391,
}

local function english()
  local l = GetLocale and GetLocale() or "enUS"
  return l == "enUS" or l == "enGB"
end

local function nameOf(id)
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and type(n) == "string" and n ~= "" then return n end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and type(n) == "string" and n ~= "" then return n end
  end
end

local cache, rev = {}, nil

-- English name -> the name this client uses
function S:Local(name)
  if not name or english() then return name end
  local v = cache[name]
  if v == nil then
    local id = self.ID[name]
    v = id and nameOf(id) or name
    cache[name] = v
  end
  return v
end

-- client name -> English name (for the tables that are keyed by English names)
function S:English(name)
  if not name or english() then return name end
  if not rev then
    rev = {}
    for en in pairs(self.ID) do rev[self:Local(en)] = en end
  end
  return rev[name] or name
end

function S:Reset() cache, rev = {}, nil end

-- English clients: entries whose ID belongs to a differently named spell (shown by /ff spells)
function S:Check()
  local bad, n = {}, 0
  for en, id in pairs(self.ID) do
    n = n + 1
    local got = nameOf(id)
    if got and got ~= en then bad[#bad + 1] = ("%s (%d: %s)"):format(en, id, got) end
  end
  table.sort(bad)
  return bad, n
end

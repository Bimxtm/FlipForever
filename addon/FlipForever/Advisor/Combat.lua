-- FlipForever Combat helper: a step button at the top of the screen.
--
-- How it stays within Blizzard's rules: every click casts exactly ONE spell (the one shown),
-- then the button steps to the next one. This is the same technique as the GSE addon: the
-- step happens in Blizzard's secure "restricted" code, which cannot read cooldowns, buffs or
-- your target - so the addon never decides anything for you during combat.
-- What we CAN adapt happens between fights: the sequence is rebuilt from your chosen build,
-- the spells you actually know (so it follows your level), and the target you select
-- (creature type -> immunities, extra spells like Exorcism vs undead).
local FF = FlipForever
local G = FF.Guide
local C = {}
FF.Combat = C

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

-- Sequences per class / build. A step is a spell name or a list of alternatives
-- (the first one you know is used). prefix: lines run before every cast.
local MELEE = "/startattack\n"
local PET = "/petattack\n"
C.SEQ = {
  WARRIOR = {
    arms = { prefix = MELEE, steps = { "Battle Shout", "Rend", { "Mortal Strike", "Heroic Strike" }, "Heroic Strike", { "Mortal Strike", "Heroic Strike" }, "Heroic Strike" } },
    prot = { prefix = MELEE, steps = { "Battle Shout", "Thunder Clap", "Sunder Armor", "Heroic Strike", "Sunder Armor", { "Shield Slam", "Heroic Strike" } } },
    default = { prefix = MELEE, steps = { "Battle Shout", "Rend", "Heroic Strike", "Heroic Strike" } },
    low = { prefix = MELEE, steps = { "Battle Shout", "Rend", "Heroic Strike", "Heroic Strike", "Heroic Strike" } },
  },
  PALADIN = {
    default = { prefix = MELEE, steps = { { "Seal of Command", "Seal of Righteousness" }, "Judgement", "Holy Strike", { "Consecration", "Holy Strike" }, "Holy Strike" } },
    -- levels 1-10: seal, judge it as soon as you can, seal again (auto-attack does the rest)
    low = { prefix = MELEE, steps = { "Seal of Righteousness", "Judgement", "Seal of Righteousness" } },
  },
  HUNTER = {
    default = { prefix = PET, steps = { "Hunter's Mark", "Serpent Sting", "Arcane Shot", { "Aimed Shot", "Arcane Shot" }, { "Multi-Shot", "Arcane Shot" } } },
    -- levels 1-10, no pet yet: shoot, sting, and Raptor Strike once they reach you
    low = { steps = { { "Hunter's Mark", "Auto Shot" }, { "Serpent Sting", "Auto Shot" }, { "Arcane Shot", "Raptor Strike" }, "Raptor Strike" } },
  },
  ROGUE = {
    sub_bleed = { prefix = MELEE, steps = { { "Hemorrhage", "Sinister Strike" }, { "Hemorrhage", "Sinister Strike" }, "Slice and Dice", { "Hemorrhage", "Sinister Strike" }, { "Hemorrhage", "Sinister Strike" }, "Eviscerate" } },
    default = { prefix = MELEE, steps = { "Sinister Strike", "Sinister Strike", "Slice and Dice", "Sinister Strike", "Sinister Strike", "Eviscerate" } },
    low = { prefix = MELEE, steps = { "Sinister Strike", "Sinister Strike", "Eviscerate" } },
  },
  PRIEST = {
    default = { steps = { "Power Word: Shield", "Shadow Word: Pain", "Mind Blast", { "Mind Flay", "Smite" }, { "Mind Flay", "Smite" } } },
    low = { steps = { "Power Word: Shield", "Shadow Word: Pain", "Smite", "Smite", "Smite" } },
  },
  SHAMAN = {
    enh = { prefix = MELEE, steps = { "Lightning Shield", "Flame Shock", { "Stormstrike", "Earth Shock" }, "Earth Shock", { "Stormstrike", "Lightning Bolt" } } },
    default = { steps = { "Lightning Shield", "Flame Shock", "Lightning Bolt", "Earth Shock", "Lightning Bolt" } },
    low = { prefix = MELEE, steps = { "Lightning Bolt", "Earth Shock", "Lightning Bolt" } },
  },
  MAGE = {
    frost = { steps = { "Frostbolt", "Frostbolt", { "Ice Lance", "Fire Blast" }, "Frostbolt", "Fire Blast" } },
    default = { steps = { { "Frostbolt", "Fireball" }, { "Frostbolt", "Fireball" }, "Fire Blast", { "Frostbolt", "Fireball" } } },
  },
  WARLOCK = {
    aff = { prefix = PET, steps = { "Corruption", { "Bane of Agony", "Curse of Agony" }, "Siphon Life", "Shadow Bolt", "Shadow Bolt", "Shadow Bolt" } },
    default = { prefix = PET, steps = { "Corruption", { "Bane of Agony", "Curse of Agony" }, "Immolate", "Shadow Bolt", "Shadow Bolt" } },
    low = { prefix = PET, steps = { "Immolate", "Corruption", "Shadow Bolt", "Shadow Bolt" } },
  },
  DRUID = {
    -- Cat steps are only used once you know Cat Form (stay in Cat Form while using it)
    feral = { prefix = MELEE, requires = "Cat Form", steps = { "Rake", "Claw", "Claw", "Rip", "Claw", "Claw", "Ferocious Bite" } },
    default = { steps = { "Moonfire", "Wrath", "Wrath", "Wrath" } },
  },
}

-- Levels 40-60: the full rotations with the later abilities and talents, per build. Anything you
-- don't know yet is skipped (alternatives in { } are tried in order), so a build keeps working
-- while you collect its spells. No reactive abilities (Overpower, Revenge, Riposte): a step that
-- can't fire would waste a key press.
local HIGH = {
  WARRIOR = {
    arms = { prefix = MELEE, steps = { "Battle Shout", "Rend", { "Mortal Strike", "Heroic Strike" }, { "Whirlwind", "Heroic Strike" },
      "Heroic Strike", { "Mortal Strike", "Heroic Strike" }, { "Sweeping Strikes", "Heroic Strike" } } },
    prot = { prefix = MELEE, steps = { "Battle Shout", "Thunder Clap", "Sunder Armor", { "Shield Slam", "Heroic Strike" },
      "Sunder Armor", { "Concussion Blow", "Heroic Strike" }, { "Demoralizing Shout", "Heroic Strike" } } },
    default = { prefix = MELEE, steps = { "Battle Shout", "Rend", { "Bloodthirst", "Mortal Strike", "Heroic Strike" },
      { "Whirlwind", "Heroic Strike" }, "Heroic Strike", { "Bloodthirst", "Mortal Strike", "Heroic Strike" } } },
  },
  PALADIN = {
    default = { prefix = MELEE, steps = { { "Seal of Command", "Seal of Righteousness" }, "Judgement", "Holy Strike",
      { "Consecration", "Holy Strike" }, { "Seal of Command", "Seal of Righteousness" }, "Holy Strike", { "Repentance", "Holy Strike" } } },
  },
  HUNTER = {
    bm = { prefix = PET, steps = { "Hunter's Mark", { "Bestial Wrath", "Serpent Sting" }, "Serpent Sting", "Arcane Shot",
      { "Multi-Shot", "Arcane Shot" }, { "Rapid Fire", "Arcane Shot" } } },
    default = { prefix = PET, steps = { "Hunter's Mark", "Serpent Sting", { "Aimed Shot", "Arcane Shot" }, { "Multi-Shot", "Arcane Shot" },
      { "Rapid Fire", "Arcane Shot" }, { "Aimed Shot", "Arcane Shot" } } },
  },
  ROGUE = {
    combat = { prefix = MELEE, steps = { "Sinister Strike", "Slice and Dice", "Sinister Strike", { "Blade Flurry", "Sinister Strike" },
      "Sinister Strike", { "Adrenaline Rush", "Sinister Strike" }, "Eviscerate" } },
    sub_bleed = { prefix = MELEE, steps = { "Hemorrhage", "Hemorrhage", "Slice and Dice", "Hemorrhage", "Hemorrhage", { "Rupture", "Eviscerate" },
      "Hemorrhage", "Eviscerate" } },
    default = { prefix = MELEE, steps = { "Sinister Strike", "Slice and Dice", "Sinister Strike", "Sinister Strike", "Sinister Strike", "Eviscerate" } },
  },
  PRIEST = {
    default = { steps = { "Power Word: Shield", { "Vampiric Embrace", "Shadow Word: Pain" }, "Shadow Word: Pain", "Mind Blast",
      { "Mind Flay", "Smite" }, { "Mind Flay", "Smite" }, "Mind Blast", { "Mind Flay", "Smite" } } },
  },
  SHAMAN = {
    enh = { prefix = MELEE, steps = { "Lightning Shield", { "Stormstrike", "Earth Shock" }, "Flame Shock", { "Stormstrike", "Earth Shock" },
      "Earth Shock", { "Stormstrike", "Lightning Bolt" } } },
    ele_wct = { steps = { "Flame Shock", "Lightning Bolt", { "Chain Lightning", "Lightning Bolt" }, "Earth Shock", "Lightning Bolt",
      { "Elemental Mastery", "Lightning Bolt" } } },
    default = { steps = { "Lightning Shield", "Flame Shock", "Lightning Bolt", { "Chain Lightning", "Lightning Bolt" }, "Earth Shock", "Lightning Bolt" } },
  },
  MAGE = {
    frost = { steps = { "Frostbolt", "Frostbolt", { "Ice Lance", "Fire Blast" }, "Frostbolt", { "Presence of Mind", "Frostbolt" }, "Frostbolt",
      { "Arcane Missiles", "Fire Blast" } } },
    default = { steps = { { "Frostbolt", "Fireball" }, { "Frostbolt", "Fireball" }, "Fire Blast", { "Frostbolt", "Fireball" },
      { "Scorch", "Fire Blast" }, { "Frostbolt", "Fireball" } } },
  },
  WARLOCK = {
    aff = { prefix = PET, steps = { "Corruption", { "Bane of Agony", "Curse of Agony" }, "Siphon Life", "Shadow Bolt",
      { "Drain Soul", "Shadow Bolt" }, "Shadow Bolt", "Shadow Bolt" } },
    default = { prefix = PET, steps = { "Corruption", { "Bane of Agony", "Curse of Agony" }, "Immolate", "Shadow Bolt",
      { "Conflagrate", "Shadow Bolt" }, "Shadow Bolt" } },
  },
  DRUID = {
    feral = { prefix = MELEE, requires = "Cat Form", steps = { { "Faerie Fire (Feral)", "Rake" }, "Rake", "Claw", "Claw", "Rip",
      "Claw", "Claw", "Ferocious Bite" } },
    default = { steps = { "Moonfire", { "Insect Swarm", "Wrath" }, { "Starfire", "Wrath" }, "Wrath", { "Starfire", "Wrath" } } },
  },
}
for class, t in pairs(HIGH) do if C.SEQ[class] then C.SEQ[class].high = t end end

-- Rotations for the other builds in the guides (GuideBuilds.lua sets each build's "combat" key).
-- Used from level 11; spells you don't know yet are skipped, so one list covers 11-60.
local MORE = {
  WARRIOR = {
    fury = { prefix = MELEE, steps = { "Battle Shout", { "Bloodthirst", "Heroic Strike" }, { "Whirlwind", "Heroic Strike" }, "Heroic Strike",
      { "Bloodthirst", "Heroic Strike" }, "Sunder Armor" } },
  },
  PALADIN = {
    prot = { prefix = MELEE, steps = { { "Seal of Fury", "Seal of Righteousness" }, "Judgement", { "Consecration", "Holy Strike" },
      { "Holy Shield", "Holy Strike" }, "Holy Strike", { "Swift Judgement", "Judgement" } } },
    holy = { prefix = MELEE, steps = { "Seal of Righteousness", "Judgement", { "Holy Shock", "Holy Strike" }, "Holy Strike" } },
  },
  HUNTER = {
    mm = { prefix = PET, steps = { "Hunter's Mark", { "Sniper Shot", "Aimed Shot", "Arcane Shot" }, "Serpent Sting", { "Aimed Shot", "Arcane Shot" },
      "Arcane Shot", { "Rapid Fire", "Arcane Shot" } } },
    sv = { prefix = MELEE, steps = { "Serpent Sting", "Arcane Shot", { "Mongoose Bite", "Raptor Strike" }, "Raptor Strike",
      { "Strider Kick", "Raptor Strike" }, { "Rapid Fire", "Raptor Strike" } } },
  },
  ROGUE = {
    dagger = { prefix = MELEE, steps = { { "Backstab", "Sinister Strike" }, { "Backstab", "Sinister Strike" }, "Slice and Dice",
      { "Backstab", "Sinister Strike" }, { "Backstab", "Sinister Strike" }, "Eviscerate" } },
    assa = { prefix = MELEE, steps = { { "Mutilate", "Sinister Strike" }, { "Mutilate", "Sinister Strike" }, "Slice and Dice",
      { "Mutilate", "Sinister Strike" }, { "Venom", "Eviscerate" }, "Eviscerate" } },
    sub = { prefix = MELEE, steps = { { "Hemorrhage", "Sinister Strike" }, { "Ghostly Strike", "Hemorrhage", "Sinister Strike" }, "Slice and Dice",
      { "Hemorrhage", "Sinister Strike" }, { "Hemorrhage", "Sinister Strike" }, { "Death Mark", "Eviscerate" }, "Eviscerate" } },
  },
  PRIEST = {
    shadow = { steps = { "Shadow Word: Pain", { "Devouring Plague", "Mind Blast" }, "Mind Blast", { "Shadow Word: Death", "Mind Flay", "Smite" },
      { "Vampiric Embrace", "Mind Flay", "Smite" }, { "Mind Flay", "Smite" } } },
    holy = { steps = { { "Holy Fire", "Smite" }, "Shadow Word: Pain", "Smite", "Smite" } },
  },
  SHAMAN = {
    ele = { steps = { "Flame Shock", { "Lava Burst", "Lightning Bolt" }, "Lightning Bolt", { "Chain Lightning", "Lightning Bolt" }, "Earth Shock" } },
    resto = { steps = { "Flame Shock", "Lightning Bolt", "Earth Shock", "Lightning Bolt" } },
  },
  MAGE = {
    fire = { steps = { { "Pyroblast", "Fireball" }, "Fireball", { "Scorch", "Fireball" }, "Fire Blast", "Fireball", { "Combustion", "Fireball" } } },
    frostfire = { steps = { { "Frostfire Bolt", "Frostbolt" }, { "Frostfire Bolt", "Frostbolt" }, "Fire Blast", { "Ice Lance", "Frostbolt" },
      { "Pyroblast", "Frostfire Bolt", "Frostbolt" } } },
    arcane = { steps = { { "Arcane Blast", "Arcane Missiles" }, { "Arcane Blast", "Arcane Missiles" }, "Arcane Missiles", { "Arcane Blast", "Arcane Missiles" },
      { "Arcane Wrath", "Arcane Missiles" }, "Fire Blast" } },
  },
  WARLOCK = {
    wrack = { prefix = PET, steps = { "Corruption", { "Bane of Agony", "Curse of Agony" }, "Siphon Life", { "Wrack", "Shadow Bolt" }, { "Wrack", "Shadow Bolt" } } },
    demo = { prefix = PET, steps = { { "Searing Pain", "Immolate" }, "Immolate", { "Bane of Agony", "Curse of Agony" }, "Corruption",
      { "Soul Fire", "Searing Pain", "Shadow Bolt" }, { "Searing Pain", "Shadow Bolt" } } },
    demo_shadow = { prefix = PET, steps = { { "Searing Pain", "Immolate" }, "Immolate", "Corruption", "Shadow Bolt", "Shadow Bolt" } },
    destro = { prefix = PET, steps = { "Immolate", "Corruption", { "Conflagrate", "Incinerate", "Shadow Bolt" }, { "Shadowburn", "Incinerate", "Shadow Bolt" },
      { "Incinerate", "Shadow Bolt" }, { "Incinerate", "Shadow Bolt" } } },
  },
  DRUID = {
    bear = { prefix = MELEE, requires = "Bear Form", steps = { { "Faerie Fire (Feral)", "Demoralizing Roar" }, "Demoralizing Roar",
      { "Primal Bite", "Maul" }, { "Lacerate", "Maul" }, { "Lacerate", "Maul" }, { "Swipe", "Maul" } } },
    balance = { steps = { "Moonfire", { "Insect Swarm", "Wrath" }, { "Starfire", "Wrath" }, { "Starfire", "Wrath" }, "Wrath" } },
  },
}
for class, t in pairs(MORE) do
  local cls = C.SEQ[class]
  if cls then
    cls.high = cls.high or {}
    for key, seq in pairs(t) do
      cls[key] = cls[key] or seq
      cls.high[key] = cls.high[key] or seq
    end
  end
end
-- builds that share a rotation under another name
C.SEQ.SHAMAN.high.ele = C.SEQ.SHAMAN.high.ele_wct
C.SEQ.PALADIN.ret = C.SEQ.PALADIN.default

-- What each spell is, for immunities
local TAG = {
  Rend = "bleed", Rip = "bleed", Rake = "bleed", Garrote = "bleed", Rupture = "bleed", Hemorrhage = "physical",
  Fireball = "fire", ["Fire Blast"] = "fire", Immolate = "fire", ["Flame Shock"] = "fire", ["Searing Pain"] = "fire",
  Frostbolt = "frost", ["Ice Lance"] = "frost", ["Frost Shock"] = "frost", ["Cone of Cold"] = "frost",
  ["Serpent Sting"] = "poison", Corruption = "shadow", ["Shadow Bolt"] = "shadow",
  Scorch = "fire", Conflagrate = "fire", ["Drain Soul"] = "shadow", ["Siphon Life"] = "shadow",
  Pyroblast = "fire", Incinerate = "fire", ["Soul Fire"] = "fire", ["Lava Burst"] = "fire", Shadowburn = "shadow",
  ["Devouring Plague"] = "shadow", ["Shadow Word: Death"] = "shadow", Wrack = "shadow", Lacerate = "bleed",
}

-- Creature types: what doesn't work, what works extra, and crowd control
C.TYPES = {
  Elemental  = { no = { bleed = true }, cc = "Banish (warlock)", note = "Elementals: bleeds don't work; fire/water ones are immune to their own school." },
  Mechanical = { no = { bleed = true, poison = true }, cc = "none of the usual", note = "Mechanical: bleeds and poisons don't work." },
  Undead     = { extra = { PALADIN = { "Exorcism" } }, cc = "Shackle Undead (priest), Turn Undead (paladin)", note = "Undead: Exorcism works; Polymorph doesn't." },
  Demon      = { extra = { PALADIN = { "Exorcism" } }, cc = "Banish / Enslave Demon (warlock)", note = "Demon: Exorcism works; Polymorph doesn't." },
  Beast      = { cc = "Polymorph, Hibernate, Scare Beast, Freezing Trap", note = "Beast." },
  Humanoid   = { cc = "Polymorph, Sap, Freezing Trap", note = "Humanoid: many run away at low health - finish them fast." },
  Dragonkin  = { cc = "Hibernate, Sap", note = "Dragonkin." },
}

local function schoolImmunity(name)
  if not name then return nil end
  local n = name:lower()
  if n:find("fire") or n:find("flame") or n:find("magma") or n:find("lava") or n:find("ember") then return "fire" end
  if n:find("water") or n:find("frost") or n:find("ice") or n:find("tide") or n:find("snow") then return "frost" end
  return nil
end

-- Target read (out of combat this always works; in combat some values may be hidden)
function C:Target()
  if not UnitExists("target") or not UnitCanAttack("player", "target") then return nil end
  local t = {
    name = plain(UnitName("target")),
    ctype = plain(UnitCreatureType("target")),
    level = plain(UnitLevel("target")),
    class = plain(UnitClassification("target")),
    power = plain(UnitPowerType("target")),
  }
  t.immune = {}
  local info = t.ctype and C.TYPES[t.ctype]
  if info and info.no then for k in pairs(info.no) do t.immune[k] = true end end
  if t.ctype == "Elemental" then
    local school = schoolImmunity(t.name)
    if school then t.immune[school] = true end
  end
  return t
end

function C:TargetHint(t)
  if not t then return "" end
  local parts = {}
  local info = t.ctype and C.TYPES[t.ctype]
  parts[#parts + 1] = (t.ctype or "?")
  if info and info.note then parts[#parts + 1] = info.note end
  local me = UnitLevel("player") or 1
  if t.level == -1 or (t.level and t.level - me >= 4) then parts[#parts + 1] = "|cffff5555much higher level - skip or get help|r"
  elseif t.level and t.level - me >= 2 then parts[#parts + 1] = "|cffffaa00tough (higher level)|r" end
  if t.class == "elite" or t.class == "rareelite" or t.class == "worldboss" then parts[#parts + 1] = "|cffff5555elite: use cooldowns or a group|r"
  elseif t.class == "rare" then parts[#parts + 1] = "|cffa335eerare - good loot|r" end
  if t.power == 0 and t.ctype == "Humanoid" then parts[#parts + 1] = "caster: interrupt its heals/spells" end
  if info and info.cc then parts[#parts + 1] = "CC: " .. info.cc end
  return table.concat(parts, "  ·  ")
end

-- Build the step list ------------------------------------------------------------------------------
-- forceKey: one rotation regardless of the build (druid forms: "bear", "feral", "default")
function C:BuildSteps(forceKey)
  local AD = FF.Advisor
  local p = AD:Player()
  local build = AD:Build(p)
  local cls = C.SEQ[p.class]
  if not cls then return {}, "" end
  -- three level bands: 1-10 starter spells, 11-39 the build's core, 40-60 the full rotation
  local level = p.level or 60
  local key = forceKey or (build and (build.combat or build.id)) or "default"
  local known = AD:KnownSpells()
  local seq
  if forceKey then
    seq = (level >= 40 and cls.high and cls.high[forceKey]) or cls[forceKey]
  elseif level <= 10 and cls.low then
    seq = cls.low
  elseif level >= 40 and cls.high then
    seq = cls.high[key] or cls.high.default
    if seq and seq.requires and not known[seq.requires] then seq = cls.high.default end
  end
  seq = seq or cls[key] or (build and cls[build.id]) or cls.default
  if seq.requires and not known[seq.requires] and not forceKey then seq = cls.default end
  self.band = (level <= 10 and cls.low and "1-10") or (level >= 40 and cls.high and "40-60") or "11-39"
  local target = self:Target()
  local immune = target and target.immune or {}

  local function usable(name)
    if not known[name] then return false end
    local tag = TAG[name]
    return not (tag and immune[tag])
  end

  -- when the target is immune to a spell, use this one instead
  local SWAP = { Frostbolt = "Fireball", Fireball = "Frostbolt", ["Ice Lance"] = "Fire Blast", ["Fire Blast"] = "Ice Lance",
    Rake = "Claw", Rip = "Ferocious Bite", Rend = "Heroic Strike", Immolate = "Shadow Bolt", ["Flame Shock"] = "Earth Shock",
    ["Serpent Sting"] = "Arcane Shot", Garrote = "Cheap Shot", Rupture = "Eviscerate" }
  local function pickOne(name)
    if usable(name) then return name end
    local swap = SWAP[name]
    if known[name] and swap and usable(swap) then return swap end
    return nil
  end

  local steps = {}
  for _, s in ipairs(seq.steps) do
    local pick
    if type(s) == "table" then
      for _, alt in ipairs(s) do pick = pickOne(alt) if pick then break end end
    else
      pick = pickOne(s)
    end
    if pick then steps[#steps + 1] = pick end
  end
  -- target-type extras (e.g. Exorcism vs undead/demons) go right after the opener
  local info = target and target.ctype and C.TYPES[target.ctype]
  local extra = info and info.extra and info.extra[p.class]
  if extra then
    for _, sp in ipairs(extra) do
      if known[sp] then table.insert(steps, math.min(3, #steps + 1), sp) end
    end
  end
  -- a frost mage against a frost-immune target: swap to fire / arcane
  if #steps == 0 then
    for _, sp in ipairs({ "Fireball", "Arcane Missiles", "Shadow Bolt", "Wrath", "Lightning Bolt", "Smite", "Heroic Strike", "Sinister Strike", "Arcane Shot", "Holy Strike", "Raptor Strike", "Seal of Righteousness" }) do
      if usable(sp) then steps[1] = sp break end
    end
  end
  return steps, seq.prefix or ""
end

-- The secure button -------------------------------------------------------------------------------
local btn, small1, small2, hintText, bar
local pendingRebuild = false

local function iconOf(spell)
  if not spell then return nil end
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spell) end
  if GetSpellTexture then return GetSpellTexture(spell) end
end

function C:UpdateIcons()
  if not btn then return end
  if self.assist then
    -- Blizzard decides; show what it suggests next
    local AC = C_AssistedCombat
    local ok, nextId = pcall(AC and AC.GetNextCastSpell or function() end, false)
    nextId = ok and plain(nextId) or nil
    btn.icon:SetTexture(iconOf(nextId or self.assist) or "Interface\\Icons\\INV_Misc_QuestionMark")
    small1:SetTexture(nil)
    small2:SetTexture(nil)
    if small1.cd then small1.cd:SetText("") small2.cd:SetText("") end
    local name = nextId and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(nextId)
    btn.label:SetText((name or "Blizzard assistant") .. "  |cff888888(Blizzard mode)|r")
  elseif self.buffs and self.buffs[1] and not InCombatLockdown() then
    -- out of combat with a buff missing: the next press casts it
    btn.icon:SetTexture(iconOf(self.buffs[1]) or "Interface\\Icons\\INV_Misc_QuestionMark")
    small1:SetTexture(iconOf(self.buffs[2]))
    small2:SetTexture(nil)
    if small1.cd then small1.cd:SetText("") small2.cd:SetText("") end
    btn.label:SetText(FF:T("%s (before the fight)"):format(self.buffs[1]))
  elseif self.cds or self.seq then
    -- smart mode: the big icon is what the next press will cast; the small ones are your
    -- cooldown abilities, dimmed while they aren't ready
    local nextSpell = self:SmartNext()
    btn.icon:SetTexture(iconOf(nextSpell) or "Interface\\Icons\\INV_Misc_QuestionMark")
    local others = {}
    for _, s in ipairs(self.cds or {}) do if s ~= nextSpell then others[#others + 1] = s end end
    for k, tex in ipairs({ small1, small2 }) do
      local s = others[k]
      tex:SetTexture(iconOf(s))
      if tex.SetDesaturated then tex:SetDesaturated(s ~= nil and C.CooldownLeft(s) > 1.6) end
      if tex.cd then tex.cd:SetText(C.CooldownText(s)) end
    end
    btn.label:SetText(nextSpell or "no spells yet")
  else
    local steps = self.steps or {}
    -- druids: the rotation of the form you're in
    if self.formSteps and GetShapeshiftForm then
      steps = self.formSteps[GetShapeshiftForm() or 0] or self.formSteps[0] or steps
    end
    local n = #steps
    local s = btn:GetAttribute("step") or 1
    local function stepSpell(k) return n > 0 and steps[((s - 1 + k) % n) + 1] or nil end
    btn.icon:SetTexture(iconOf(stepSpell(0)) or "Interface\\Icons\\INV_Misc_QuestionMark")
    small1:SetTexture(iconOf(stepSpell(1)))
    small2:SetTexture(iconOf(stepSpell(2)))
    if small1.cd then small1.cd:SetText("") small2.cd:SetText("") end
    btn.label:SetText(stepSpell(0) or "no spells yet")
  end
  local t = self:Target()
  local hint = t and self:TargetHint(t) or ""
  local ally = self:AllyUnderAttack()
  if ally then hint = ("|cffff5555Your target is attacking %s!|r  "):format(ally) .. hint end
  local threat = self:ThreatWarning()
  if threat then hint = threat .. "  " .. hint end
  hintText:SetText(hint)
end

-- One-key targeting -------------------------------------------------------------------------------
-- Blizzard only lets macros choose targets in simple, allowed ways: the nearest enemy
-- (/targetenemy) and "the target of my friendly target" (/assist). That's what we use; the
-- addon itself never picks a target from game state during combat.
local TANK_BUILDS = { WARRIOR = { prot = true }, PALADIN = { prot = true }, DRUID = { bear = true } }

function C:IsTank()
  local s = FlipForeverDB.settings
  if s.combatTank ~= nil then return s.combatTank end -- you ticked/unticked it yourself
  local AD = FF.Advisor
  local p = AD:Player()
  local build = AD:Build(p)
  if build and build.role == "tank" then return true end
  return (TANK_BUILDS[p.class] and build and TANK_BUILDS[p.class][build.id]) and true or false
end

function C:AutoTarget() return FlipForeverDB.settings.combatTarget ~= false end

function C:TargetPrefix()
  if not self:AutoTarget() then return "" end
  local lines = ""
  -- tank: clicked a party member? take whatever is attacking them
  if self:IsTank() then lines = lines .. "/assist [help,nodead]\n" end
  -- no target, a dead one or a friendly one: take the nearest enemy
  return lines .. "/targetenemy [noharm][dead]\n"
end

-- shown above the icons when your enemy target is beating on someone else (tanks care)
function C:AllyUnderAttack()
  if not (UnitExists("target") and UnitCanAttack("player", "target")) then return nil end
  if not UnitExists("targettarget") then return nil end
  local ok, friendly = pcall(UnitIsFriend, "player", "targettarget")
  local ok2, isMe = pcall(UnitIsUnit, "targettarget", "player")
  if not (ok and ok2) or not plain(friendly) or plain(isMe) then return nil end
  return plain(UnitName("targettarget"))
end

-- Threat on your target, from the game's threat API. Non-tanks: a warning from 85% of the threat
-- that pulls aggro, and when the target is on you. Tanks: a warning when you lose it.
-- Setting: threatWarning (on by default).
function C:ThreatWarning()
  if FlipForeverDB.settings.threatWarning == false then return nil end
  if not (UnitDetailedThreatSituation and UnitExists("target") and UnitCanAttack("player", "target")) then return nil end
  local ok, tanking, status, scaled = pcall(UnitDetailedThreatSituation, "player", "target")
  if not ok then return nil end
  tanking, status, scaled = plain(tanking), plain(status), tonumber(plain(scaled))
  if status == nil then return nil end -- no threat on this target yet
  if self:IsTank() then
    if not tanking and (status or 0) < 2 and UnitExists("targettarget") then
      return FF:T("|cffff5555You lost aggro - taunt or hit it hard|r")
    end
    return nil
  end
  if tanking then return FF:T("|cffff5555It's attacking you!|r") end
  if scaled and scaled >= 85 then return FF:T("|cffff8800Threat %d%% - ease off|r"):format(math.floor(scaled)) end
  return nil
end

-- Blizzard's own one-button rotation, if this client has it (retail-style Assisted Combat)
function C:BlizzardAssistSpell()
  local AC = C_AssistedCombat
  if not (AC and AC.GetActionSpell) then return nil end
  local ok, avail = pcall(AC.IsAvailable or function() return true end)
  if ok and avail == false then return nil end
  local ok2, id = pcall(AC.GetActionSpell)
  return ok2 and id or nil
end

-- Smart mode: one macro the game itself evaluates on every press -------------------------------
-- Cooldown abilities get their own "/cast" lines: the game casts one the moment it's ready and
-- skips the line silently while it isn't. Everything else goes into a "/castsequence", which
-- only moves on after a successful cast - so a spell that isn't ready is never skipped.
-- (Addons can't check cooldowns themselves in combat; the game's macro system can.)
local KNOWN_CD = {}
for _, s in ipairs({ "Mortal Strike", "Bloodthirst", "Whirlwind", "Shield Slam", "Sweeping Strikes", "Concussion Blow",
  "Thunder Clap", "Taunt", "Growl", "Righteous Defense", "Judgement", "Swift Judgement", "Holy Shock", "Consecration",
  "Holy Shield", "Exorcism", "Hammer of Wrath", "Repentance", "Aimed Shot", "Multi-Shot", "Arcane Shot", "Rapid Fire",
  "Bestial Wrath", "Sniper Shot", "Mongoose Bite", "Strider Kick", "Blade Flurry", "Adrenaline Rush", "Ghostly Strike",
  "Death Mark", "Shank", "Mind Blast", "Shadow Word: Death", "Penance", "Devouring Plague", "Power Word: Shield",
  "Stormstrike", "Earth Shock", "Flame Shock", "Frost Shock", "Lava Burst", "Chain Lightning", "Elemental Mastery",
  "Fire Blast", "Presence of Mind", "Combustion", "Cone of Cold", "Arcane Power", "Conflagrate", "Shadowburn",
  "Faerie Fire (Feral)", "Primal Bite", "Wrack", "Bane of Doom" }) do KNOWN_CD[s] = true end

function C:Smart() return FlipForeverDB.settings.combatSmart ~= false end

-- does this spell have its own cooldown (beyond the global one)?
function C:HasCooldown(spell)
  local id
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spell)
    id = info and info.spellID
  elseif GetSpellInfo then
    id = select(7, GetSpellInfo(spell))
  end
  if id and GetSpellBaseCooldown then
    local ok, ms = pcall(GetSpellBaseCooldown, id)
    if ok and type(ms) == "number" then return ms > 1500 end
  end
  return KNOWN_CD[spell] or KNOWN_CD[FF.Spells:English(spell)] or false
end

-- the macro text for the steps; also returns the cooldown spells and the sequence spells
function C:SmartMacro(prefix, steps)
  local cds, seq, seen = {}, {}, {}
  for _, s in ipairs(steps) do
    if self:HasCooldown(s) then
      if not seen[s] then seen[s] = true cds[#cds + 1] = s end
    else
      seq[#seq + 1] = s
    end
  end
  local function render(nseq)
    local lines = prefix
    for _, s in ipairs(cds) do lines = lines .. "/cast " .. s .. "\n" end
    if nseq > 0 then lines = lines .. "/castsequence reset=target/combat " .. table.concat(seq, ", ", 1, nseq) end
    return lines
  end
  -- macros are limited to 255 characters: drop sequence spells from the end until it fits
  local n = #seq
  local text = render(n)
  while #text > 255 and n > 1 do n = n - 1 text = render(n) end
  for i = #seq, n + 1, -1 do seq[i] = nil end
  return text, cds, seq
end

local function cooldownLeft(spell)
  local start, dur
  if C_Spell and C_Spell.GetSpellCooldown then
    local cd = C_Spell.GetSpellCooldown(spell)
    if cd then start, dur = cd.startTime, cd.duration end
  elseif GetSpellCooldown then
    start, dur = GetSpellCooldown(spell)
  end
  start, dur = plain(start), plain(dur)
  if not start or start == 0 or not dur then return 0 end
  return math.max(0, start + dur - GetTime())
end
C.CooldownLeft = cooldownLeft

-- seconds left as shown on the small icons: "" when ready (or only the global cooldown)
function C.CooldownText(spell)
  if not spell then return "" end
  local left = cooldownLeft(spell)
  if left <= 1.6 then return "" end
  if left >= 60 then return ("%dm"):format(math.ceil(left / 60)) end
  return tostring(math.ceil(left))
end

-- the cast sequence's next spell: followed from your own successful casts (the game resets the
-- sequence on a new target and after the fight, and so do we); the game's answer only fills in
-- before the first cast. QueryCastSequence returns the position first and the names after it.
function C:SeqNext()
  local seq = self.seq
  if not seq or #seq == 0 then return nil end
  if self.seqPos then return seq[self.seqPos] end
  if QueryCastSequence and self.seqText then
    local r = { pcall(QueryCastSequence, self.seqText) }
    if r[1] then
      for i = 2, #r do
        if type(r[i]) == "string" and r[i] ~= "" then return r[i] end
      end
    end
  end
  return seq[1]
end

-- what the button will cast next: a ready cooldown, else the cast sequence's next spell
function C:SmartNext()
  if self.seqFirst then
    -- paladins: the seal and Judgement come first whenever the next one can be cast
    local nextSeq = self:SeqNext()
    if nextSeq and cooldownLeft(nextSeq) <= 1.6 then return nextSeq end
    for _, s in ipairs(self.cds or {}) do
      if cooldownLeft(s) <= 1.6 then return s end
    end
    return (self.fill or {})[1] or nextSeq
  end
  for _, s in ipairs(self.cds or {}) do
    if cooldownLeft(s) <= 1.6 then return s end      -- ready (or only the global cooldown left)
  end
  local seq = self.seq or {}
  if #seq == 0 then
    -- one step per press: the spell of the current step
    local s = btn and btn:GetAttribute("step") or 1
    return (self.steps or {})[s]
  end
  return self:SeqNext()
end

-- a successful cast of the sequence's current spell moves it on (display only; the game casts)
function C:OnCastSucceeded(spellID)
  local seq = self.seq
  if not (seq and #seq > 0) then return end
  spellID = plain(spellID)
  local name = spellID and ((C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID))
    or (GetSpellInfo and GetSpellInfo(spellID)))
  if not name then return end
  local pos = self.seqPos or 1
  if name == seq[pos] then self.seqPos = pos % #seq + 1 end
end

-- Buffs before a fight (setting combatBuffs, on by default) -------------------------------------
-- Out of combat the addon may look at your buffs: a missing one is put in front of the button as
-- "/cast [nocombat] ...", so the first presses before a pull cast it. In combat the line never
-- fires, and the button is rebuilt without it once the buff is up.
-- Each entry: spells to try in order (the first you know is cast); any of them counts as present.
C.BUFFS = {
  PALADIN = { { "Blessing of Might", "Blessing of Wisdom" }, { "Devotion Aura", "Retribution Aura" } },
  PRIEST = { { "Power Word: Fortitude" }, { "Inner Fire" } },
  MAGE = { { "Arcane Intellect" }, { "Molten Armor", "Mage Armor", "Ice Armor", "Frost Armor" } },
  DRUID = { { "Mark of the Wild" }, { "Thorns" } },
  WARLOCK = { { "Fel Armor", "Demon Armor", "Demon Skin" } },
  HUNTER = { { "Aspect of the Hawk", "Aspect of the Monkey" } },
}
-- per build: a holy paladin wants Wisdom, a tank paladin Righteous Fury
C.BUILD_BUFFS = {
  PALADIN = {
    holy = { { "Blessing of Wisdom", "Blessing of Might" }, { "Devotion Aura" } },
    prot = { { "Righteous Fury" }, { "Blessing of Might", "Blessing of Wisdom" }, { "Devotion Aura", "Retribution Aura" } },
  },
}
-- any buff whose name starts like this also counts (you picked another aspect yourself)
local BUFF_FAMILY = { ["Aspect of the Hawk"] = "Aspect of", ["Aspect of the Monkey"] = "Aspect of" }

function C:BuffsOn() return FlipForeverDB.settings.combatBuffs ~= false end

-- your buff names, or nil when the game keeps them hidden right now (auras can be secret around
-- fights; reading them then raises an error, so it is done in a protected call)
local function playerBuffNames()
  local names = {}
  for i = 1, 40 do
    local ok, raw
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
      ok, raw = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
      if ok and raw ~= nil and issecretvalue and issecretvalue(raw) then return nil end
      if ok and raw then raw = raw.name end
    elseif UnitBuff then
      ok, raw = pcall(UnitBuff, "player", i)
    else
      ok = true
    end
    if not ok then return nil end
    if raw == nil then break end
    local name = plain(raw)
    if not name then return nil end
    names[#names + 1] = name
  end
  return names
end
C.PlayerBuffNames = playerBuffNames

-- the buffs to cast before the next fight, in the client's language
function C:MissingBuffs()
  if not self:BuffsOn() then return {} end
  local AD = FF.Advisor
  local p = AD:Player()
  local build = AD:Build(p)
  local key = build and (build.combat or build.id)
  local list = (C.BUILD_BUFFS[p.class] and key and C.BUILD_BUFFS[p.class][key]) or C.BUFFS[p.class]
  if not list then return {} end
  local known = AD:KnownSpells()
  local have = playerBuffNames()
  if not have then return C.lastMissing or {} end   -- hidden right now: keep the last answer
  local S = FF.Spells
  local function present(spell)
    local loc = S:Local(spell)
    local family = BUFF_FAMILY[spell] and S:Local(BUFF_FAMILY[spell])
    for _, n in ipairs(have) do
      -- "Greater Blessing of Might" also counts as Blessing of Might
      if n == loc or n:find(loc, 1, true) or (family and n:find(family, 1, true) == 1) then return true end
    end
    return false
  end
  local out = {}
  for _, entry in ipairs(list) do
    local any = false
    for _, s in ipairs(entry) do if present(s) then any = true break end end
    if not any then
      for _, s in ipairs(entry) do
        if known[s] then out[#out + 1] = S:Local(s) break end
      end
    end
  end
  C.lastMissing = out
  return out
end

-- the macro lines for the missing buffs (druids: only in caster form)
function C:BuffLines()
  local lines = ""
  local cond = FF.Advisor:Player().class == "DRUID" and "[nocombat,noform]" or "[nocombat]"
  for _, s in ipairs(self.buffs or {}) do lines = lines .. "/cast " .. cond .. " " .. s .. "\n" end
  return lines
end

-- Druids: which shapeshift bar slot holds Bear Form and Cat Form (the order depends on what you've learned)
function C:DruidForms()
  local out = {}
  if not (GetNumShapeshiftForms and GetShapeshiftFormInfo) then return out end
  local S = FF.Spells
  local bear = { [S:Local("Bear Form")] = true, [S:Local("Dire Bear Form")] = true }
  local cat = S:Local("Cat Form")
  for i = 1, GetNumShapeshiftForms() or 0 do
    local _, a, _, b = GetShapeshiftFormInfo(i)
    local name = type(a) == "string" and a or nil
    if not name and type(b) == "number" then
      name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(b)) or (GetSpellInfo and GetSpellInfo(b))
    end
    if name and bear[name] then out.bear = i elseif name == cat then out.cat = i end
  end
  return out
end

-- Druids: every press casts the step of the form you're in, using the game's own [form:n] check,
-- which also works in combat (an addon can't swap the button's spells during a fight)
function C:DruidSetup()
  local p = FF.Advisor:Player()
  if p.class ~= "DRUID" then return false end
  local forms = self:DruidForms()
  if not (forms.bear or forms.cat) then return false end
  local function list(key)
    local s = self:BuildSteps(key)
    for i, x in ipairs(s) do s[i] = FF.Spells:Local(x) end
    return s
  end
  local build = FF.Advisor:Build(p)
  local key = build and (build.combat or build.id)
  local caster = (key == "feral" or key == "bear") and list("default") or self.steps
  local bear = forms.bear and list("bear") or {}
  local cat = forms.cat and list("feral") or {}
  local n = math.max(#bear, #cat, #caster, 1)
  local melee = {}
  if #bear > 0 then melee[#melee + 1] = forms.bear end
  if #cat > 0 then melee[#melee + 1] = forms.cat end
  local prefix = self:BuffLines() .. self:TargetPrefix() .. (#melee > 0 and ("/startattack [form:" .. table.concat(melee, "/") .. "]\n") or "")
  local function pick(l, i) return #l > 0 and l[(i - 1) % #l + 1] or nil end
  for i = 1, n do
    local parts = {}
    if pick(bear, i) then parts[#parts + 1] = "[form:" .. forms.bear .. "] " .. pick(bear, i) end
    if pick(cat, i) then parts[#parts + 1] = "[form:" .. forms.cat .. "] " .. pick(cat, i) end
    if pick(caster, i) then parts[#parts + 1] = pick(caster, i) end
    btn:SetAttribute("step" .. i, prefix .. "/cast " .. table.concat(parts, "; "))
  end
  btn:SetAttribute("count", n)
  btn:SetAttribute("step", 1)
  btn:SetAttribute("type", "macro")
  btn:SetAttribute("macrotext", btn:GetAttribute("step1"))
  self.steps = caster
  self.formSteps = { [0] = caster }
  if forms.bear then self.formSteps[forms.bear] = bear end
  if forms.cat then self.formSteps[forms.cat] = cat end
  return true
end

-- Paladins: Judgement uses up the active seal, so the seal and Judgement go into a cast sequence
-- that only moves on after a successful cast (seal, then Judgement, then the seal again). While
-- the sequence waits (Judgement recharging or out of range), the lines below it fire: cooldown
-- abilities when ready, then the filler. Putting Judgement and Consecration in front of every
-- press, as before, left the seal out and made Consecration the only spell cast.
function C:PaladinSetup(steps, prefix)
  if FF.Advisor:Player().class ~= "PALADIN" then return false end
  local seal, judge
  local cds, fill, seen = {}, {}, {}
  for _, s in ipairs(steps) do
    local e = FF.Spells:English(s) or s
    if e:find("^Seal of") then
      seal = seal or s
    elseif e == "Judgement" then
      judge = judge or s
    elseif not seen[s] then
      seen[s] = true
      if self:HasCooldown(s) then cds[#cds + 1] = s else fill[#fill + 1] = s end
    end
  end
  if not (seal and judge) then return false end
  local seqText = "reset=target/combat " .. seal .. ", " .. judge
  local text = prefix .. "/castsequence " .. seqText .. "\n"
  local used = {}
  for _, s in ipairs(cds) do
    local line = "/cast " .. s .. "\n"
    if #(text .. line) <= 240 then text = text .. line used[#used + 1] = s end
  end
  local fills = {}
  for _, s in ipairs(fill) do
    local line = "/cast " .. s .. "\n"
    if #(text .. line) <= 255 then text = text .. line fills[#fills + 1] = s end
  end
  text = text:gsub("\n$", "")
  btn:SetAttribute("count", 0)
  btn:SetAttribute("step", 1)
  btn:SetAttribute("type", "macro")
  btn:SetAttribute("macrotext", text)
  self.steps = { seal, judge }
  for _, s in ipairs(used) do self.steps[#self.steps + 1] = s end
  for _, s in ipairs(fills) do self.steps[#self.steps + 1] = s end
  self.seq, self.seqText, self.cds, self.fill, self.seqFirst = { seal, judge }, seqText, used, fills, true
  return true
end

function C:Rebuild()
  if not btn then return end
  if InCombatLockdown() then pendingRebuild = true return end
  btn:SetAttribute("ffdown", GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and true or false)
  local assist = FlipForeverDB.settings.combatBlizzard and self:BlizzardAssistSpell()
  if assist then
    self.steps, self.assist = {}, assist
    btn:SetAttribute("count", 0)
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", assist)
    self:UpdateIcons()
    return
  end
  self.assist = nil
  btn:SetAttribute("spell", nil)
  self.seqPos = nil
  self.buffs = self:MissingBuffs()
  self.buffSig = table.concat(self.buffs, ",")
  local steps, prefix = self:BuildSteps()
  -- the order that worked best in your own fights (CombatLearn.lua; the guide's order until then)
  if FF.CombatLearn then
    local ok, learned = pcall(FF.CombatLearn.Apply, FF.CombatLearn, steps)
    if ok and type(learned) == "table" then steps = learned end
  end
  prefix = self:BuffLines() .. self:TargetPrefix() .. prefix
  -- tanks: a taunt early in every round (only if you know one)
  if self:IsTank() then
    local known = FF.Advisor:KnownSpells()
    for _, taunt in ipairs({ "Taunt", "Growl", "Righteous Defense" }) do
      if known[taunt] then table.insert(steps, math.min(2, #steps + 1), taunt) break end
    end
  end
  -- from here on the names go to the game: use the client's language
  for i, s in ipairs(steps) do steps[i] = FF.Spells:Local(s) end
  self.steps = steps
  for i = 1, 20 do btn:SetAttribute("step" .. i, nil) end
  self.cds, self.seq, self.seqText, self.formSteps, self.fill, self.seqFirst = nil, nil, nil, nil, nil, nil
  if self:DruidSetup() then self:UpdateIcons() return end
  if self:Smart() and self:PaladinSetup(steps, prefix) then self:UpdateIcons() return end
  if self:Smart() and #steps > 0 then
    -- Cooldown abilities go in front of every press ("/cast" skips them silently while they
    -- recharge); the rest of the rotation moves on one step per press. A cast sequence was used
    -- here before, but it stops for good on a spell that can't be cast (a finisher without combo
    -- points, a buff that's already up, not enough rage), so the button never moved on.
    local cds, rest, seen = {}, {}, {}
    for _, s in ipairs(steps) do
      if self:HasCooldown(s) then
        if not seen[s] then seen[s] = true cds[#cds + 1] = s end
      else
        rest[#rest + 1] = s
      end
    end
    if #rest == 0 then rest = { cds[1] } end
    local lines = ""
    for _, s in ipairs(cds) do
      local line = "/cast " .. s .. "\n"
      if #(prefix .. lines .. line) <= 200 then lines = lines .. line end  -- macros stop at 255 characters
    end
    self.cds = cds
    steps, prefix = rest, prefix .. lines
    self.steps = steps
  end
  for i, spell in ipairs(steps) do
    btn:SetAttribute("step" .. i, prefix .. "/cast " .. spell)
  end
  btn:SetAttribute("count", #steps)
  btn:SetAttribute("step", 1)
  btn:SetAttribute("type", "macro")
  btn:SetAttribute("macrotext", steps[1] and (prefix .. "/cast " .. steps[1]) or "")
  self:UpdateIcons()
end

local function create()
  bar = CreateFrame("Frame", "FlipForeverCombatBar", UIParent)
  bar:SetSize(300, 110)
  local pos = FlipForeverDB.settings.combatPos
  -- below the busy top band (EllesmereUI XP bar, LayerSwap, WhatsTraining, Dungeon Journal and
  -- Schmendrick pop-ups all sit in the first ~170px); Shift + right-drag moves it
  if pos then bar:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else bar:SetPoint("TOP", UIParent, "TOP", 0, -190) end
  bar:SetMovable(true)
  bar:EnableMouse(false)

  btn = CreateFrame("Button", "FlipForeverCombatButton", bar, "SecureActionButtonTemplate, SecureHandlerBaseTemplate")
  btn:SetSize(56, 56)
  btn:SetPoint("TOP", 0, 0)
  btn:RegisterForClicks("AnyUp", "AnyDown")
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetAllPoints()
  btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  btn.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  btn.label:SetPoint("TOP", btn, "BOTTOM", 0, -2)

  small1 = bar:CreateTexture(nil, "ARTWORK")
  small1:SetSize(30, 30)
  small1:SetPoint("LEFT", btn, "RIGHT", 10, 0)
  small1:SetAlpha(0.8)
  small2 = bar:CreateTexture(nil, "ARTWORK")
  small2:SetSize(24, 24)
  small2:SetPoint("LEFT", small1, "RIGHT", 6, 0)
  small2:SetAlpha(0.55)
  for _, tex in ipairs({ small1, small2 }) do
    tex.cd = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    tex.cd:SetPoint("CENTER", tex, "CENTER", 0, 0)
  end

  hintText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hintText:SetPoint("TOP", btn.label, "BOTTOM", 0, -4)
  hintText:SetWidth(420)

  -- smart mode: cooldowns tick down, so keep the icons current (5 times a second)
  local since = 0
  bar:SetScript("OnUpdate", function(_, elapsed)
    since = since + (elapsed or 0)
    if since >= 0.2 then since = 0 if C.cds or C.seq then C:UpdateIcons() end end
  end)

  -- After each click: step to the next spell. Runs in Blizzard's secure code, so it also
  -- works in combat - and it can't look at cooldowns, buffs or targets.
  SecureHandlerWrapScript(btn, "PostClick", btn, [[
    -- one key press sends a "down" and an "up" click; only step on the one that casts
    if down ~= self:GetAttribute("ffdown") then return end
    local n = self:GetAttribute("count") or 0
    if n == 0 then return end
    local s = (self:GetAttribute("step") or 1) % n + 1
    self:SetAttribute("step", s)
    self:SetAttribute("macrotext", self:GetAttribute("step" .. s))
  ]])
  btn:HookScript("PostClick", function() C_Timer.After(0, function() C:UpdateIcons() end) end)

  -- drag the bar with Shift + right mouse (out of combat)
  -- the bar holds a secure button, so moving it is blocked in combat: only stop a move we started
  local moving = false
  btn:SetScript("OnMouseDown", function(_, mouse)
    if mouse == "RightButton" and IsShiftKeyDown() and not InCombatLockdown() then moving = true bar:StartMoving() end
  end)
  btn:SetScript("OnMouseUp", function()
    if not moving or InCombatLockdown() then return end
    moving = false
    bar:StopMovingOrSizing()
    local point, _, relPoint, x, y = bar:GetPoint()
    FlipForeverDB.settings.combatPos = { point, relPoint, x, y }
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("FlipForever combat helper")
    GameTooltip:AddLine(C:Smart() and "Click (or your key) = cast the big icon. Cooldown abilities go first whenever they're ready; the rest of the rotation only moves on after a successful cast, so nothing is skipped." or "Click (or your key) = cast the big icon, then the next one appears.", 1, 1, 1, true)
    GameTooltip:AddLine("Follows your chosen build and the spells you know; adapts to the target you select before a fight.", 1, 1, 1, true)
    GameTooltip:AddLine("Shift + right-drag to move. /ff combat to hide.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function C:Enabled() return FlipForeverDB.settings.combat == true end

function C:Apply()
  if InCombatLockdown() then pendingRebuild = true return end
  if self:Enabled() then
    if not btn then create() end
    bar:Show()
    self:Rebuild()
    ClearOverrideBindings(bar)
    for _, key in ipairs(self:Keys()) do SetOverrideBindingClick(bar, false, key, "FlipForeverCombatButton", "LeftButton") end
  elseif bar then
    ClearOverrideBindings(bar)
    bar:Hide()
  end
end

function C:Toggle()
  if InCombatLockdown() then FF:Print(FF:T("Can't change the combat helper during a fight - try again after.")) return end
  FlipForeverDB.settings.combat = not self:Enabled()
  FF:Print(self:Enabled() and "Combat helper ON (near the top of the screen). Click the big icon, or set a key in the FlipForever window."
    or "Combat helper OFF.")
  self:Apply()
  if FF.Hub then FF.Hub:Refresh() end
end

-- the combat helper's keys: the one you set, else + (main keyboard and numpad); none after Clear
C.DEFAULT_KEYS = { "+", "NUMPADPLUS" }
function C:Keys()
  local key = FlipForeverDB.settings.combatKey
  if key == false then return {} end
  if key then return { key } end
  return C.DEFAULT_KEYS
end

function C:SetKey(key)
  if InCombatLockdown() then FF:Print(FF:T("Can't change keys during a fight.")) return false end
  local clash = key and (FF:KeyConflict(key) or (key == FlipForeverDB.settings.key and "FlipForever's auction house key"))
  if clash then
    FF:Print(FF:T("|cffff5555%s is already used by %s|r - pick another."):format(key, clash))
    return false
  end
  FlipForeverDB.settings.combatKey = key or false   -- false: you cleared it (no default key either)
  FF:Print(key and ("Combat helper key: |cffffff00" .. key .. "|r") or "Combat helper key cleared.")
  self:Apply()
  if FF.Hub then FF.Hub:Refresh() end
  return true
end

-- Events: rebuild between fights when something relevant changes -----------------------------------
local function rebuildSoon()
  if btn and C:Enabled() then
    if InCombatLockdown() then pendingRebuild = true else C:Rebuild() end
  end
end
-- druids: shifting changes which rotation the button follows (the icon shows it right away);
-- learning a new form moves the shapeshift bar, so the button is rebuilt out of combat
FF:On("UPDATE_SHAPESHIFT_FORM", function() if btn and C.formSteps then C:UpdateIcons() end end)
FF:On("UPDATE_SHAPESHIFT_FORMS", function() if btn and C:Enabled() then C:Rebuild() end end)

-- the cast sequence moves on after each successful cast (followed for the big icon)
pcall(FF.On, FF, "UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if unit ~= "player" or not btn or not C.seq then return end
  C:OnCastSucceeded(spellID)
  C:UpdateIcons()
end)
-- your buffs changed out of combat: rebuild when the list of missing buffs is different
pcall(FF.On, FF, "UNIT_AURA", function(unit)
  if unit ~= "player" or not btn or not C:Enabled() or InCombatLockdown() or C.assist then return end
  if table.concat(C:MissingBuffs(), ",") ~= (C.buffSig or "") then C:Rebuild() end
end)

FF:On("PLAYER_TARGET_CHANGED", function()
  if not btn then return end
  C.seqPos = nil   -- reset=target: the sequence starts over on a new target
  if InCombatLockdown() then
    C:UpdateIcons() -- the warning line still updates; the sequence waits for the fight to end
  else
    C:Rebuild()
  end
end)
FF:On("SPELLS_CHANGED", rebuildSoon)
pcall(FF.On, FF, "UNIT_TARGET", function(unit)
  if unit == "target" and btn and bar:IsShown() then C:UpdateIcons() end
end)
-- threat changes: refresh the warning line
for _, ev in ipairs({ "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE" }) do
  pcall(FF.On, FF, ev, function() if btn and bar:IsShown() then pcall(C.UpdateIcons, C) end end)
end

function C:SetAutoTarget(on)
  if InCombatLockdown() then FF:Print(FF:T("Can't change this during a fight.")) return end
  FlipForeverDB.settings.combatTarget = on and true or false
  self:Apply()
end

function C:SetTank(on)
  if InCombatLockdown() then FF:Print(FF:T("Can't change this during a fight.")) return end
  FlipForeverDB.settings.combatTank = on and true or false
  self:Apply()
end
FF:On("PLAYER_LEVEL_UP", function() C_Timer.After(1, rebuildSoon) end)
FF:On("PLAYER_REGEN_ENABLED", function()
  if btn and C:Enabled() then C:Rebuild() pendingRebuild = false end
end)
FF:On("PLAYER_LOGIN", function() C_Timer.After(3, function() C:Apply() end) end)

-- Blizzard mode: keep the suggested icon fresh
C_Timer.NewTicker(0.2, function()
  if btn and C.assist and bar:IsShown() then pcall(C.UpdateIcons, C) end
end)

function C:ToggleBlizzard()
  if not self:BlizzardAssistSpell() then
    FF:Print(FF:T("This game client has no Blizzard one-button assistant - using your build's sequence."))
    FlipForeverDB.settings.combatBlizzard = false
    return
  end
  FlipForeverDB.settings.combatBlizzard = not FlipForeverDB.settings.combatBlizzard
  FF:Print(FlipForeverDB.settings.combatBlizzard and FF:T("Combat helper: Blizzard's assistant decides.") or FF:T("Combat helper: follows your build's sequence."))
  self:Apply()
  if FF.Hub then FF.Hub:Refresh() end
end

-- the advisor's build switch also changes the sequence
local origCycle = FF.Advisor.CycleBuild
FF.Advisor.CycleBuild = function(self, step)
  origCycle(self, step)
  rebuildSoon()
end

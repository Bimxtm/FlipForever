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
  },
  PALADIN = {
    default = { prefix = MELEE, steps = { { "Seal of Command", "Seal of Righteousness" }, "Judgement", "Holy Strike", { "Consecration", "Holy Strike" }, "Holy Strike" } },
  },
  HUNTER = {
    default = { prefix = PET, steps = { "Hunter's Mark", "Serpent Sting", "Arcane Shot", { "Aimed Shot", "Arcane Shot" }, { "Multi-Shot", "Arcane Shot" } } },
  },
  ROGUE = {
    sub_bleed = { prefix = MELEE, steps = { { "Hemorrhage", "Sinister Strike" }, { "Hemorrhage", "Sinister Strike" }, "Slice and Dice", { "Hemorrhage", "Sinister Strike" }, { "Hemorrhage", "Sinister Strike" }, "Eviscerate" } },
    default = { prefix = MELEE, steps = { "Sinister Strike", "Sinister Strike", "Slice and Dice", "Sinister Strike", "Sinister Strike", "Eviscerate" } },
  },
  PRIEST = {
    default = { steps = { "Power Word: Shield", "Shadow Word: Pain", "Mind Blast", { "Mind Flay", "Smite" }, { "Mind Flay", "Smite" } } },
  },
  SHAMAN = {
    enh = { prefix = MELEE, steps = { "Lightning Shield", "Flame Shock", { "Stormstrike", "Earth Shock" }, "Earth Shock", { "Stormstrike", "Lightning Bolt" } } },
    default = { steps = { "Lightning Shield", "Flame Shock", "Lightning Bolt", "Earth Shock", "Lightning Bolt" } },
  },
  MAGE = {
    frost = { steps = { "Frostbolt", "Frostbolt", { "Ice Lance", "Fire Blast" }, "Frostbolt", "Fire Blast" } },
    default = { steps = { { "Frostbolt", "Fireball" }, { "Frostbolt", "Fireball" }, "Fire Blast", { "Frostbolt", "Fireball" } } },
  },
  WARLOCK = {
    aff = { prefix = PET, steps = { "Corruption", { "Bane of Agony", "Curse of Agony" }, "Siphon Life", "Shadow Bolt", "Shadow Bolt", "Shadow Bolt" } },
    default = { prefix = PET, steps = { "Corruption", { "Bane of Agony", "Curse of Agony" }, "Immolate", "Shadow Bolt", "Shadow Bolt" } },
  },
  DRUID = {
    -- Cat steps are only used once you know Cat Form (stay in Cat Form while using it)
    feral = { prefix = MELEE, requires = "Cat Form", steps = { "Rake", "Claw", "Claw", "Rip", "Claw", "Claw", "Ferocious Bite" } },
    default = { steps = { "Moonfire", "Wrath", "Wrath", "Wrath" } },
  },
}

-- What each spell is, for immunities
local TAG = {
  Rend = "bleed", Rip = "bleed", Rake = "bleed", Garrote = "bleed", Rupture = "bleed", Hemorrhage = "physical",
  Fireball = "fire", ["Fire Blast"] = "fire", Immolate = "fire", ["Flame Shock"] = "fire", ["Searing Pain"] = "fire",
  Frostbolt = "frost", ["Ice Lance"] = "frost", ["Frost Shock"] = "frost", ["Cone of Cold"] = "frost",
  ["Serpent Sting"] = "poison", Corruption = "shadow", ["Shadow Bolt"] = "shadow",
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
function C:BuildSteps()
  local AD = FF.Advisor
  local p = AD:Player()
  local build = AD:Build(p)
  local cls = C.SEQ[p.class]
  if not cls then return {}, "" end
  local seq = (build and cls[build.id]) or cls.default
  local known = AD:KnownSpells()
  if seq.requires and not known[seq.requires] then seq = cls.default end
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
    for _, sp in ipairs({ "Fireball", "Arcane Missiles", "Shadow Bolt", "Wrath", "Lightning Bolt", "Smite", "Heroic Strike", "Sinister Strike", "Arcane Shot", "Holy Strike" }) do
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
    local name = nextId and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(nextId)
    btn.label:SetText((name or "Blizzard assistant") .. "  |cff888888(Blizzard mode)|r")
  else
    local steps = self.steps or {}
    local n = btn:GetAttribute("count") or 0
    local s = btn:GetAttribute("step") or 1
    local function stepSpell(k) return n > 0 and steps[((s - 1 + k) % n) + 1] or nil end
    btn.icon:SetTexture(iconOf(stepSpell(0)) or "Interface\\Icons\\INV_Misc_QuestionMark")
    small1:SetTexture(iconOf(stepSpell(1)))
    small2:SetTexture(iconOf(stepSpell(2)))
    btn.label:SetText(stepSpell(0) or "no spells yet")
  end
  local t = self:Target()
  local hint = t and self:TargetHint(t) or ""
  local ally = self:AllyUnderAttack()
  if ally then hint = ("|cffff5555Your target is attacking %s!|r  "):format(ally) .. hint end
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

-- Blizzard's own one-button rotation, if this client has it (retail-style Assisted Combat)
function C:BlizzardAssistSpell()
  local AC = C_AssistedCombat
  if not (AC and AC.GetActionSpell) then return nil end
  local ok, avail = pcall(AC.IsAvailable or function() return true end)
  if ok and avail == false then return nil end
  local ok2, id = pcall(AC.GetActionSpell)
  return ok2 and id or nil
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
  local steps, prefix = self:BuildSteps()
  prefix = self:TargetPrefix() .. prefix
  -- tanks: a taunt early in every round (only if you know one)
  if self:IsTank() then
    local known = FF.Advisor:KnownSpells()
    for _, taunt in ipairs({ "Taunt", "Growl", "Righteous Defense" }) do
      if known[taunt] then table.insert(steps, math.min(2, #steps + 1), taunt) break end
    end
  end
  self.steps = steps
  for i = 1, 20 do btn:SetAttribute("step" .. i, nil) end
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

  hintText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hintText:SetPoint("TOP", btn.label, "BOTTOM", 0, -4)
  hintText:SetWidth(420)

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
  btn:SetScript("OnMouseDown", function(_, mouse)
    if mouse == "RightButton" and IsShiftKeyDown() and not InCombatLockdown() then bar:StartMoving() end
  end)
  btn:SetScript("OnMouseUp", function()
    bar:StopMovingOrSizing()
    local point, _, relPoint, x, y = bar:GetPoint()
    FlipForeverDB.settings.combatPos = { point, relPoint, x, y }
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("FlipForever combat helper")
    GameTooltip:AddLine("Click (or your key) = cast the big icon, then the next one appears.", 1, 1, 1, true)
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
    local key = FlipForeverDB.settings.combatKey
    ClearOverrideBindings(bar)
    if key then SetOverrideBindingClick(bar, false, key, "FlipForeverCombatButton", "LeftButton") end
  elseif bar then
    ClearOverrideBindings(bar)
    bar:Hide()
  end
end

function C:Toggle()
  if InCombatLockdown() then FF:Print("Can't change the combat helper during a fight - try again after.") return end
  FlipForeverDB.settings.combat = not self:Enabled()
  FF:Print(self:Enabled() and "Combat helper ON (near the top of the screen). Click the big icon, or set a key in the FlipForever window."
    or "Combat helper OFF.")
  self:Apply()
  if FF.Hub then FF.Hub:Refresh() end
end

function C:SetKey(key)
  if InCombatLockdown() then FF:Print("Can't change keys during a fight.") return false end
  local clash = key and (FF:KeyConflict(key) or (key == FlipForeverDB.settings.key and "FlipForever's auction house key"))
  if clash then
    FF:Print(("|cffff5555%s is already used by %s|r - pick another."):format(key, clash))
    return false
  end
  FlipForeverDB.settings.combatKey = key
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
FF:On("PLAYER_TARGET_CHANGED", function()
  if not btn then return end
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

function C:SetAutoTarget(on)
  if InCombatLockdown() then FF:Print("Can't change this during a fight.") return end
  FlipForeverDB.settings.combatTarget = on and true or false
  self:Apply()
end

function C:SetTank(on)
  if InCombatLockdown() then FF:Print("Can't change this during a fight.") return end
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
    FF:Print("This game client has no Blizzard one-button assistant - using your build's sequence.")
    FlipForeverDB.settings.combatBlizzard = false
    return
  end
  FlipForeverDB.settings.combatBlizzard = not FlipForeverDB.settings.combatBlizzard
  FF:Print(FlipForeverDB.settings.combatBlizzard and "Combat helper: Blizzard's assistant decides." or "Combat helper: follows your build's sequence.")
  self:Apply()
  if FF.Hub then FF.Hub:Refresh() end
end

-- the advisor's build switch also changes the sequence
local origCycle = FF.Advisor.CycleBuild
FF.Advisor.CycleBuild = function(self, step)
  origCycle(self, step)
  rebuildSoon()
end

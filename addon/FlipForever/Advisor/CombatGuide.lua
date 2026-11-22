-- What skilled players do, for the combat helper. The spell lists per class come from the WoW: Forever
-- class guides on Skill Capped (skill-capped.com/wowarticles/forever/guides, updated 19 Nov 2026):
-- defensives, interrupts, control and burst. The guides are written for PvP; here they are used
-- against mobs and bosses:
--   * big cooldowns are saved for targets that deserve them (elites, rares, bosses, players, much
--     higher levels) instead of being burnt on every normal mob;
--   * an emergency key casts your defensives (in the guide's order, the first one ready) plus the best
--     healthstone and healing potion in your bags - prepared before the fight, as the game requires;
--   * during a fight the helper says when to press it, when to interrupt, when to slow a runner and
--     when to switch to the wand.
-- Health and mana thresholds are FlipForever's own starting values (the guides give none).
-- Switch: combatGuide.
local FF = FlipForever
local C = FF.Combat
local GD = {}
FF.CombatGuide = GD

GD.SOURCE = "Skill Capped, WoW: Forever class guides (19 Nov 2026)"
GD.LOW_HEALTH = 0.35   -- emergency below this (own value)
GD.LOW_MANA = 0.12     -- wand below this (own value)

GD.CLASS = {
  WARRIOR = { defensive = { "Shield Wall", "Retaliation", "Berserker Rage" }, big = { "Recklessness", "Death Wish" },
              interrupt = { "Pummel", "Shield Bash" }, slow = { "Hamstring" }, fear = { "Intimidating Shout" } },
  ROGUE   = { defensive = { "Evasion", "Vanish", "Preparation" }, big = { "Adrenaline Rush", "Cold Blood" },
              interrupt = { "Kick", "Kidney Shot", "Gouge" }, slow = { "Crippling Poison" } },
  SHAMAN  = { defensive = { "Healing Wave", "Lesser Healing Wave" }, big = { "Rage of the Farseer", "Elemental Mastery" },
              interrupt = { "Earth Shock" }, slow = { "Frost Shock", "Earthbind Totem" } },
  PRIEST  = { defensive = { "Power Word: Shield", "Flash Heal", "Psychic Scream" }, big = { "Power Infusion", "Inner Focus" },
              interrupt = { "Silence" }, slow = { "Mind Flay" } },
  PALADIN = { defensive = { "Divine Shield", "Lay on Hands", "Blessing of Protection", "Holy Light" }, big = { "Avenging Wrath" },
              interrupt = { "Hammer of Justice" }, slow = { "Hammer of Justice" } },
  MAGE    = { defensive = { "Ice Barrier", "Ice Block", "Mana Shield", "Frost Nova" }, big = { "Arcane Power", "Combustion", "Presence of Mind", "Icy Veins", "Cold Snap" },
              interrupt = { "Counterspell" }, slow = { "Frost Nova", "Cone of Cold" }, wand = true },
  WARLOCK = { defensive = { "Death Coil", "Shadow Ward" }, big = {},
              interrupt = { "Spell Lock" }, slow = { "Curse of Exhaustion" }, fear = { "Fear", "Howl of Terror" }, wand = true },
  DRUID   = { defensive = { "Barkskin", "Frenzied Regeneration", "Regrowth", "Healing Touch" }, big = { "Tiger's Fury" },
              interrupt = { "Bash", "Feral Charge" }, slow = { "Entangling Roots" } },
  HUNTER  = { defensive = { "Feign Death", "Deterrence" }, big = { "Rapid Fire", "Bestial Wrath" },
              interrupt = { "Scatter Shot", "Intimidation" }, slow = { "Concussive Shot", "Wing Clip" } },
}

-- healthstones (best first) and healing potions (best first), by item ID: the names differ per language
GD.HEALTHSTONES = { 19013, 19012, 9421, 19011, 19010, 5510, 19009, 19008, 5509, 19007, 19006, 5511, 19005, 19004, 5512 }
GD.POTIONS = { 13446, 3928, 1710, 929, 858, 118 }

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

function GD:On() return FlipForeverDB.settings.combatGuide ~= false end

function GD:Data()
  local p = FF.Advisor:Player()
  return GD.CLASS[p.class] or {}
end

local function known(name) return FF.Advisor:KnownSpells()[name] end

-- does this target deserve your big cooldowns?
function GD:WorthBig(t)
  if not t then return false end
  if t.class == "elite" or t.class == "rareelite" or t.class == "worldboss" or t.class == "rare" then return true end
  if t.level == -1 then return true end
  local me = FF.Advisor:Player().level or plain(UnitLevel("player")) or 1
  if t.level and t.level - me >= 3 then return true end
  if UnitIsPlayer and UnitIsPlayer("target") then return true end
  return false
end

-- the guide's big cooldowns stay out of the rotation against normal mobs (English names in and out)
function GD:FilterSteps(steps, target)
  if not self:On() then return steps end
  local big = {}
  for _, s in ipairs(self:Data().big or {}) do big[s] = true end
  if not next(big) or self:WorthBig(target) then return steps end
  local out = {}
  for _, s in ipairs(steps) do if not big[s] then out[#out + 1] = s end end
  if #out == 0 then return steps end
  return out
end

-- the emergency macro: known defensives in the guide's order, then the best healthstone and potion you carry
function GD:EmergencyMacro()
  local lines, first = {}, nil
  for _, s in ipairs(self:Data().defensive or {}) do
    if known(s) then
      local loc = FF.Spells:Local(s)
      lines[#lines + 1] = "/cast " .. loc
      first = first or loc
    end
  end
  local count = (C_Item and C_Item.GetItemCount) or GetItemCount
  for _, list in ipairs({ GD.HEALTHSTONES, GD.POTIONS }) do
    for _, id in ipairs(list) do
      local ok, n = pcall(count, id)
      if ok and (tonumber(n) or 0) > 0 then
        lines[#lines + 1] = "/use item:" .. id
        first = first or ("item:" .. id)
        break
      end
    end
  end
  local text = table.concat(lines, "\n")
  while #text > 255 and #lines > 1 do table.remove(lines, 1) text = table.concat(lines, "\n") end
  return text, first
end

-- the first known spell of a list that is ready now (nil if none)
local function firstReady(list)
  for _, s in ipairs(list or {}) do
    if known(s) and (not C.CooldownLeft or C.CooldownLeft(FF.Spells:Local(s)) <= 1.6) then return FF.Spells:Local(s) end
  end
  return nil
end
GD.FirstReady = firstReady

local function pct(unit, power)
  local ok, cur, max = pcall(function()
    if power then return UnitPower(unit), UnitPowerMax(unit) end
    return UnitHealth(unit), UnitHealthMax(unit)
  end)
  cur, max = ok and plain(cur), ok and plain(max)
  if not cur or not max or max <= 0 then return nil end
  return cur / max
end
GD.Pct = pct

-- the advice line during a fight (nil when nothing needs doing)
function GD:Hint()
  if not self:On() or not (InCombatLockdown and InCombatLockdown()) then return nil end
  local d = self:Data()
  local hp = pct("player")
  if hp and hp < GD.LOW_HEALTH and self.emergencyFirst then
    local key = self.emergencyKey and (" (" .. FF:KeyLabel(self.emergencyKey) .. ")") or ""
    return FF:T("|cffff5555Low health: press the emergency key%s - %s|r"):format(key, self.emergencyLabel or self.emergencyFirst)
  end
  if UnitExists("target") and UnitCanAttack("player", "target") then
    local ok, name, _, _, _, _, _, _, notInterruptible = pcall(UnitCastingInfo, "target")
    if not (ok and plain(name)) then ok, name, _, _, _, _, _, notInterruptible = pcall(UnitChannelInfo, "target") end
    if ok and plain(name) and not plain(notInterruptible) then
      local kick = firstReady(d.interrupt)
      if kick then return FF:T("|cffffd200Interrupt %s: %s|r"):format(name, kick) end
    end
    local thp = pct("target")
    local ctype = plain(UnitCreatureType("target"))
    if thp and thp < 0.2 and ctype == "Humanoid" then
      local slow = firstReady(d.slow)
      if slow then return FF:T("|cffffd200Low on health, it may run: %s|r"):format(slow) end
    end
  end
  if d.wand and known("Shoot") then
    local mana = pct("player", true)
    if mana and mana < GD.LOW_MANA then return FF:T("|cff88bbffLow mana: finish with your wand (Shoot)|r") end
  end
  return nil
end

-- The emergency button (secure; its macro can only change outside fights) ---------------------------
local ebtn
local function createButton(parent)
  ebtn = CreateFrame("Button", "FlipForeverEmergencyButton", parent, "SecureActionButtonTemplate")
  ebtn:SetSize(26, 26)
  ebtn:RegisterForClicks("AnyUp", "AnyDown")
  ebtn.icon = ebtn:CreateTexture(nil, "ARTWORK")
  ebtn.icon:SetAllPoints()
  ebtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  ebtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(FF:T("Emergency"))
    GameTooltip:AddLine(FF:T("Casts your first ready defensive spell and uses your best healthstone or healing potion."), 1, 1, 1, true)
    if GD.emergencyKey then GameTooltip:AddLine(FF:T("Key: %s"):format(FF:KeyLabel(GD.emergencyKey)), 0.7, 0.7, 0.7) end
    GameTooltip:Show()
  end)
  ebtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- the emergency key: Shift + your combat key (unless taken)
function GD:Keys()
  local s = FlipForeverDB.settings.emergencyKey
  if s == false then return {} end
  if s then return { s } end
  local out = {}
  for _, k in ipairs(C:Keys()) do
    local key = "SHIFT-" .. k
    if not (FF.KeyConflict and FF:KeyConflict(key)) then out[#out + 1] = key end
  end
  return out
end

-- set up the button and its key (outside fights only)
function GD:Setup(bar, anchor)
  if InCombatLockdown() then return end
  if not self:On() then
    if ebtn then ebtn:Hide() end
    self.emergencyFirst = nil
    return
  end
  if not ebtn and bar then createButton(bar) end
  if not ebtn then return end
  if anchor then ebtn:ClearAllPoints() ebtn:SetPoint("RIGHT", anchor, "LEFT", -10, 0) end
  local text, first = self:EmergencyMacro()
  ebtn:SetAttribute("type", "macro")
  ebtn:SetAttribute("macrotext", text)
  self.emergencyFirst = first
  self.emergencyLabel = first and (first:match("^item:") and FF:T("healthstone or potion") or first) or nil
  local tex
  if first and not first:match("^item:") then
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(first)
    tex = info and info.iconID
  end
  ebtn.icon:SetTexture(tex or "Interface\\Icons\\INV_Potion_54")
  if first then ebtn:Show() else ebtn:Hide() end
  local keys = self:Keys()
  self.emergencyKey = keys[1]
  if bar then
    for _, k in ipairs(keys) do SetOverrideBindingClick(bar, false, k, "FlipForeverEmergencyButton", "LeftButton") end
  end
end

-- /ff emergencykey KEY (or "clear")
function GD:SetKey(key)
  if InCombatLockdown() then FF:Print(FF:T("Can't change keys during a fight.")) return false end
  if key and FF.KeyConflict then
    local clash = FF:KeyConflict(key)
    if clash then FF:Print(FF:T("|cffff5555%s is already used by %s|r - pick another."):format(key, clash)) return false end
  end
  FlipForeverDB.settings.emergencyKey = key or false
  FF:Print(key and FF:T("Emergency key: |cffffff00%s|r"):format(key) or FF:T("Emergency key cleared."))
  C:Apply()
  return true
end

-- Orders from written leveling guides ----------------------------------------------------------------
-- Part 3 of the combat helper: the single-target priorities from the WoW: Forever leveling guides on
-- Warcraft Tavern (warcrafttavern.com/forever/guides, read 22 Nov 2026), turned into a repeating order
-- per class and build (the "combat" key of the build). Spells that only fire after a proc, a dodge or
-- below 20% health (Overpower, Revenge, Execute, Shadowburn, Ice Lance) are left out, and so are the
-- big cooldowns (kept for targets that deserve them, see GD.CLASS). The combat learner tries this
-- order as one more version next to the helper's own and keeps whichever kills faster for you.
GD.TUTORIAL_SOURCE = "Warcraft Tavern, WoW: Forever leveling guides (22 Nov 2026)"
GD.TUTORIAL = {
  WARRIOR = {
    arms = { "Battle Shout", "Rend", "Mortal Strike", { "Slam", "Heroic Strike" }, "Mortal Strike", "Heroic Strike" },
    fury = { "Battle Shout", "Bloodthirst", "Whirlwind", "Heroic Strike", "Bloodthirst", "Heroic Strike" },
    prot = { "Battle Shout", "Thunder Clap", "Shield Slam", "Rend", "Heroic Strike", "Shield Slam" },
  },
  PALADIN = {
    default = { { "Seal of Command", "Seal of Righteousness" }, "Judgement", "Holy Strike", "Holy Strike", { "Seal of Command", "Seal of Righteousness" } },
    prot = { { "Seal of Fury", "Seal of Righteousness" }, "Judgement", "Consecration", "Holy Strike", "Holy Strike" },
    holy = { "Seal of Righteousness", "Holy Shock", "Judgement", "Consecration", "Holy Strike" },
  },
  HUNTER = {
    bm = { "Serpent Sting", "Arcane Shot", { "Aimed Shot", "Arcane Shot" }, "Arcane Shot" },
    mm = { "Serpent Sting", { "Sniper Shot", "Arcane Shot" }, "Arcane Shot", { "Aimed Shot", "Arcane Shot" } },
    sv = { "Serpent Sting", "Arcane Shot", "Raptor Strike", { "Immolation Trap", "Raptor Strike" }, "Raptor Strike" },
  },
  ROGUE = {
    combat = { "Sinister Strike", "Slice and Dice", { "Shank", "Sinister Strike" }, "Sinister Strike", "Sinister Strike", "Eviscerate" },
    assa = { { "Mutilate", "Sinister Strike" }, "Slice and Dice", { "Shank", "Sinister Strike" }, { "Mutilate", "Sinister Strike" }, "Eviscerate" },
    sub = { "Hemorrhage", { "Ghostly Strike", "Hemorrhage" }, "Slice and Dice", { "Shank", "Hemorrhage" }, "Hemorrhage", "Eviscerate" },
    sub_bleed = { "Hemorrhage", "Slice and Dice", "Hemorrhage", { "Ghostly Strike", "Hemorrhage" }, "Hemorrhage", { "Rupture", "Eviscerate" } },
  },
  PRIEST = {
    shadow = { "Shadow Word: Pain", "Mind Blast", { "Mind Flay", "Smite" }, { "Devouring Plague", "Mind Flay", "Smite" }, { "Mind Flay", "Smite" } },
    default = { "Power Word: Shield", "Smite", "Shadow Word: Pain", { "Penance", "Smite" }, "Smite" },
  },
  SHAMAN = {
    enh = { "Lightning Shield", "Flame Shock", { "Stormstrike", "Earth Shock" }, "Earth Shock", { "Stormstrike", "Earth Shock" } },
    ele = { "Lightning Shield", { "Lava Burst", "Lightning Bolt" }, "Flame Shock", "Lightning Bolt", { "Lava Burst", "Lightning Bolt" }, "Lightning Bolt" },
  },
  MAGE = {
    fire = { { "Scorch", "Fireball" }, "Fireball", "Fire Blast", "Fireball", "Fireball" },
    arcane = { "Arcane Blast", "Arcane Blast", "Arcane Blast", { "Arcane Wrath", "Arcane Blast" }, "Fire Blast" },
  },
  WARLOCK = {
    aff = { { "Bane of Agony", "Curse of Agony" }, "Corruption", "Immolate", "Siphon Life", { "Wrack", "Drain Life", "Shadow Bolt" }, { "Drain Life", "Shadow Bolt" } },
    demo = { "Searing Pain", { "Bane of Agony", "Curse of Agony" }, "Corruption", "Immolate", "Searing Pain", { "Drain Life", "Shadow Bolt" } },
    destro = { { "Curse of the Elements", "Bane of Agony", "Curse of Agony" }, "Immolate", { "Conflagrate", "Shadow Bolt" }, { "Incinerate", "Shadow Bolt" }, { "Incinerate", "Shadow Bolt" } },
  },
  DRUID = {
    feral = { "Rake", "Claw", "Claw", "Claw", "Rip", "Claw", "Claw", "Claw", "Ferocious Bite" },
    bear = { "Lacerate", "Demoralizing Roar", { "Primal Bite", "Maul" }, "Lacerate", "Maul" },
    balance = { "Moonfire", { "Insect Swarm", "Wrath" }, { "Starfire", "Wrath" }, { "Starfire", "Wrath" }, "Wrath" },
  },
}

-- the guide's order for this learner key ("CLASS:combat:band"), with only the spells you can use:
-- ones in the helper's own order or that you know, never a big cooldown the helper left out.
-- Returns nil when there is none or it is the same as the helper's order.
function GD:TutorialSteps(key, base, known)
  local class, combat = tostring(key or ""):match("^(%u+):([^:]+)")
  local list = class and self.TUTORIAL[class] and self.TUTORIAL[class][combat]
  if not list then return nil end
  local inBase, big = {}, {}
  for _, s in ipairs(base) do inBase[s] = true end
  for _, s in ipairs((self.CLASS[class] or {}).big or {}) do big[s] = true end
  local function usable(s) return inBase[s] or (known and known[s] and not big[s]) end
  local out = {}
  for _, step in ipairs(list) do
    local pick
    if type(step) == "table" then
      for _, s in ipairs(step) do if usable(s) then pick = s break end end
    elseif usable(step) then pick = step end
    if pick then out[#out + 1] = pick end
  end
  if #out < 2 or table.concat(out, ">") == table.concat(base, ">") then return nil end
  return out
end

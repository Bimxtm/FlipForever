-- Combat helper that learns from its own fights, per class, build and level band (shared by all your
-- characters of that class). It learns from its own choices, not from how you play: only casts that
-- come right after a press of the helper's button or key count, and a fight only counts when most
-- casts (70%) came from the helper. Recorded: what it cast, what failed and why, how long the
-- fight took, time out of mana/rage/energy, health lost, deaths and whether the target died. From that it
--   * tries small changes to the guide's order (two neighbouring steps swapped, or a spell that keeps
--     failing for lack of power moved later) and keeps the order that kills fastest with the least
--     damage taken and no deaths, once each version has enough fights;
--   * says after a fight what could be done better (only when it matters, at most every few minutes);
--   * sums it all up with /ff combat.
-- Switches: combatLearn (learning and reordering), combatTips (the notes after fights).
local FF = FlipForever
local L = {}
FF.CombatLearn = L

local MIN_FIGHTS = 6        -- fights per version before its result counts
local MAX_FIGHTS_KEPT = 60  -- recent fights kept per class/build for the summary
local TIP_GAP = 300         -- seconds between two notes after fights
local IDLE_GAP = 2.5        -- seconds without a cast that count as waiting
local HELPER_SHARE = 0.7    -- a fight counts for learning when at least this share of casts came from the helper

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

function L:On() return FlipForeverDB.settings.combatLearn ~= false end
function L:TipsOn() return FlipForeverDB.settings.combatTips ~= false end

-- "PALADIN:ret:11-39": what is learned is kept apart per class, build and level band
function L:Key()
  local AD = FF.Advisor
  local p = AD:Player()
  local build = AD:Build(p)
  local C = FF.Combat
  local band = (C and C.band) or "all"
  return (p.class or "?") .. ":" .. ((build and (build.combat or build.id)) or "default") .. ":" .. band
end

function L:Store(key)
  FlipForeverDB.combatLearn = FlipForeverDB.combatLearn or {}
  local db = FlipForeverDB.combatLearn
  key = key or self:Key()
  db[key] = db[key] or { spells = {}, fights = {}, bases = {} }
  local s = db[key]
  s.spells, s.fights, s.bases = s.spells or {}, s.fights or {}, s.bases or {}
  return s
end

local function english(name)
  if not name then return nil end
  return (FF.Spells and FF.Spells.English and FF.Spells:English(name)) or name
end

-- Versions of the order ---------------------------------------------------------------------------
-- base: the guide's order (English names). Returns { name = steps } for the versions worth trying.
function L:Variants(base, store)
  local out = { base = base }
  local n = #base
  for i = 1, math.min(3, n - 1) do
    local v = {}
    for j, s in ipairs(base) do v[j] = s end
    v[i], v[i + 1] = v[i + 1], v[i]
    out["swap" .. i] = v
  end
  -- a spell that keeps failing for lack of power goes to the end
  local worst, worstRate = nil, 0.25
  for _, s in ipairs(base) do
    local st = store and store.spells[s]
    local tries = st and ((st.cast or 0) + (st.fail or 0)) or 0
    if st and tries >= 10 then
      local rate = (st.power or 0) / tries
      if rate > worstRate then worst, worstRate = s, rate end
    end
  end
  if worst and n > 1 then
    local v = {}
    for _, s in ipairs(base) do if s ~= worst then v[#v + 1] = s end end
    v[#v + 1] = worst
    out["later:" .. worst] = v
  end
  return out
end

-- score of one version: lower is better (seconds per kill, adjusted, with penalties)
function L:Score(v)
  if not v or (v.n or 0) == 0 then return nil end
  local kills = v.kills or 0
  if kills == 0 then return 1e6 end
  local perKill = (v.time or 0) / kills
  local deathRate = (v.deaths or 0) / v.n
  local hpLost = (v.hp or 0) / v.n          -- average share of health lost per fight
  return perKill * (1 + hpLost * 0.5) * (1 + deathRate * 3)
end

-- What all players' helpers learned, shipped with each release (CombatShared.lua, built from the
-- anonymous summaries players share): FF.COMBAT_SHARED[key][baseSig][variant] = { n, kills, time, deaths, hp }.
-- It counts as at most SHARED_WEIGHT fights next to your own, so your fights still decide.
local SHARED_WEIGHT = 20

function L:Shared(key, sig, name)
  local s = FF.COMBAT_SHARED and FF.COMBAT_SHARED[key]
  s = s and s[sig]
  return s and s[name]
end

-- your own results for a version plus everyone's (scaled down)
function L:Combined(bstore, name, key, sig)
  local own = bstore.variants[name] or {}
  local sh = self:Shared(key or (self.current and self.current.key) or self:Key(), sig or bstore.sig, name)
  local out = { n = own.n or 0, kills = own.kills or 0, time = own.time or 0, deaths = own.deaths or 0, hp = own.hp or 0 }
  if sh and (sh.n or 0) > 0 then
    local w = math.min(1, SHARED_WEIGHT / sh.n)
    out.n = out.n + sh.n * w
    out.kills = out.kills + (sh.kills or 0) * w
    out.time = out.time + (sh.time or 0) * w
    out.deaths = out.deaths + (sh.deaths or 0) * w
    out.hp = out.hp + (sh.hp or 0) * w
  end
  return out
end

-- pick the version for the next fight: each one first gets MIN_FIGHTS (counting what all players
-- shared), then mostly the best one, now and then another (so a change in gear or level is noticed)
function L:Pick(variants, bstore, rnd, key, sig)
  rnd = rnd or math.random
  local names = {}
  for name in pairs(variants) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    if self:Combined(bstore, name, key, sig).n < MIN_FIGHTS then return name, false end
  end
  local best, bestScore = "base", nil
  for _, name in ipairs(names) do
    local sc = self:Score(self:Combined(bstore, name, key, sig))
    if sc and (not bestScore or sc < bestScore) then best, bestScore = name, sc end
  end
  if rnd() < 0.1 then return names[math.floor(rnd() * #names) + 1], false end
  return best, true
end

-- called by the combat helper with the guide's steps (English names); returns the steps to use
function L:Apply(steps)
  self.current = nil
  if not self:On() or #steps < 2 then return steps end
  local store = self:Store()
  local sig = table.concat(steps, ">")
  store.bases[sig] = store.bases[sig] or { variants = {} }
  local bstore = store.bases[sig]
  local variants = self:Variants(steps, store)
  local key = self:Key()
  local name, settled = self:Pick(variants, bstore, nil, key, sig)
  self.current = { key = key, sig = sig, variant = name }
  if settled and name ~= "base" and bstore.told ~= name and self:TipsOn() then
    bstore.told = name
    FF:Print(FF:T("Combat helper learned: this order works better for you - %s."):format(table.concat(variants[name], ", ")))
  end
  return variants[name] or steps
end

-- Recording a fight -------------------------------------------------------------------------------
local fight
local POWER_ERR = {}
local RANGE_ERR = {}
local function addErr(set, ...)
  for _, k in ipairs({ ... }) do local v = _G[k] if type(v) == "string" then set[v] = true end end
end
addErr(POWER_ERR, "ERR_OUT_OF_MANA", "ERR_OUT_OF_RAGE", "ERR_OUT_OF_ENERGY", "SPELL_FAILED_NO_POWER",
  "ERR_OUT_OF_FOCUS", "SPELL_FAILED_NO_COMBO_POINTS", "ERR_NO_COMBO_POINTS")
addErr(RANGE_ERR, "ERR_OUT_OF_RANGE", "SPELL_FAILED_OUT_OF_RANGE", "ERR_BADATTACKPOS", "SPELL_FAILED_UNIT_NOT_INFRONT",
  "ERR_TOO_FAR_TO_INTERACT", "SPELL_FAILED_LINE_OF_SIGHT")

local function pct(cur, max)
  cur, max = plain(cur), plain(max)
  if not cur or not max or max <= 0 then return nil end
  return cur / max
end

local function playerHealth()
  local ok, a, b = pcall(function() return UnitHealth("player"), UnitHealthMax("player") end)
  return ok and pct(a, b) or nil
end
local function playerPower()
  local ok, a, b = pcall(function() return UnitPower("player"), UnitPowerMax("player") end)
  return ok and pct(a, b) or nil
end

function L:StartFight(now)
  now = now or GetTime()
  local tl = UnitExists and UnitExists("target") and plain(UnitLevel("target")) or nil
  fight = { t0 = now, last = now, idle = 0, low = 0, casts = 0, fails = {}, hp0 = playerHealth() or 1,
            hpMin = playerHealth() or 1, tlevel = tl, plevel = plain(UnitLevel("player")),
            pvp = UnitIsPlayer and UnitIsPlayer("target") and true or false, cur = self.current }
  self.fight = fight
end

-- the helper's button or key was pressed: casts right after it are the helper's own choices
local HELPER_WINDOW = 0.6
function L:OnHelperPress(now) self.pressAt = now or GetTime() end
function L:IsHelperCast(now)
  return self.pressAt ~= nil and (now or GetTime()) - self.pressAt <= HELPER_WINDOW
end

-- helper: true when the helper cast it (nil: decided from the last press)
function L:OnCast(spellName, now, helper)
  if not fight then return end
  now = now or GetTime()
  if helper == nil then helper = self:IsHelperCast(now) end
  local gap = now - fight.last
  if gap > IDLE_GAP then fight.idle = fight.idle + (gap - IDLE_GAP) end
  fight.last = now
  fight.casts = fight.casts + 1
  if not helper then return end          -- your own casts are not what the helper learns from
  fight.helperCasts = (fight.helperCasts or 0) + 1
  local name = english(spellName)
  if name then
    local st = self:Store(fight.cur and fight.cur.key).spells
    st[name] = st[name] or {}
    st[name].cast = (st[name].cast or 0) + 1
  end
end

function L:OnFail(spellName, reason, helper)
  if not fight or helper == false then return end
  local name = english(spellName) or "?"
  local st = self:Store(fight.cur and fight.cur.key).spells
  st[name] = st[name] or {}
  st[name].fail = (st[name].fail or 0) + 1
  if reason == "power" then st[name].power = (st[name].power or 0) + 1 end
  if reason == "range" then st[name].range = (st[name].range or 0) + 1 end
  fight.fails[name] = fight.fails[name] or {}
  fight.fails[name][reason or "other"] = (fight.fails[name][reason or "other"] or 0) + 1
end

-- twice a second in a fight: low power and lowest health
function L:Tick(dt)
  if not fight then return end
  local pw = playerPower()
  if pw and pw < 0.1 then fight.low = fight.low + (dt or 0.5) end
  local hp = playerHealth()
  if hp and hp < fight.hpMin then fight.hpMin = hp end
end

function L:EndFight(now, killed, died)
  local f = fight
  fight, self.fight = nil, nil
  if not f then return nil end
  now = now or GetTime()
  local dur = now - f.t0
  if dur < 3 then return nil end            -- a stray hit, not a fight
  local gap = now - f.last
  if gap > IDLE_GAP and f.casts > 0 then f.idle = f.idle + math.min(gap - IDLE_GAP, 5) end
  local hpLost = math.max(0, (f.hp0 or 1) - (f.hpMin or 1))
  -- harder targets take longer: count time against a target 3 levels up as 30% less
  local adj = dur
  if f.tlevel and f.plevel and f.tlevel > 0 then adj = dur / math.max(0.5, 1 + 0.1 * (f.tlevel - f.plevel)) end
  local share = f.casts > 0 and (f.helperCasts or 0) / f.casts or 0
  local rec = { t = time(), dur = math.floor(dur * 10) / 10, idle = math.floor(f.idle * 10) / 10,
                low = math.floor(f.low * 10) / 10, hp = math.floor(hpLost * 100) / 100,
                kill = killed and true or false, died = died and true or false, pvp = f.pvp, casts = f.casts,
                helper = share >= HELPER_SHARE }
  local key = f.cur and f.cur.key or self:Key()
  local store = self:Store(key)
  table.insert(store.fights, rec)
  while #store.fights > MAX_FIGHTS_KEPT do table.remove(store.fights, 1) end
  -- the version used in this fight gets the result, but only when the helper did the fighting
  -- (most casts came from its button) - it learns from its own choices, not from how you play;
  -- PvP fights are kept out too: players differ too much
  if f.cur and not f.pvp and rec.helper and store.bases[f.cur.sig] then
    local vs = store.bases[f.cur.sig].variants
    local v = vs[f.cur.variant] or { n = 0 }
    vs[f.cur.variant] = v
    v.n = (v.n or 0) + 1
    v.hp = (v.hp or 0) + hpLost
    if died then v.deaths = (v.deaths or 0) + 1 end
    if killed then v.kills = (v.kills or 0) + 1 v.time = (v.time or 0) + adj end
  end
  local tip = self:Tip(rec, f)
  if tip and self:TipsOn() and (not self.lastTip or time() - self.lastTip >= TIP_GAP) then
    self.lastTip = time()
    FF:Print(tip)
  end
  return rec, tip
end

-- one note on what to do better, the most important first (nil when the fight went fine)
function L:Tip(rec, f)
  if rec.died then
    local G = FF.CombatGuide
    if G and G:On() and G.emergencyFirst then
      return FF:T("Combat: you died. Press the emergency key%s below 35%% health - it casts %s and uses your healthstone or potion."):format(
        G.emergencyKey and (" (" .. G.emergencyKey .. ")") or "", G.emergencyLabel or G.emergencyFirst)
    end
    return FF:T("Combat: you died. Pull one enemy at a time, start with full health and use your defensive spells or a potion below 40% health.")
  end
  if rec.idle >= 4 and rec.idle / rec.dur > 0.25 then
    return FF:T("Combat: you waited %d of %d seconds between casts. Press the combat key as soon as the next spell lights up."):format(
      math.floor(rec.idle + 0.5), math.floor(rec.dur + 0.5))
  end
  for name, why in pairs(f and f.fails or {}) do
    if (why.range or 0) >= 3 then
      return FF:T("Combat: %s failed %d times out of range or out of sight. Get closer first, or let the target come to you."):format(name, why.range)
    end
  end
  if rec.low / rec.dur > 0.3 then
    return FF:T("Combat: you were out of mana, rage or energy for %d%% of the fight. Rest or drink before the next pull, or let the helper use cheaper spells."):format(math.floor(rec.low / rec.dur * 100))
  end
  if not rec.pvp and rec.hp >= 0.7 then
    return FF:T("Combat: you lost %d%% of your health. Pull fewer enemies at once or start the fight with your defensive buff up."):format(math.floor(rec.hp * 100))
  end
  return nil
end

-- /ff combat: what has been learned for your class and build
function L:Report()
  local key = self:Key()
  local store = self:Store(key)
  local n, kills, dur, idle, deaths, own = 0, 0, 0, 0, 0, 0
  for _, r in ipairs(store.fights) do
    n = n + 1
    if r.helper then own = own + 1 end
    if r.kill then kills = kills + 1 end
    if r.died then deaths = deaths + 1 end
    dur, idle = dur + (r.dur or 0), idle + (r.idle or 0)
  end
  local lines = { FF:T("Combat helper, %s - recent fights: %d, kills: %d, deaths: %d."):format(key, n, kills, deaths) }
  if n > 0 then
    lines[#lines + 1] = FF:T("Average fight %.1f s, waiting between casts %d%%."):format(dur / n, dur > 0 and math.floor(idle / dur * 100) or 0)
    lines[#lines + 1] = FF:T("Fights the helper did itself (these are what it learns from): %d of %d."):format(own, n)
  end
  local fails = {}
  for name, st in pairs(store.spells) do
    local tries = (st.cast or 0) + (st.fail or 0)
    if tries >= 5 and (st.fail or 0) / tries >= 0.2 then
      fails[#fails + 1] = ("%s %d%%"):format(name, math.floor((st.fail or 0) / tries * 100))
    end
  end
  table.sort(fails)
  if #fails > 0 then lines[#lines + 1] = FF:T("Often failing: %s."):format(table.concat(fails, ", ")) end
  local cur = self.current
  if cur and store.bases[cur.sig] then
    local parts = {}
    for name, v in pairs(store.bases[cur.sig].variants) do
      local sc = self:Score(v)
      parts[#parts + 1] = ("%s %d/%d%s"):format(name, v.n or 0, MIN_FIGHTS, sc and sc < 1e6 and (" " .. math.floor(sc * 10) / 10 .. "s") or "")
    end
    table.sort(parts)
    lines[#lines + 1] = FF:T("Orders being compared (fights, seconds per kill): %s. Now using: %s."):format(table.concat(parts, ", "), cur.variant)
  end
  for _, l in ipairs(lines) do FF:Print(l) end
  return lines
end

-- Events ------------------------------------------------------------------------------------------
local lastFailed
FF:On("PLAYER_REGEN_DISABLED", function() if L:On() or L:TipsOn() then L:StartFight() end end)
FF:On("PLAYER_REGEN_ENABLED", function()
  if not fight then return end
  local killed = UnitExists and UnitExists("target") and UnitIsDead and UnitIsDead("target") and true or false
  if not killed and fight.targetDied then killed = true end
  L:EndFight(nil, killed, fight.died)
end)
pcall(FF.On, FF, "PLAYER_DEAD", function()
  if fight then fight.died = true L:EndFight(nil, false, true) end
end)
pcall(FF.On, FF, "UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if unit ~= "player" or not fight then return end
  spellID = plain(spellID)
  local name = spellID and ((C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or (GetSpellInfo and GetSpellInfo(spellID)))
  if plain(name) then L:OnCast(name) end
end)
pcall(FF.On, FF, "UNIT_SPELLCAST_FAILED", function(unit, _, spellID)
  if unit ~= "player" or not fight then return end
  spellID = plain(spellID)
  local name = spellID and ((C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or (GetSpellInfo and GetSpellInfo(spellID)))
  lastFailed = plain(name) and { name = name, t = GetTime(), helper = L:IsHelperCast() } or nil
end)
-- the reason comes as an error message right after the failed cast
FF:On("UI_ERROR_MESSAGE", function(_, msg)
  if not fight or type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end
  local name = lastFailed and GetTime() - lastFailed.t < 0.5 and lastFailed.name
  if not name then return end
  local helper = lastFailed.helper and true or false
  lastFailed = nil
  if POWER_ERR[msg] then L:OnFail(name, "power", helper)
  elseif RANGE_ERR[msg] then L:OnFail(name, "range", helper)
  else L:OnFail(name, "other", helper) end
end)
pcall(FF.On, FF, "PLAYER_TARGET_CHANGED", function()
  -- the target you were fighting is dead: count the kill even if you clicked away before the fight ended
  if fight and fight.hadTarget and not fight.targetDied then
    fight.hadTarget = false
  end
  if fight and UnitExists and UnitExists("target") then fight.hadTarget = true end
end)
pcall(FF.On, FF, "UNIT_HEALTH", function(unit)
  if not fight or unit ~= "target" then return end
  if UnitIsDead and UnitIsDead("target") then fight.targetDied = true end
end)
C_Timer.NewTicker(0.5, function() if fight then L:Tick(0.5) end end)

-- Sharing ------------------------------------------------------------------------------------------
-- The FlipForever app sends an anonymous summary of what the helper learned (class, build, level
-- band, the spell orders compared, fight counts and times; no names, no chat, nothing else) so every
-- release starts from what worked for all players. Setting combatShare (on); the app reads it.
function L:ShareOn() return FlipForeverDB.settings.combatShare ~= false end

function L:WarnOnce()
  local s = FlipForeverDB.settings
  if s.combatShareWarned then return false end
  s.combatShareWarned = true
  FF:Print(FF:T("|cffffd200Note:|r the combat helper collects anonymous combat data (class, build, spell order, fight length; no names) and the FlipForever app shares it to improve the helper for everyone. Switch it off under Settings, Features: \"Share anonymous combat data\"."))
  return true
end
FF:On("PLAYER_LOGIN", function() C_Timer.After(8, function() pcall(L.WarnOnce, L) end) end)

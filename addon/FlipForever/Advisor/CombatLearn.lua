-- Combat helper that learns from your fights, per class, build and level band (shared by all your
-- characters of that class). Every fight is recorded: what you cast, what failed and why, how long
-- you waited between casts, how long you were out of mana/rage/energy, health lost, deaths and
-- whether the target died. From that it
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

-- pick the version for the next fight: each one first gets MIN_FIGHTS, then mostly the best one,
-- now and then another (so a change in your gear or level is noticed)
function L:Pick(variants, bstore, rnd)
  rnd = rnd or math.random
  local names = {}
  for name in pairs(variants) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local v = bstore.variants[name]
    if not v or (v.n or 0) < MIN_FIGHTS then return name, false end
  end
  local best, bestScore = "base", nil
  for _, name in ipairs(names) do
    local sc = self:Score(bstore.variants[name])
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
  local name, settled = self:Pick(variants, bstore)
  self.current = { key = self:Key(), sig = sig, variant = name }
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

function L:OnCast(spellName, now)
  if not fight then return end
  now = now or GetTime()
  local gap = now - fight.last
  if gap > IDLE_GAP then fight.idle = fight.idle + (gap - IDLE_GAP) end
  fight.last = now
  fight.casts = fight.casts + 1
  local name = english(spellName)
  if name then
    local st = self:Store(fight.cur and fight.cur.key).spells
    st[name] = st[name] or {}
    st[name].cast = (st[name].cast or 0) + 1
  end
end

function L:OnFail(spellName, reason)
  if not fight then return end
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
  local rec = { t = time(), dur = math.floor(dur * 10) / 10, idle = math.floor(f.idle * 10) / 10,
                low = math.floor(f.low * 10) / 10, hp = math.floor(hpLost * 100) / 100,
                kill = killed and true or false, died = died and true or false, pvp = f.pvp, casts = f.casts }
  local key = f.cur and f.cur.key or self:Key()
  local store = self:Store(key)
  table.insert(store.fights, rec)
  while #store.fights > MAX_FIGHTS_KEPT do table.remove(store.fights, 1) end
  -- the version used in this fight gets the result (PvP fights are kept out: players differ too much)
  if f.cur and not f.pvp and store.bases[f.cur.sig] then
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
    return FF:T("Combat: you waited %d of %d seconds between casts. Press the combat key as soon as the next spell lights up."):format(rec.idle, rec.dur)
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
  local n, kills, dur, idle, deaths = 0, 0, 0, 0, 0
  for _, r in ipairs(store.fights) do
    n = n + 1
    if r.kill then kills = kills + 1 end
    if r.died then deaths = deaths + 1 end
    dur, idle = dur + (r.dur or 0), idle + (r.idle or 0)
  end
  local lines = { FF:T("Combat helper, %s - recent fights: %d, kills: %d, deaths: %d."):format(key, n, kills, deaths) }
  if n > 0 then
    lines[#lines + 1] = FF:T("Average fight %.1f s, waiting between casts %d%%."):format(dur / n, dur > 0 and math.floor(idle / dur * 100) or 0)
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
  lastFailed = plain(name) and { name = name, t = GetTime() } or nil
end)
-- the reason comes as an error message right after the failed cast
FF:On("UI_ERROR_MESSAGE", function(_, msg)
  if not fight or type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end
  local name = lastFailed and GetTime() - lastFailed.t < 0.5 and lastFailed.name
  if not name then return end
  lastFailed = nil
  if POWER_ERR[msg] then L:OnFail(name, "power")
  elseif RANGE_ERR[msg] then L:OnFail(name, "range")
  else L:OnFail(name, "other") end
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

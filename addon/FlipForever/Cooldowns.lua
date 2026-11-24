-- Profession cooldowns across characters (switch profCooldowns): transmutes, Mooncloth and other
-- crafts with a cooldown are read whenever a profession window is read, per character, and the
-- Overview (and the app) show when each is ready again on every character of this realm.
-- All transmutes share one cooldown, so they are kept as one "Transmute" entry.
local FF = FlipForever
local C = {}
FF.Cooldowns = C

-- crafts known to have a cooldown, so they also show once they are ready again
local KNOWN = { [18560] = true } -- Mooncloth

function C:Enabled() return FlipForeverDB.settings.profCooldowns ~= false end

-- seconds until a recipe can be crafted again: 0 = ready, nil = the game doesn't say
function C:Remaining(rid)
  local TS = C_TradeSkillUI
  if TS and TS.GetRecipeCooldown then
    local ok, cd = pcall(TS.GetRecipeCooldown, rid)
    if ok and type(cd) == "number" then return math.max(0, cd) end
  end
  local get = (C_Spell and C_Spell.GetSpellCooldown) or GetSpellCooldown
  if get and GetTime then
    local ok, start, dur = pcall(get, rid)
    if ok and type(start) == "table" then start, dur = start.startTime, start.duration end
    if ok and type(start) == "number" and type(dur) == "number" then
      if start > 0 and dur > 1.5 then return math.max(0, start + dur - GetTime()) end
      return 0
    end
  end
  return nil
end

local function keyOf(r)
  if r.name and r.name:find("^Transmute") then return "transmute", FF:T("Transmute") end
  return r.id, r.name
end

-- called after the profession window was read (Professions:Capture)
function C:Read(recipes)
  if not self:Enabled() then return end
  local store = FF.Advisor:CharStore()
  store.cooldowns = store.cooldowns or {}
  local list, now = store.cooldowns, time()
  for _, r in ipairs(recipes or {}) do
    if r.learned and r.id then
      local cd = self:Remaining(r.id)
      local key, name = keyOf(r)
      if cd and cd > 60 then
        local e = list[key] or {}
        e.name, e.ready = name, now + math.floor(cd)
        list[key] = e
      elseif cd == 0 and (KNOWN[r.id] or key == "transmute" or list[key]) then
        local e = list[key] or {}
        -- a shared cooldown: one transmute ready doesn't undo another's running timer
        if not (e.ready and e.ready > now and key == "transmute") then e.ready = now end
        e.name = name
        list[key] = e
      end
    end
  end
end

-- every character's cooldowns on this realm, soonest first: { char, name, ready }
function C:List()
  local out = {}
  for char, cs in pairs(FF:DB().chars or {}) do
    if type(cs) == "table" and type(cs.cooldowns) == "table" then
      for _, e in pairs(cs.cooldowns) do
        if type(e) == "table" and e.name and e.ready then out[#out + 1] = { char = char, name = e.name, ready = e.ready } end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.ready ~= b.ready then return a.ready < b.ready end
    return a.char .. a.name < b.char .. b.name
  end)
  return out
end

function C:Left(secs)
  if secs <= 0 then return FF:T("|cff33ff99ready|r") end
  if secs < 3600 then return FF:T("%d min"):format(math.ceil(secs / 60)) end
  if secs < 48 * 3600 then return FF:T("%d h"):format(math.ceil(secs / 3600)) end
  return FF:T("%d days"):format(math.floor(secs / 86400 + 0.5))
end

-- one Overview line ("" when off or nothing known)
function C:Line(max)
  if not self:Enabled() then return "" end
  local list, now, parts = self:List(), time(), {}
  for i, e in ipairs(list) do
    if i > (max or 3) then break end
    parts[#parts + 1] = ("%s %s (%s)"):format(e.name, self:Left(e.ready - now), e.char)
  end
  if #parts == 0 then return "" end
  local more = #list > #parts and FF:T("  +%d more"):format(#list - #parts) or ""
  return FF:T("Cooldowns: ") .. table.concat(parts, "  ·  ") .. more
end

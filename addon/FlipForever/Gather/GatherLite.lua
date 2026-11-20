-- FlipForever Gathering module (was the separate Ore Farmer addon).
if select(2, ...).skipGather then return end
-- Ore Farmer + GatherLite.
-- GatherLite ships 35,000+ WoW Forever gathering spots and draws them on the
-- maps. When it is installed, Ore Farmer reads its spots (read-only) and adds
-- them to its own, so routes and profit estimates cover the whole zone from
-- day one. GatherLite keeps drawing the pins; Ore Farmer draws the route and
-- the next stop.
local _, ns = ...

local GL_KINDS = { mining = "mining", herbalism = "herbalism", containers = "treasure", fishing = "fishing" }
local CACHE_SECONDS = 120

local function gatherLite()
  if ns.glDisabled then return nil end
  local ace = LibStub and LibStub("AceAddon-3.0", true)
  local gl = ace and ace:GetAddon("GatherLite", true)
  if gl and gl.GetNodesForMap and gl.GetNodeObject then return gl end
  return nil
end

function ns.UsingGatherLite()
  return gatherLite() ~= nil and ns.db and ns.db.useGatherLite ~= false
end

-- "Khadgar's Whisker" / "khadgars_whisker" -> "khadgarswhisker"
local function norm(s)
  return (s:lower():gsub("[^%a]", ""))
end

local byNormName
local function lookupKey(glName)
  if not byNormName then
    byNormName = {}
    for _, def in ipairs(ns.ORES) do
      for _, n in ipairs(def.nodes or {}) do byNormName[norm(n)] = def.key end
    end
  end
  return byNormName[norm(glName)]
end

local function pretty(glName)
  return (glName:gsub("_", " "):gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end))
end

-- GatherLite object ID -> Ore Farmer resource key (learning new ones as custom).
local objectKey = {}
local function keyForObject(gl, objectID, cat)
  local k = objectKey[objectID]
  if k ~= nil then return k or nil end
  local obj = gl:GetNodeObject(objectID)
  if not obj or type(obj.name) ~= "string" then
    objectKey[objectID] = false
    return nil
  end
  k = lookupKey(obj.name)
  if not k then
    local label = pretty(obj.name)
    k = ns.RegisterCustomOre(label, cat)
    local def = ns.OreByKey[k]
    if def and type(obj.levels) == "table" and tonumber(obj.levels[1]) then def.skill = tonumber(obj.levels[1]) end
    byNormName = nil
  end
  objectKey[objectID] = k
  return k
end

-- GatherLite's spots on one map, converted to Ore Farmer spots.
local cache = {}
function ns.GatherLiteNodes(mapID)
  local gl = ns.UsingGatherLite() and gatherLite()
  if not gl then return nil end
  local c = cache[mapID]
  if c and GetTime() - c.t < CACHE_SECONDS then return c.list end
  local list = {}
  for glKind, cat in pairs(GL_KINDS) do
    local ok, nodes = pcall(gl.GetNodesForMap, gl, glKind, mapID)
    if ok and type(nodes) == "table" then
      for _, n in ipairs(nodes) do
        local x, y, obj = n.posX, n.posY, n.object
        if type(x) == "number" and type(y) == "number" and obj then
          local key = keyForObject(gl, obj, cat)
          if key then list[#list + 1] = { x = x, y = y, n = 1, t = { [key] = 1 }, ext = true } end
        end
      end
    end
  end
  -- Same number of spots as before: keep the old list so routes stay cached.
  if c and #c.list == #list then
    c.t = GetTime()
    return c.list
  end
  cache[mapID] = { t = GetTime(), list = list }
  return list
end

function ns.ResetGatherLiteCache()
  cache = {}
end

-- Your own spots plus GatherLite's (minus ones you already have).
local merged = {}
function ns.AllNodes(mapID)
  local own = (ns.db and ns.db.nodes[mapID]) or {}
  local ext = ns.GatherLiteNodes(mapID)
  if not ext or #ext == 0 then return own end
  local m = merged[mapID]
  if m and m.ext == ext and m.ownCount == #own then return m.list end
  local W, H = ns.MapSize(mapID)
  local list = {}
  for i = 1, #own do list[i] = own[i] end
  for _, e in ipairs(ext) do
    local dup = false
    for i = 1, #own do
      if ns.Yards(own[i].x, own[i].y, e.x, e.y, W, H) < ns.MERGE_YARDS then dup = true; break end
    end
    if not dup then list[#list + 1] = e end
  end
  merged[mapID] = { ext = ext, ownCount = #own, list = list }
  return list
end

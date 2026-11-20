-- FlipForever Gathering module (was the separate Ore Farmer addon).
if select(2, ...).skipGather then return end
-- Ore Farmer: pure logic (no game API calls), so it can be tested outside the game.
-- Map positions are 0..1 map coordinates; W and H are the map's size in yards.
local _, ns = ...

local sqrt, floor, sin, cos = math.sqrt, math.floor, math.sin, math.cos
local atan2 = math.atan2 or math.atan

ns.SAME_VISIT_SECONDS = 120 -- observations of one spot this close together are one spawn
ns.MERGE_YARDS = 15         -- observations this close together are one spawn point

function ns.Yards(ax, ay, bx, by, W, H)
  local dx, dy = (ax - bx) * W, (ay - by) * H
  return sqrt(dx * dx + dy * dy)
end

-- Add one observation of an ore at (x, y) to a zone's node list.
-- mined = true when you mined it, false when you only saw it on the minimap.
-- Returns node, isNewSpawnPoint, isNewMiningVisit.
function ns.AddObservation(nodes, key, x, y, W, H, now, mergeYards, mined)
  mergeYards = mergeYards or ns.MERGE_YARDS
  local best, bestD
  for _, node in ipairs(nodes) do
    local d = ns.Yards(node.x, node.y, x, y, W, H)
    if d <= mergeYards and (not bestD or d < bestD) then best, bestD = node, d end
  end

  local weight = mined and 1 or 0.3 -- mining positions are more precise than minimap hovers
  if best then
    if now - (best.lastObs or 0) > ns.SAME_VISIT_SECONDS then
      best.n = (best.n or 0) + 1
      best.t[key] = (best.t[key] or 0) + 1
    elseif not best.t[key] then
      best.t[key] = 1
    end
    local pw = best.pw or 1
    best.x = (best.x * pw + x * weight) / (pw + weight)
    best.y = (best.y * pw + y * weight) / (pw + weight)
    best.pw = math.min(pw + weight, 20)
    best.lastObs = now
    local newVisit = false
    if mined then
      newVisit = now - (best.lastMined or 0) > ns.SAME_VISIT_SECONDS
      best.lastMined = now
      if newVisit then best.mined = (best.mined or 0) + 1 end
    end
    return best, false, newVisit
  end

  local node = { x = x, y = y, n = 1, t = { [key] = 1 }, pw = weight, lastObs = now,
                 lastMined = mined and now or nil, mined = mined and 1 or 0 }
  nodes[#nodes + 1] = node
  return node, true, mined and true or false
end

-- The ore type seen most often at a spawn point.
function ns.MainType(node)
  local bestK, bestC
  for k, c in pairs(node.t) do
    if not bestC or c > bestC or (c == bestC and k < bestK) then bestK, bestC = k, c end
  end
  return bestK
end

-- Expected value of one visit to a spawn point (assuming something is there).
-- Ores you can't mine or have hidden count as zero.
-- Returns value, relevant (true if any of its ores is minable and shown).
function ns.NodeValue(node, valueOf, canMine, enabled)
  local total, value, relevant = 0, 0, false
  for _, c in pairs(node.t) do total = total + c end
  if total == 0 then return 0, false end
  for k, c in pairs(node.t) do
    if canMine(k) and enabled(k) then
      relevant = true
      value = value + (c / total) * (valueOf(k) or 0)
    end
  end
  return value, relevant
end

-- Average copper per mining visit for one ore type.
-- yield = { visits = n, items = { [itemID] = count } }; priceOf(itemID) -> copper.
-- With no data yet, guesses 2 ore per node. Returns value, isGuess.
function ns.YieldValue(yield, priceOf, oreItem)
  if yield and (yield.visits or 0) > 0 then
    local v = 0
    for id, count in pairs(yield.items or {}) do
      v = v + (count / yield.visits) * (priceOf(id) or 0)
    end
    return v, yield.visits < 3
  end
  if oreItem then return 2 * (priceOf(oreItem) or 0), true end
  return 0, true
end

-- Distance function d(i, j): a lookup table for small sets, computed on the
-- fly for big ones (GatherLite zones can have hundreds of spots).
local function distFn(pts, W, H)
  local n = #pts
  if n <= 250 then
    local D = {}
    for i = 1, n do
      local row = {}
      for j = 1, n do row[j] = ns.Yards(pts[i].x, pts[i].y, pts[j].x, pts[j].y, W, H) end
      D[i] = row
    end
    return function(i, j) return D[i][j] end
  end
  return function(i, j)
    local a, b = pts[i], pts[j]
    local dx, dy = (a.x - b.x) * W, (a.y - b.y) * H
    return sqrt(dx * dx + dy * dy)
  end
end

local function tourLength(order, d)
  local n, len = #order, 0
  if n < 2 then return 0 end
  for k = 1, n do len = len + d(order[k], order[k % n + 1]) end
  return len
end

local function nearestNeighbour(n, d, start)
  local used, order = { [start] = true }, { start }
  for k = 2, n do
    local last, best, bd = order[k - 1], nil, nil
    for j = 1, n do
      if not used[j] then
        local dd = d(last, j)
        if not bd or dd < bd then best, bd = j, dd end
      end
    end
    order[k] = best
    used[best] = true
  end
  return order
end

-- outOfTime() is checked between rows so a huge zone can't freeze the game.
local function twoOpt(order, d, outOfTime)
  local n = #order
  local improved, passes = true, 0
  while improved and passes < 60 do
    improved, passes = false, passes + 1
    for i = 1, n - 2 do
      if outOfTime() then return order end
      local a, b = order[i], order[i + 1]
      local dab = d(a, b)
      for j = i + 2, n do
        if not (i == 1 and j == n) then
          local c, e = order[j], order[j % n + 1]
          if d(a, c) + d(b, e) < dab + d(c, e) - 1e-6 then
            local lo, hi = i + 1, j
            while lo < hi do
              order[lo], order[hi] = order[hi], order[lo]
              lo, hi = lo + 1, hi - 1
            end
            improved = true
            b = order[i + 1]
            dab = d(a, b)
          end
        end
      end
    end
  end
  return order
end

-- Shortest closed loop through all points (nearest-neighbour from a few starts,
-- then 2-opt). Returns an array of indexes into pts.
-- clock (optional): returns milliseconds; budgetMs caps the time spent.
function ns.BuildRoute(pts, W, H, clock, budgetMs)
  local n = #pts
  if n == 0 then return {} end
  if n <= 3 then
    local o = {}
    for i = 1, n do o[i] = i end
    return o
  end
  local d = distFn(pts, W, H)
  local t0 = clock and clock() or 0
  local function outOfTime() return clock ~= nil and clock() - t0 > (budgetMs or 150) end
  local starts = n > 400 and 1 or (n > 150 and 2 or 6)
  local bestOrder, bestLen
  for s = 1, starts do
    local start = floor((s - 1) * n / starts) + 1
    local order = twoOpt(nearestNeighbour(n, d, start), d, outOfTime)
    local len = tourLength(order, d)
    if not bestLen or len < bestLen then bestOrder, bestLen = order, len end
    if outOfTime() then break end
  end
  return bestOrder
end

function ns.RouteLength(pts, order, W, H)
  local n, len = #order, 0
  if n < 2 then return 0 end
  for k = 1, n do
    local a, b = pts[order[k]], pts[order[k % n + 1]]
    len = len + ns.Yards(a.x, a.y, b.x, b.y, W, H)
  end
  return len
end

-- Estimate one loop of the route.
-- opts: speed (yards/second), secondsPerNode (dismount + mine + loot),
-- availability (0..1, share of spawn points that have a node when you arrive).
function ns.EstimateLoop(pts, order, W, H, opts)
  local yards = ns.RouteLength(pts, order, W, H)
  local speed = (opts.speed and opts.speed > 0) and opts.speed or 7
  local avail = opts.availability or 0.5
  local value = 0
  for _, p in ipairs(pts) do value = value + (p.value or 0) * avail end
  local seconds = yards / speed + #pts * avail * (opts.secondsPerNode or 6)
  local perHour = seconds > 0 and value / seconds * 3600 or 0
  return { yards = yards, seconds = seconds, value = value, perHour = perHour, nodes = #pts }
end

-- A robust "cheapest real price": the unit price at which the cheapest 15% of
-- the listed quantity is reached, so one odd cheap listing doesn't set the price.
-- entries = { { unit = copperPerItem, count = n }, ... }
function ns.LowPrice(entries, frac)
  if not entries or #entries == 0 then return nil end
  table.sort(entries, function(a, b) return a.unit < b.unit end)
  local total = 0
  for _, e in ipairs(entries) do total = total + e.count end
  local target = math.max(1, total * (frac or 0.15))
  local cum = 0
  for _, e in ipairs(entries) do
    cum = cum + e.count
    if cum >= target then return e.unit end
  end
  return entries[#entries].unit
end

function ns.FormatMoney(c)
  c = floor((c or 0) + 0.5)
  local g, s, cc = floor(c / 10000), floor((c % 10000) / 100), c % 100
  if g > 0 then
    if s > 0 then return string.format("%dg %ds", g, s) end
    return string.format("%dg", g)
  end
  if s > 0 then
    if cc > 0 then return string.format("%ds %dc", s, cc) end
    return string.format("%ds", s)
  end
  return string.format("%dc", cc)
end

function ns.FormatTime(sec)
  sec = floor((sec or 0) + 0.5)
  if sec >= 3600 then return string.format("%dh %02dm", floor(sec / 3600), floor((sec % 3600) / 60)) end
  if sec >= 60 then return string.format("%dm %02ds", floor(sec / 60), sec % 60) end
  return string.format("%ds", sec)
end

-- 8-way compass direction for an offset (east, north) in yards.
local DIRS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
function ns.Compass(dxEast, dyNorth)
  local deg = math.deg(atan2(dxEast, dyNorth)) % 360
  return DIRS[floor((deg + 22.5) / 45) % 8 + 1]
end

-- Rotate an (east, north) offset into a rotating minimap's frame.
-- facing: radians counter-clockwise from north. Use -facing for the reverse.
function ns.Rotate(x, y, facing)
  local c, s = cos(facing), sin(facing)
  return x * c + y * s, -x * s + y * c
end

-- Minimap view radius in yards for a zoom level (0..5).
local MM_OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local MM_INDOOR  = { [0] = 300, 240, 180, 120, 80, 50 }
function ns.MinimapRadius(zoom, indoors)
  local t = indoors and MM_INDOOR or MM_OUTDOOR
  return (t[zoom or 0] or t[0]) / 2
end

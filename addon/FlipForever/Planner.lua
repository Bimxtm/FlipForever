-- FlipForever: the in-game planner. Rebuilds the shopping list right after a scan, so a new
-- list needs no /reload. It is a faithful port of the app's planner (engine.py: market_model,
-- recommend, _starter, build_plan) and uses what the app learned, which the app hands over
-- inside each character's plan as plan.ctx (settings, margin tuning, calibration, sell
-- chances, deposits, your own selling times, what this character holds).
-- tests/test_addon.py checks that both planners pick the same items at the same prices.
local FF = FlipForever
local P = {}
FF.Planner = P

local DAY = 86400
local HISTORY_DAYS = 14
local HALF_LIFE = 3 * DAY
local FULL = { full = true, ["full-browse"] = true }

-- the app's defaults (store.py Settings), used for characters the app hasn't planned for yet
local DEFAULTS = {
  min_margin = 0.20, ah_cut = 0.05, deposit_pct = 0.015, hold_days = 2.0, min_sales_per_day = 3.0,
  min_sell_chance = 0.55, starter_mode = true, starter_min_listed = 50, max_units_per_item = 200,
  max_plan_items = 40, min_value_copper = 50, min_scans = 3, duration = 2, sell_farmed = true,
}

local floor, sqrt, exp = math.floor, math.sqrt, math.exp
local log10 = math.log10 or function(x) return math.log(x, 10) end
local function trunc(x) if x >= 0 then return floor(x) end return -floor(-x) end -- Python int()
local function idiv(a, b) return floor(a / b) end                                   -- Python //
local function clamp(x, lo, hi) if x < lo then return lo elseif x > hi then return hi end return x end

local function median(t)
  local s = {}
  for i = 1, #t do s[i] = t[i] end
  table.sort(s)
  local n = #s
  if n % 2 == 1 then return s[(n + 1) / 2] end
  return (s[n / 2] + s[n / 2 + 1]) / 2
end

local function weightedMedian(values, weights)
  local pairs_, total = {}, 0
  for i = 1, #values do
    pairs_[i] = { values[i], weights[i] }
    total = total + weights[i]
  end
  table.sort(pairs_, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
  local acc = 0
  for _, p in ipairs(pairs_) do
    acc = acc + p[2]
    if acc >= total / 2 then return p[1] end
  end
  return pairs_[#pairs_][1]
end

-- plans.json gives number keys back as strings; normalise to numbers
local function numKeys(t)
  local out = {}
  for k, v in pairs(t or {}) do
    local n = tonumber(k)
    if n then out[n] = v end
  end
  return out
end

-- Market model ---------------------------------------------------------------------------------
function P:MarketModel(scans, now)
  local since = now - HISTORY_DAYS * DAY
  local hist = {}
  for _, sc in ipairs(scans or {}) do
    local t = tonumber(sc.t)
    if t and t >= since then
      local full = FULL[sc.src or "full"] and true or false
      for sid, mn, p25, qty in (sc.d or ""):gmatch("(%d+):(%d+):(%d+):(%d+):%d+") do
        local id = tonumber(sid)
        local h = hist[id]
        if not h then h = {} hist[id] = h end
        h[#h + 1] = { t = t, min = tonumber(mn), p25 = tonumber(p25), qty = tonumber(qty), full = full }
      end
    end
  end
  local out = {}
  for id, pts in pairs(hist) do
    table.sort(pts, function(a, b) return a.t < b.t end)
    local p25s, weights, mins, recent, days = {}, {}, {}, {}, {}
    local ndays = 0
    for i, p in ipairs(pts) do
      p25s[i] = p.p25
      weights[i] = 0.5 ^ ((now - p.t) / HALF_LIFE)
      mins[i] = p.min
      if now - p.t < 3 * DAY then recent[#recent + 1] = p.p25 end
      local d = floor(p.t / DAY)
      if not days[d] then days[d] = true ndays = ndays + 1 end
    end
    local market = weightedMedian(p25s, weights)
    local med = median(mins)
    local vol = 1.0
    if med > 0 then
      local dev = {}
      for i, m in ipairs(mins) do dev[i] = math.abs(m - med) end
      vol = median(dev) / med
    end
    local trend = 0.0
    local mp = median(p25s)
    if #recent > 0 and mp ~= 0 then trend = median(recent) / mp - 1 end
    local drops, span, prev = 0, 0, nil
    for _, p in ipairs(pts) do
      if p.full then
        if prev then
          local dt = p.t - prev.t
          if dt > 0 and dt <= 36 * 3600 then
            drops = drops + math.max(0, prev.qty - p.qty)
            span = span + dt
          end
        end
        prev = p
      end
    end
    local volDay = nil
    if span >= 6 * 3600 then volDay = 0.7 * drops / (span / DAY) end
    local last = pts[#pts]
    out[id] = { id = id, market = market, cur_min = last.min, cur_p25 = last.p25, cur_qty = last.qty, cur_t = last.t,
      nscans = #pts, days_seen = ndays, volatility = vol, vol_day = volDay, trend = trend }
  end
  return out
end

local function liquidityPrior(m)
  if not m then return 0.35 end
  local v = m.vol_day
  if v == nil then v = math.min(m.cur_qty, 20) * 0.25 end
  local p = 0.25 + 0.6 * (1 - exp(-v / 10.0))
  if m.days_seen < 2 then p = p * 0.8 end
  return clamp(p, 0.15, 0.85)
end

-- What the app learned, with safe defaults ----------------------------------------------------
function P:Context(ctx, held)
  ctx = ctx or {}
  local s = {}
  for k, v in pairs(DEFAULTS) do s[k] = v end
  for k, v in pairs(ctx.s or {}) do s[k] = v end
  local black = {}
  for _, id in ipairs(s.blacklist or {}) do if tonumber(id) then black[tonumber(id)] = true end end
  local sell = {}
  for id, v in pairs(numKeys(ctx.ps)) do sell[id] = { tonumber(v[1]) or 0, tonumber(v[2]) or 0 } end
  local h = numKeys(ctx.held)
  for id, q in pairs(held or {}) do h[id] = (h[id] or 0) + q end
  return {
    s = s, black = black,
    mf = tonumber(ctx.mf) or 1.0, gc = tonumber(ctx.gc) or 1.0,
    ic = numKeys(ctx.ic), sell = sell, adj = numKeys(ctx.adj), paused = numKeys(ctx.paused),
    dep = numKeys(ctx.dep), own = numKeys(ctx.own), held = h,
  }
end

local function starter(c, m, name)
  local s = c.s
  if not s.starter_mode or m.cur_qty < s.starter_min_listed then return nil end
  if m.market < s.min_value_copper then return nil end
  local ps = c.sell[m.id]
  if ps and ps[2] >= 4 and ps[1] < s.min_sell_chance then return nil end
  return { id = m.id, name = name, cur = m.cur_min, expected = trunc(m.market), max_buy = 0, qty_cap = s.max_units_per_item,
    confidence = 0.3, score = log10(m.cur_qty) * sqrt(m.market), is_deal = false, fast = true, starter = true }
end

-- recommend(): every item with a score, deals first
function P:Recommend(model, c, now, nameOf)
  local s = c.s
  local marginBase = s.min_margin * c.mf
  local cut = s.ah_cut
  local deals = {}
  for id, m in pairs(model) do
    if not (c.black[id] or c.paused[id]) then
      if m.nscans < s.min_scans or m.vol_day == nil then
        local d = starter(c, m, nameOf(id))
        if d then deals[#deals + 1] = d end
      elseif m.market >= s.min_value_copper then
        local expected = m.market * (c.ic[id] or c.gc)
        if m.trend < -0.05 then expected = expected * (1 + m.trend) end
        local ps = c.sell[id]
        local p = ps and ps[1] or liquidityPrior(m)
        local pEv = 1 - (1 - p) ^ 3
        local cycles = p > 0 and pEv / p or 3
        local depUnit = c.dep[id] or expected * s.deposit_pct
        -- the deposit comes back when the item sells: only postings that expire lose it
        local net = pEv * expected * (1 - cut) - (cycles - pEv) * depUnit
        local margin = marginBase + math.min(0.25, m.volatility * 0.5) + (c.adj[id] or 0)
        local maxBuy = trunc(net / (1 + margin))
        if maxBuy > 0 then
          local held = c.held[id] or 0
          local ownDays = c.own[id]
          local ourRate = m.vol_day * 0.5
          local qtyCap = trunc(math.min(s.max_units_per_item, floor(ourRate * s.hold_days)) - held)
          local estDays = nil
          if ourRate > 0 then estDays = (held + math.max(1, qtyCap)) / ourRate end
          if ownDays then estDays = math.max(estDays or 0, ownDays) end
          local slow = (m.vol_day < s.min_sales_per_day) or (p < s.min_sell_chance) or (ownDays ~= nil and ownDays > s.hold_days)
          local fast = not slow
          local stale = now - m.cur_t > 8 * 3600
          local isDeal = fast and (not stale) and m.cur_min <= maxBuy and qtyCap > 0
          local profitUnit = trunc(net - m.cur_min)
          local dataConf = math.min(1.0, m.nscans / 10) * math.min(1.0, m.days_seen / 3)
          local confidence = math.max(0.05, dataConf * (1 - math.min(0.8, m.volatility * 1.5)) * (0.5 + p / 2))
          local est = estDays
          if not est or est == 0 then est = s.hold_days end
          local speed = 1.0 / math.max(0.25, est)
          local score
          if isDeal then
            score = math.max(0, profitUnit) * math.max(1, qtyCap) * confidence * speed
          else
            score = math.max(0, net - maxBuy) * m.vol_day * confidence * speed * 0.1
          end
          deals[#deals + 1] = { id = id, name = nameOf(id), cur = m.cur_min, expected = trunc(expected), max_buy = maxBuy,
            qty_cap = math.max(0, qtyCap), confidence = confidence, score = score, is_deal = isDeal, fast = fast,
            starter = false }
        end
      end
    end
  end
  table.sort(deals, function(a, b)
    if a.is_deal ~= b.is_deal then return a.is_deal end
    if a.fast ~= b.fast then return a.fast end
    if a.starter ~= b.starter then return not a.starter end
    if a.score ~= b.score then return a.score > b.score end
    return a.id < b.id
  end)
  return deals
end

-- build_plan(): the shopping list, plus the sell list (held stock from the app, market items fresh)
function P:BuildPlan(deals, model, c, nameOf, heldSells)
  local s = c.s
  local budget = trunc((tonumber(s.budget) or 0) * 10000 * 0.85)
  local perItem = math.max(1, trunc(budget * 0.40))
  local marginBase = s.min_margin * c.mf
  local buys, spent, starters = {}, 0, 0
  for _, d in ipairs(deals) do
    if #buys >= s.max_plan_items then break end
    if d.qty_cap > 0 and d.fast then
      if d.starter then
        if starters < idiv(s.max_plan_items, 2) then
          local m = model[d.id]
          local qty = trunc(math.min(d.qty_cap, idiv(perItem, math.max(1, m.cur_min)), math.max(1, idiv(m.cur_qty, 20))))
          if qty >= 5 then
            starters = starters + 1
            buys[#buys + 1] = { id = d.id, name = d.name, gap = floor((marginBase + 0.05) * 1000 + 0.5) / 1000, qty = qty,
              max = trunc(math.max(m.cur_p25, m.market) * 1.5) }
          end
        end
      elseif d.is_deal then
        local qty = trunc(math.min(d.qty_cap, idiv(budget - spent, math.max(1, d.cur)), idiv(perItem, math.max(1, d.max_buy))))
        if qty > 0 then
          spent = spent + qty * d.cur
          buys[#buys + 1] = { id = d.id, name = d.name, max = d.max_buy, qty = qty, exp = d.expected }
        end
      elseif not (d.confidence < 0.4 or #buys >= s.max_plan_items * 0.75) then
        local qty = trunc(math.min(math.max(1, idiv(d.qty_cap, 2)), idiv(perItem, math.max(1, d.max_buy))))
        if qty > 0 then
          buys[#buys + 1] = { id = d.id, name = d.name, max = d.max_buy, qty = qty, exp = d.expected }
        end
      end
    end
  end

  local sells, seen = {}, {}
  for _, e in ipairs(heldSells or {}) do
    sells[#sells + 1] = e
    seen[tonumber(e.id) or 0] = true
  end
  if s.sell_farmed then
    local farmed = {}
    for id, m in pairs(model) do
      if not seen[id] and m.market >= s.min_value_copper and (m.cur_qty >= 10 or (m.vol_day or 0) >= 1) then
        local liq = m.vol_day ~= nil and m.vol_day or m.cur_qty / 10
        farmed[#farmed + 1] = { m = m, key = liq * sqrt(m.market) }
      end
    end
    table.sort(farmed, function(a, b) if a.key ~= b.key then return a.key > b.key end return a.m.id < b.m.id end)
    for i = 1, math.min(600, #farmed) do
      local m = farmed[i].m
      local normal = trunc(m.market * (c.ic[m.id] or c.gc))
      sells[#sells + 1] = { id = m.id, name = nameOf(m.id), floor = trunc(normal * 0.75), normal = normal, ceil = trunc(normal * 1.6) }
    end
  end
  return { budget = budget, cut = s.ah_cut, duration = s.duration, buy = buys, sell = sells }, spent
end

-- Units this character bought in game since the app's list was made (not in the app's numbers yet)
local function boughtSince(t)
  local held, me = {}, UnitName("player")
  for _, ev in ipairs(FF:DB().log or {}) do
    if ev.e == "buy" and ev.id and (ev.t or 0) > t and (ev.char == nil or ev.char == me) then
      held[ev.id] = (held[ev.id] or 0) + (ev.q or 0)
    end
  end
  return held
end

-- Plan straight from data (also used by the tests) -----------------------------------------
-- The market model for the saved scans, cached until a new scan arrives (tooltips use it)
local modelKey, modelCache
function P:Model()
  local scans = FF:DB().scans
  local key = #scans .. ":" .. ((scans[#scans] or {}).t or 0)
  if key ~= modelKey then
    modelKey, modelCache = key, self:MarketModel(scans, time())
  end
  return modelCache
end

-- Units sold per day on the AH (estimated from listings vanishing between full scans), or nil
function P:SellsPerDay(id)
  local m = id and self:Model()[id]
  return m and m.vol_day
end

function P:Compute(scans, ctx, now, nameOf, heldSells, extraHeld)
  local model = self:MarketModel(scans, now)
  local c = self:Context(ctx, extraHeld)
  local deals = self:Recommend(model, c, now, nameOf)
  return self:BuildPlan(deals, model, c, nameOf, heldSells)
end

-- Vendor flips: listings priced below what a merchant pays. Buying and vendoring them is a
-- guaranteed profit (no auction, no deposit, no waiting). Only fresh scan data, at least 15%
-- and 5 copper profit per unit, best first.
function P:VendorFlips(model, now, maxCount)
  local out = {}
  for id, m in pairs(model or {}) do
    if m.cur_min > 0 and m.cur_min <= 50000 and now - m.cur_t <= 8 * 3600 then
      local v = FF:VendorPrice(id)
      if v and m.cur_min <= v * 0.85 and v - m.cur_min >= 5 then
        out[#out + 1] = { id = id, max = math.floor(v * 0.9), qty = math.max(1, math.min(m.cur_qty, 40)),
          vendor = true, profit = v - m.cur_min }
      end
    end
  end
  table.sort(out, function(a, b)
    local pa, pb = a.profit * a.qty, b.profit * b.qty
    if pa ~= pb then return pa > pb end
    return a.id < b.id
  end)
  for i = #out, (maxCount or 15) + 1, -1 do out[i] = nil end
  for _, e in ipairs(out) do e.name = FF:ItemName(e.id) end
  return out
end

-- At a merchant: sell what you bought as vendor flips (setting: autoVendor)
function P:SellVendorFlips()
  local db = FF:DB()
  local flips = db.vendorFlips
  if not (flips and next(flips)) or FlipForeverDB.settings.autoVendor == false then return 0 end
  local C = C_Container
  if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo and C.UseContainerItem) then return 0 end
  -- forget flips you no longer carry (sold earlier, or used)
  for id in pairs(flips) do if (C_Item.GetItemCount and C_Item.GetItemCount(id, false) or 0) == 0 then flips[id] = nil end end
  local sold, gold = 0, 0
  for bag = 0, 4 do
    for slot = 1, C.GetContainerNumSlots(bag) or 0 do
      local info = C.GetContainerItemInfo(bag, slot)
      local id = info and info.itemID
      if id and flips[id] and not info.isLocked then
        gold = gold + (FF:VendorPrice(id) or 0) * (info.stackCount or 1)
        C.UseContainerItem(bag, slot)
        sold = sold + (info.stackCount or 1)
      end
    end
  end
  if sold > 0 then
    FF:Print(("Sold %d vendor-flip item%s to the merchant for %s."):format(sold, sold > 1 and "s" or "", FF:Money(gold)))
  end
  return sold
end

FF:On("MERCHANT_SHOW", function() pcall(P.SellVendorFlips, P) end)

function P:Enabled() return FlipForeverDB.settings.livePlanning ~= false end

local function newestScan()
  local scans = FF:DB().scans
  local t = 0
  for _, sc in ipairs(scans) do if (sc.t or 0) > t then t = sc.t end end
  return t
end

-- Rebuild the playing character's list from the saved scans. Returns the plan or nil.
function P:Rebuild()
  if not self:Enabled() then return nil end
  local scans = FF:DB().scans
  if #scans == 0 then return nil end
  local file = FF:FilePlan()
  local ctx = file and file.ctx
  if not ctx then
    -- no list from the app yet: plan with the app's defaults and the gold you carry
    ctx = { s = { budget = (GetMoney and GetMoney() or 0) / 10000 } }
  end
  local heldSells = {}
  if file and file.sell then
    local heldIds = numKeys(ctx.held)
    for _, e in ipairs(file.sell) do
      if e.held or heldIds[tonumber(e.id) or 0] then heldSells[#heldSells + 1] = e end
    end
  end
  local ok, plan = pcall(self.Compute, self, scans, ctx, time(), function(id) return FF:ItemName(id) end, heldSells,
    boughtSince(file and file.generated or 0))
  if not ok or type(plan) ~= "table" then
    FF.livePlan = nil
    return nil
  end
  -- plus vendor flips from the same scan (bought below what a merchant pays)
  if FlipForeverDB.settings.vendorFlips ~= false then
    for _, e in ipairs(self:VendorFlips(self:Model(), time(), 15)) do plan.buy[#plan.buy + 1] = e end
  end
  plan.generated = newestScan()   -- stable across reloads, so progress on this list is kept
  plan.realm = FF:RealmKey()
  plan.key = FF:CharKey()
  plan.live = true
  plan.ctx = ctx
  FF.livePlan = plan
  return plan
end

-- At login: if there's a scan newer than the app's list, plan from it right away
FF:On("PLAYER_LOGIN", function()
  C_Timer.After(4, function()
    if not P:Enabled() then return end
    local file = FF:FilePlan()
    if newestScan() > (file and file.generated or 0) then
      local plan = P:Rebuild()
      if plan then
        FF:Print(("Shopping list rebuilt in game from your newest scan: %d to buy, %d to sell."):format(#plan.buy, #plan.sell))
        if FF.UI and FF.UI.Refresh then FF.UI:Refresh() end
      end
    end
  end)
end)

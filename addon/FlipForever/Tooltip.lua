-- FlipForever: price lines in item tooltips (like Auctionator's), so you see at a glance
-- what an item usually goes for and whether it's on your shopping or sell list.
-- Read-only: it only adds lines to Blizzard's tooltip.
local FF = FlipForever
local TT = {}
FF.Tooltip = TT

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

-- index the current character's shopping list by item (rebuilt when the list changes)
local index, indexGen = {}, nil
local function planIndex()
  local plan = FF:Plan()
  local gen = plan and plan.generated or 0
  if gen ~= indexGen then
    indexGen, index = gen, {}
    if plan then
      for _, b in ipairs(plan.buy or {}) do index[b.id] = index[b.id] or {} index[b.id].buy = b end
      for _, s in ipairs(plan.sell or {}) do index[s.id] = index[s.id] or {} index[s.id].sell = s end
    end
  end
  return index
end

function TT:Enabled()
  return FlipForeverDB and FlipForeverDB.settings.tooltips ~= false
end

-- the lines for one item (also used by the tests)
function TT:Lines(itemID)
  local out = {}
  if not itemID then return out end
  local price = FF:PriceOf(itemID)
  if price then out[#out + 1] = { FF:T("|cff33ff99FlipForever|r typical price"), FF:Money(price) } end
  local perDay = FF.Planner and FF.Planner:SellsPerDay(itemID)
  if perDay then
    local speed = perDay >= 10 and FF:T("|cff33ff99fast|r") or perDay >= 3 and FF:T("|cffffd200ok|r") or FF:T("|cffff8800slow|r")
    out[#out + 1] = { FF:T("  sells on the AH"), FF:T("~%s/day (%s)"):format(perDay >= 10 and ("%d"):format(math.floor(perDay + 0.5)) or ("%.1f"):format(perDay), speed) }
  end
  local entry = planIndex()[itemID]
  if entry and entry.buy then
    local b = entry.buy
    out[#out + 1] = { FF:T("  on your shopping list"), b.gap and FF:T("price checked live") or FF:T("max %s"):format(FF:Money(b.max)) }
  end
  if entry and entry.sell then
    out[#out + 1] = { FF:T("  you post at"), FF:T("%s (never below %s)"):format(FF:Money(entry.sell.normal), FF:Money(entry.sell.floor)) }
  end
  -- gear: is this better than what you wear? (same stat weights as the Gear tab)
  local up = FlipForeverDB.settings.gearTooltip ~= false and TT:Upgrade(itemID)
  if up then
    out[#out + 1] = up
    if up.diff and up.diff ~= "" then out[#out + 1] = { " ", up.diff } end
  end
  return out
end

function TT:Upgrade(itemID)
  local G = FF.Gear
  if not (G and G.Check) then return nil end
  local level = UnitLevel and UnitLevel("player") or 1
  local ok, r = pcall(G.Check, G, itemID, 0, level, G:Weights(), math.huge, 1)
  if not (ok and type(r) == "table") then return nil end
  local slot = G.SLOT_NAMES and G.SLOT_NAMES[r.slot] or ""
  local gain = r.pct and ("+%d%%"):format(math.floor(r.pct * 100 + 0.5)) or ("+%.1f"):format(r.gain)
  local diff = ""
  if FlipForeverDB.settings.gearStats ~= false and G.StatDiffText then
    local okD, d = pcall(G.StatDiffText, G, r, 4)
    diff = okD and d or ""
  end
  return { FF:T("  upgrade for you"), ("|cff33ff99%s|r %s"):format(gain, FF:T(slot)), diff = diff }
end

local function addTo(tooltip, itemID)
  if not TT:Enabled() then return end
  local lines = TT:Lines(itemID)
  if #lines == 0 then return end
  for _, l in ipairs(lines) do tooltip:AddDoubleLine(l[1], l[2], 0.8, 0.8, 0.8, 1, 1, 1) end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    local id = data and plain(data.id)
    if type(id) == "number" then pcall(addTo, tooltip, id) end
  end)
end

-- Bag value: what your bags are worth at the merchant and at the auction house (after the 5% cut),
-- and which items are worth posting instead of vendoring. Shown on the Overview; hover the line
-- for the list. Setting: bagValue (on by default).
local FF = FlipForever
local BV = {}
FF.BagValue = BV

local AH_CUT = 0.05
local POOR = 0

function BV:Enabled() return FlipForeverDB.settings.bagValue ~= false end

-- worth posting: tradeable, not grey, and the auction house pays at least 1.5x the merchant
-- price and at least 50 copper more
local function worthPosting(vendor, ah)
  return ah > 0 and ah >= vendor * 1.5 and ah - vendor >= 50
end

function BV:Compute()
  local out = { vendor = 0, ah = 0, post = {} }
  local C = C_Container
  if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return out end
  local byId = {}
  for bag = 0, 4 do
    for slot = 1, C.GetContainerNumSlots(bag) or 0 do
      local info = C.GetContainerItemInfo(bag, slot)
      local id = info and info.itemID
      if id then
        local count = info.stackCount or 1
        local vendor = (info.hasNoValue and 0 or (FF:VendorPrice(id) or 0)) * count
        out.vendor = out.vendor + vendor
        local price = (not info.isBound and info.quality ~= POOR) and FF:PriceOf(id) or nil
        local ah = price and math.floor(price * (1 - AH_CUT)) * count or 0
        -- what you'd get selling it the better way
        out.ah = out.ah + math.max(ah, vendor)
        if worthPosting(vendor, ah) then
          local e = byId[id]
          if not e then
            e = { id = id, count = 0, ah = 0, vendor = 0 }
            byId[id] = e
            out.post[#out.post + 1] = e
          end
          e.count, e.ah, e.vendor = e.count + count, e.ah + ah, e.vendor + vendor
        end
      end
    end
  end
  table.sort(out.post, function(a, b) return (a.ah - a.vendor) > (b.ah - b.vendor) end)
  return out
end

-- cached until your bags change
function BV:Get()
  if not self.cache then self.cache = self:Compute() end
  return self.cache
end

function BV:Line()
  if not self:Enabled() then return "" end
  local v = self:Get()
  if v.vendor == 0 and v.ah == 0 then return "" end
  local line = FF:T("Bags: %s at the merchant  ·  %s selling the best way"):format(FF:Money(v.vendor), FF:Money(v.ah))
  if #v.post > 0 then line = line .. "  ·  " .. FF:T("|cff33ff99%d worth posting|r"):format(#v.post) end
  return line
end

-- the hover list: the items worth posting, the biggest gain first
function BV:Tooltip(tip)
  local v = self:Get()
  tip:AddLine(FF:T("Worth posting at the auction house"), 1, 0.82, 0)
  if #v.post == 0 then
    tip:AddLine(FF:T("Nothing in your bags sells clearly better there than at a merchant."), 1, 1, 1, true)
    return
  end
  for i, e in ipairs(v.post) do
    if i > 10 then tip:AddLine(FF:T("(+%d more)"):format(#v.post - 10), 0.6, 0.6, 0.6) break end
    local name = FF:ItemName(e.id) or ("item " .. e.id)
    tip:AddDoubleLine(("%s x%d"):format(name, e.count), FF:Money(e.ah) .. "  |cff888888(" .. FF:Money(e.vendor) .. ")|r", 1, 1, 1, 1, 1, 1)
  end
  tip:AddLine(FF:T("Auction price after the 5% cut; merchant price in grey. Based on your last scan."), 0.6, 0.6, 0.6, true)
end

FF:On("BAG_UPDATE_DELAYED", function() BV.cache = nil end)
FF:On("PLAYER_ENTERING_WORLD", function() BV.cache = nil end)

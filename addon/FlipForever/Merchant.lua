-- Merchant: sell grey items and repair in one go. A small strip under the game's merchant window
-- has a Sell junk button and two switches (sell junk / repair on every visit, both off at first).
local FF = FlipForever
local M = {}
FF.Merchant = M

local POOR = 0 -- item quality of grey items

local function settings() return FlipForeverDB.settings end
function M:AutoJunk() return settings().autoJunk == true end
function M:AutoRepair() return settings().autoRepair == true end

-- grey items in your bags: list of { bag, slot, id, count, value }
function M:Junk()
  local out = {}
  local C = C_Container
  if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return out end
  for bag = 0, 4 do
    for slot = 1, C.GetContainerNumSlots(bag) or 0 do
      local info = C.GetContainerItemInfo(bag, slot)
      if info and info.itemID and info.quality == POOR and not info.isLocked and not info.hasNoValue then
        local count = info.stackCount or 1
        out[#out + 1] = { bag = bag, slot = slot, id = info.itemID, count = count, value = (FF:VendorPrice(info.itemID) or 0) * count }
      end
    end
  end
  return out
end

-- sell every grey item; returns how many stacks and the gold they fetched
function M:SellJunk(quiet)
  local C = C_Container
  if not (C and C.UseContainerItem) then return 0, 0 end
  if MerchantFrame and MerchantFrame.IsShown and not MerchantFrame:IsShown() then return 0, 0 end
  local sold, gold = 0, 0
  for _, e in ipairs(self:Junk()) do
    if e.value > 0 then
      C.UseContainerItem(e.bag, e.slot)
      sold, gold = sold + 1, gold + e.value
    end
  end
  if sold > 0 and not quiet then
    FF:Print(FF:T("Sold %d grey item%s for %s."):format(sold, FF:Plural(sold), FF:Money(gold)))
  end
  return sold, gold
end

-- repair everything with your own gold (never the guild bank); returns the cost, 0 if nothing
function M:Repair(quiet)
  if not (CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost and RepairAllItems) then return 0 end
  local cost, can = GetRepairAllCost()
  cost = tonumber(cost) or 0
  if cost <= 0 or not can then return 0 end
  if (GetMoney and GetMoney() or 0) < cost then
    if not quiet then FF:Print(FF:T("Not enough gold to repair (%s)."):format(FF:Money(cost))) end
    return 0
  end
  RepairAllItems(false)
  if not quiet then FF:Print(FF:T("Repaired everything for %s."):format(FF:Money(cost))) end
  return cost
end

-- the strip under the merchant window
local strip
function M:Strip()
  if strip or not MerchantFrame then return strip end
  strip = CreateFrame("Frame", "FlipForeverMerchantStrip", MerchantFrame, "BackdropTemplate")
  strip:SetSize(330, 30)
  strip:SetPoint("TOPLEFT", MerchantFrame, "BOTTOMLEFT", 0, -2)
  if strip.SetBackdrop then
    strip:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    strip:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
  end
  strip.sell = CreateFrame("Button", nil, strip, "UIPanelButtonTemplate")
  strip.sell:SetSize(80, 20)
  strip.sell:SetPoint("LEFT", 6, 0)
  strip.sell:SetText(FF:T("Sell junk"))
  strip.sell:SetScript("OnClick", function() M:SellJunk() M:RefreshStrip() end)
  local function check(label, key, x)
    local c = CreateFrame("CheckButton", nil, strip, "UICheckButtonTemplate")
    c:SetSize(22, 22)
    c:SetPoint("LEFT", x, 0)
    c.text = c.text or c.Text or strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.text:ClearAllPoints()
    c.text:SetPoint("LEFT", c, "RIGHT", 0, 1)
    c.text:SetText(label)
    c:SetScript("OnClick", function(self) settings()[key] = self:GetChecked() and true or false end)
    return c
  end
  strip.auto = check(FF:T("Always sell junk"), "autoJunk", 92)
  strip.repair = check(FF:T("Always repair"), "autoRepair", 212)
  return strip
end

function M:RefreshStrip()
  local s = self:Strip()
  if not s then return end
  s.auto:SetChecked(self:AutoJunk())
  s.repair:SetChecked(self:AutoRepair())
  local value = 0
  for _, e in ipairs(self:Junk()) do value = value + e.value end
  if s.sell.SetEnabled then s.sell:SetEnabled(value > 0) end
  s:Show()
end

function M:OnMerchant()
  if self:AutoRepair() then self:Repair() end
  if self:AutoJunk() then self:SellJunk() end
  self:RefreshStrip()
end

FF:On("MERCHANT_SHOW", function() pcall(M.OnMerchant, M) end)

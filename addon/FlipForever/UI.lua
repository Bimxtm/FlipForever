-- FlipForever: the panel docked next to the auction house.
-- Plays nice with other addons: own uniquely named frames only, no changes to Blizzard or
-- other addons' frames, remembers where you drag it (in case Auctionator/Auctioneer
-- put something in the same spot), and the action key is only bound while the AH is open.
local FF = FlipForever
local UI = {}
FF.UI = UI

local WIDTH = 290

local function button(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h or 24)
  b:SetText(FF:T(text))
  return b
end

function UI:Build()
  if self.frame then return end
  -- shown next to the auction house: no Escape or close button of its own
  local f = FF:Window("FlipForeverPanel", WIDTH, 430, { pos = "panelPos", strata = "HIGH", alpha = 0.95, escape = false, close = false })
  self.frame = f

  -- flashing gold glow while a deal waits for you
  local glow = f:CreateTexture(nil, "BACKGROUND")
  glow:SetPoint("TOPLEFT", -6, 6)
  glow:SetPoint("BOTTOMRIGHT", 6, -6)
  glow:SetColorTexture(1, 0.8, 0.1, 0.55)
  glow:Hide()
  local anim = glow:CreateAnimationGroup()
  anim:SetLooping("BOUNCE")
  local fade = anim:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0.1)
  fade:SetDuration(0.45)
  self.glow, self.glowAnim = glow, anim

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -12)
  title:SetText("|cff33ff99Flip|rForever")

  local plan = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  plan:SetPoint("TOPLEFT", 14, -38)
  plan:SetPoint("TOPRIGHT", -14, -38)
  plan:SetJustifyH("LEFT")
  self.planText = plan

  local action = CreateFrame("Button", "FlipForeverActionButton", f, "UIPanelButtonTemplate")
  action:SetSize(WIDTH - 28, 54)
  action:SetPoint("TOP", 0, -78)
  action:SetNormalFontObject("GameFontNormalLarge")
  action:SetHighlightFontObject("GameFontHighlightLarge")
  action:SetScript("OnClick", function() FF.Trader:Primary() end)
  self.action = action

  local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  status:SetPoint("TOPLEFT", 14, -142)
  status:SetPoint("TOPRIGHT", -14, -142)
  status:SetHeight(58)
  status:SetJustifyH("LEFT")
  status:SetJustifyV("TOP")
  self.statusText = status

  local bw = (WIDTH - 36) / 2
  local buy = button(f, "Buy deals", bw)
  buy:SetPoint("TOPLEFT", 14, -206)
  buy:SetScript("OnClick", function() FF.Trader:StartBuying() end)

  local sell = button(f, "Post my items", bw)
  sell:SetPoint("TOPRIGHT", -14, -206)
  sell:SetScript("OnClick", function() FF.Trader:StartSelling() end)

  local skip = button(f, "Skip", bw)
  skip:SetPoint("TOPLEFT", 14, -234)
  skip:SetScript("OnClick", function() FF.Trader:Skip() end)

  local stop = button(f, "Stop", bw)
  stop:SetPoint("TOPRIGHT", -14, -234)
  stop:SetScript("OnClick", function() FF.Trader:Stop() end)

  local scan = button(f, "Full scan", WIDTH - 28)
  scan:SetPoint("TOP", 0, -266)
  scan:SetScript("OnClick", function() FF.Scan:StartFull(false) end)
  self.scanButton = scan

  local auto = button(f, "Autopilot: OFF", WIDTH - 28, 28)
  auto:SetPoint("TOP", 0, -298)
  auto:SetScript("OnClick", function() FF.Auto:SetEnabled(not FF.Auto:Enabled()) end)
  self.autoButton = auto
  if not FF.Auto.AVAILABLE then auto:Hide() end

  local autoText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  autoText:SetPoint("TOPLEFT", 14, -332)
  autoText:SetPoint("TOPRIGHT", -14, -332)
  autoText:SetJustifyH("LEFT")
  self.autoText = autoText

  local mats = button(f, "Buy profession mats", WIDTH - 28, 24)
  mats:SetPoint("TOP", 0, -352)
  mats:SetScript("OnClick", function() FF.Professions:BuyPending() end)
  mats:Hide()
  self.matsButton = mats

  local settings = button(f, "Settings", 70, 20)
  settings:SetPoint("TOPRIGHT", -10, -10)
  settings:SetScript("OnClick", function() FF.Hub:Show("settings") end)

  -- one click instead of typing /reload: loads a new shopping list from the app and saves
  -- your scans so the app can import them
  local reload = button(f, "Reload", 60, 20)
  reload:SetPoint("TOPLEFT", 10, -10)
  reload:SetScript("OnClick", function() FF:ReloadForSync() end)
  self.reloadButton = reload
  reload:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Reload: load new list")
    GameTooltip:AddLine("Loads the shopping list the app just built, and saves your scans so the app can import them.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  reload:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 14, 12)
  hint:SetPoint("BOTTOMRIGHT", -14, 12)
  hint:SetJustifyH("LEFT")
  self.hint = hint

  FF.OnStatus = function() UI:Refresh() end
end

function UI:Refresh()
  if not self.frame then return end
  local T = FF.Trader
  local p = FF:Plan()
  if p and p.buy then
    local age = math.floor((time() - (p.generated or time())) / 60)
    local ageText = age < 90 and FF:T("%d min"):format(age) or FF:T("%d h"):format(math.floor(age / 60))
    local budget = (T.custom and FF:T("  ·  |cffffd200buying profession mats|r"))
      or (p.budget and FF:T("  ·  budget left %s"):format(FF:Money(T:BudgetLeft()))) or ""
    self.planText:SetText(FF:T("%s: |cffffff00%d|r buys, |cffffff00%d|r sells%s\n%s %s ago%s\n|cffaaaaaa%s|r"):format(
      UnitName("player") or "?", #p.buy, #(p.sell or {}), budget, p.live and FF:T("built in game from a scan") or FF:T("made"), ageText, age > 360 and FF:T(" |cffff8800(old - rebuild it)|r") or "",
      FF:TodayLine()))
  else
    self.planText:SetText(FF:T("|cffff8800No shopping list for %s yet.|r\nScan, pick this character in the app, build, /reload."):format(UnitName("player") or "?"))
  end
  self.action:SetText(T:ButtonText())
  self.action:SetEnabled(T:ButtonEnabled())
  self.statusText:SetText(FF.status or "")

  local pendingMats = FF.Professions and FF.Professions.pendingMats
  self.matsButton:SetShown(pendingMats ~= nil)
  -- after a scan: the Reload button lights up
  if FF.needReload then
    self.reloadButton:SetText(FF:T("|cffffd200") .. FF:T("Reload"):upper() .. "|r")
    self.reloadButton:LockHighlight()
  else
    self.reloadButton:SetText(FF:T("Reload"))
    self.reloadButton:UnlockHighlight()
  end
  if pendingMats then self.matsButton:SetText(FF:T("Buy profession mats (%d)"):format(#pendingMats)) end

  local auto = FF.Auto
  self.autoButton:SetText(auto:Enabled() and "|cff33ff99Autopilot: ON|r" or "Autopilot: OFF")
  self.autoText:SetText(auto:StatusLine())

  -- flash while a deal waits for the key press
  local waiting = T:WaitingForUser() or FF.needReload
  if waiting and not self.glow:IsShown() then
    self.glow:Show()
    self.glowAnim:Play()
  elseif not waiting and self.glow:IsShown() then
    self.glowAnim:Stop()
    self.glow:Hide()
  end

  local key = FlipForeverDB.settings.key
  self.hint:SetText(key and ("Action key: |cffffff00" .. key .. "|r (only while the AH is open)")
    or "Tip: Settings > Set key binds the big button")
end

function UI:ApplyKey()
  if not self.frame then return end
  if InCombatLockdown() then return end
  ClearOverrideBindings(self.frame)
  local key = FlipForeverDB.settings.key
  if key and self.frame:IsShown() then
    SetOverrideBindingClick(self.frame, false, key, "FlipForeverActionButton")
  end
  self:Refresh()
end

FF:On("AUCTION_HOUSE_SHOW", function()
  UI:Build()
  local f = UI.frame
  f:ClearAllPoints()
  local pos = FlipForeverDB.settings.panelPos
  if pos then
    f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  elseif AuctionHouseFrame then
    f:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 4, 0)
  else
    f:SetPoint("CENTER")
  end
  f:Show()
  UI:ApplyKey()
  if FF.Auto:Enabled() then
    FF.Auto.nextSearch = 0
    FF.Auto.nextScan = math.min(FF.Auto.nextScan or math.huge, FF.Auto:LastScanTime() + FF.Auto.SCAN_EVERY)
  end
end)

FF:On("AUCTION_HOUSE_CLOSED", function()
  if UI.frame then
    if not InCombatLockdown() then ClearOverrideBindings(UI.frame) end
    UI.glowAnim:Stop()
    UI.glow:Hide()
    UI.frame:Hide()
  end
end)

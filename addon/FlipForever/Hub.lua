-- FlipForever: the main window. Everything the addon can do is reachable from here with the
-- mouse - no slash commands needed. Opened by the gold-coin minimap button, the AddOns menu,
-- the Settings buttons on the auction house panel and in the Advisor, or /ff.
local FF = FlipForever
local H = {}
FF.Hub = H

local frame, mmButton, capture

-- Small widget helpers ---------------------------------------------------------------------------
local function button(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function check(parent, label, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
  c.text:SetText(label)
  c:SetScript("OnClick", onClick)
  return c
end

local function heading(parent, label, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", 16, y)
  fs:SetText(label)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.2, 0.8, 0.5, 0.35)
  line:SetHeight(1)
  line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
  line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
  return fs
end

-- Key capture: "press the key you want" ------------------------------------------------------------
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true }

local function startCapture(label, onKey)
  if InCombatLockdown() then FF:Print("Can't change keys during a fight.") return end
  if not capture then
    capture = CreateFrame("Frame", "FlipForeverKeyCapture", UIParent, "BackdropTemplate")
    capture:SetSize(320, 90)
    capture:SetPoint("CENTER", 0, 120)
    capture:SetFrameStrata("DIALOG")
    capture:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    capture:SetBackdropColor(0.05, 0.06, 0.08, 0.97)
    capture:SetBackdropBorderColor(1, 0.82, 0, 1)
    capture.text = capture:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    capture.text:SetPoint("CENTER")
    capture.text:SetWidth(290)
    capture:EnableKeyboard(true)
    capture:SetScript("OnKeyDown", function(self, key)
      if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
      if MODIFIERS[key] then return end
      self:Hide()
      if key == "ESCAPE" then return end
      local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
      if self.onKey then self.onKey(combo) end
    end)
    -- mouse buttons 4/5 work too
    capture:SetScript("OnMouseDown", function(self, mouse)
      if mouse == "Button4" or mouse == "Button5" then
        self:Hide()
        if self.onKey then self.onKey(mouse:upper()) end
      end
    end)
  end
  capture.onKey = onKey
  capture.text:SetText("Press the key you want for\n|cffffd200" .. label .. "|r\n\n|cff888888(Escape cancels)|r")
  capture:Show()
end

-- The window ----------------------------------------------------------------------------------------
local function build()
  local f = CreateFrame("Frame", "FlipForeverHub", UIParent, "BackdropTemplate")
  f:SetSize(400, 580)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  f:SetBackdropColor(0.05, 0.06, 0.08, 0.96)
  f:SetBackdropBorderColor(0.2, 0.8, 0.5, 1)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    FlipForeverDB.settings.hubPos = { point, relPoint, x, y }
  end)
  local pos = FlipForeverDB.settings.hubPos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", -200, 40) end
  tinsert(UISpecialFrames, "FlipForeverHub")
  CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", 2, 2)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText("|cff33ff99Flip|rForever")
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOPLEFT", 16, -36)
  sub:SetText("Auction house · Gathering · Advisor · Combat helper")

  -- Open --------------------------------------------------------------
  heading(f, "Open", -60)
  button(f, "Advisor", 118, function() FF.Advisor:Show() end):SetPoint("TOPLEFT", 16, -82)
  f.gather = button(f, "Gathering", 118, function()
    local ns = FF.gatherNS
    if ns and ns.ToggleMain and not ns.skipGather and ns.db then ns.ToggleMain()
    else FF:Print("Gathering is off: the old Ore Farmer addon is still enabled, or this client gives no map positions.") end
  end)
  f.gather:SetPoint("TOPLEFT", 140, -82)
  f.profs = button(f, "Professions", 118, function() FF.Professions:Toggle() end)
  f.profs:SetPoint("TOPLEFT", 264, -82)

  -- Combat helper -------------------------------------------------------
  heading(f, "Combat helper", -116)
  f.combat = check(f, "Show the combat helper", function() FF.Combat:Toggle() end)
  f.combat:SetPoint("TOPLEFT", 14, -136)
  f.combatMode = check(f, "Let Blizzard's one-button assistant decide", function() FF.Combat:ToggleBlizzard() end)
  f.combatMode:SetPoint("TOPLEFT", 14, -160)
  f.combatKeyText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.combatKeyText:SetPoint("TOPLEFT", 20, -192)
  f.combatKeyButton = button(f, "Set key", 80, function()
    startCapture("the combat helper", function(k) FF.Combat:SetKey(k) end)
  end)
  f.combatKeyButton:SetPoint("TOPLEFT", 206, -188)
  button(f, "Clear", 70, function() FF.Combat:SetKey(nil) end):SetPoint("TOPLEFT", 290, -188)
  local cHint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  cHint:SetPoint("TOPLEFT", 20, -214)
  cHint:SetPoint("RIGHT", -16, 0)
  cHint:SetJustifyH("LEFT")
  cHint:SetText("Follows the build you pick in the Advisor. Shift + right-drag the icon to move it.")

  -- Auction house -------------------------------------------------------
  heading(f, "Auction house", -240)
  f.auto = check(f, "Autopilot: check my list every minute, scan every 30 min", function() FF.Auto:SetEnabled(not FF.Auto:Enabled()) end)
  f.auto:SetPoint("TOPLEFT", 14, -260)
  f.ahKeyText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.ahKeyText:SetPoint("TOPLEFT", 20, -292)
  f.ahKeyButton = button(f, "Set key", 80, function()
    startCapture("the auction house button", function(k) FF:SetActionKey(k) end)
  end)
  f.ahKeyButton:SetPoint("TOPLEFT", 206, -288)
  button(f, "Clear", 70, function() FF:SetActionKey(nil) end):SetPoint("TOPLEFT", 290, -288)
  button(f, "Check the whole list again", 178, function() FF:ResetProgress() end):SetPoint("TOPLEFT", 16, -316)
  f.planText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.planText:SetPoint("TOPLEFT", 20, -344)
  f.planText:SetPoint("RIGHT", -16, 0)
  f.planText:SetJustifyH("LEFT")

  -- Advisor -------------------------------------------------------------
  heading(f, "Advisor", -372)
  f.popup = check(f, "Pop up my next steps on level-up", function(self)
    FlipForeverDB.settings.advisorPopup = self:GetChecked() and true or false
  end)
  f.popup:SetPoint("TOPLEFT", 14, -392)
  f.tips = check(f, "Prices in item tooltips", function(self)
    FlipForeverDB.settings.tooltips = self:GetChecked() and true or false
  end)
  f.tips:SetPoint("TOPLEFT", 206, -392)

  -- Buttons on screen ---------------------------------------------------
  heading(f, "Buttons on screen", -424)
  f.mm = check(f, "FlipForever minimap button", function(self)
    FlipForeverDB.settings.hideMinimap = not self:GetChecked()
    H:ApplyMinimap()
  end)
  f.mm:SetPoint("TOPLEFT", 14, -444)
  f.oreMM = check(f, "Gathering (ore) minimap button", function(self)
    local ns = FF.gatherNS
    if ns and ns.SetMinimapButtonShown and ns.db then ns.SetMinimapButtonShown(self:GetChecked()) end
  end)
  f.oreMM:SetPoint("TOPLEFT", 14, -468)
  f.tracker = check(f, "Gathering tracker (next stop, live gold)", function(self)
    local ns = FF.gatherNS
    if ns and ns.SetTrackerShown and ns.db then ns.SetTrackerShown(self:GetChecked()) end
  end)
  f.tracker:SetPoint("TOPLEFT", 14, -492)
  f.profPanel = check(f, "Planner next to profession windows", function(self)
    FlipForeverDB.settings.profPanel = self:GetChecked() and true or false
  end)
  f.profPanel:SetPoint("TOPLEFT", 14, -516)

  local foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  foot:SetPoint("BOTTOMLEFT", 16, 14)
  foot:SetPoint("RIGHT", -16, 0)
  foot:SetJustifyH("LEFT")
  foot:SetText("Buy / post / scan buttons appear next to the auction house when you open it.")
  f:Hide()
  return f
end

function H:Refresh()
  if not (frame and frame:IsShown()) then return end
  local s = FlipForeverDB.settings
  frame.combat:SetChecked(FF.Combat:Enabled())
  frame.combatMode:SetChecked(s.combatBlizzard == true)
  frame.combatMode:SetEnabled(FF.Combat:BlizzardAssistSpell() ~= nil)
  frame.combatMode.text:SetText(FF.Combat:BlizzardAssistSpell() and "Let Blizzard's one-button assistant decide"
    or "|cff888888Blizzard's one-button assistant (not in this client)|r")
  frame.combatKeyText:SetText("Key: " .. (s.combatKey and ("|cffffff00" .. s.combatKey .. "|r") or "|cff888888none - click the icon|r"))
  frame.auto:SetChecked(FF.Auto:Enabled())
  frame.ahKeyText:SetText("Big-button key: " .. (s.key and ("|cffffff00" .. s.key .. "|r") or "|cff888888none - click it|r"))
  local plan = FF:Plan()
  frame.planText:SetText(plan and plan.buy and ("Shopping list for " .. (UnitName("player") or "?") .. ": " .. #plan.buy .. " buys, " .. #(plan.sell or {}) .. " sell prices.")
    or "No shopping list for this character yet - build one in the FlipForever app.")
  frame.popup:SetChecked(s.advisorPopup ~= false)
  frame.tips:SetChecked(s.tooltips ~= false)
  frame.profPanel:SetChecked(s.profPanel ~= false)
  frame.mm:SetChecked(not s.hideMinimap)
  local ns = FF.gatherNS
  local gatherOn = ns and ns.db and not ns.skipGather
  frame.oreMM:SetEnabled(gatherOn and true or false)
  frame.tracker:SetEnabled(gatherOn and true or false)
  if gatherOn then
    frame.oreMM:SetChecked(ns.db.minimapButton ~= false)
    frame.tracker:SetChecked(ns.db.panelShown ~= false)
  end
end

function H:Toggle()
  frame = frame or build()
  if frame:IsShown() then frame:Hide() else frame:Show() H:Refresh() end
end

function H:Show()
  frame = frame or build()
  frame:Show()
  H:Refresh()
end

-- Quick summary for the minimap tooltip ------------------------------------------------------------
function H:Summary()
  local out = {}
  local plan = FF:Plan()
  if plan and plan.buy then
    local left = plan.budget and ("  ·  budget left " .. FF:Money(FF.Trader:BudgetLeft())) or ""
    out[#out + 1] = ("Shopping list: %d to check%s"):format(#plan.buy, left)
  else
    out[#out + 1] = "No shopping list for this character yet"
  end
  out[#out + 1] = FF:TodayLine()
  if FF.Auto:Enabled() then
    local now = time()
    local nextScan = FF.Auto.nextScan and math.max(0, FF.Auto.nextScan - now)
    out[#out + 1] = "Autopilot on" .. (nextScan and ("  ·  next scan in " .. math.floor(nextScan / 60) .. " min") or "") .. " (at the AH)"
  end
  local adv = FF.Advisor and FF.Advisor.last
  if adv and adv[1] then
    out[#out + 1] = "Next: " .. adv[1].text:gsub("|T.-|t%s*", "")
  end
  return out
end

-- Minimap button (gold coin) ------------------------------------------------------------------------
local function placeMinimap()
  local angle = math.rad(FlipForeverDB.settings.minimapAngle or 200)
  local r = (Minimap:GetWidth() / 2) + 6
  mmButton:ClearAllPoints()
  mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function createMinimap()
  if mmButton or not Minimap then return end
  mmButton = CreateFrame("Button", "FlipForeverMinimapButton", Minimap)
  mmButton:SetSize(31, 31)
  mmButton:SetFrameStrata("MEDIUM")
  mmButton:SetFrameLevel(8)
  mmButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mmButton:RegisterForDrag("LeftButton")
  local icon = mmButton:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  local border = mmButton:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mmButton:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then FF.Advisor:Toggle() else H:Toggle() end
  end)
  mmButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      FlipForeverDB.settings.minimapAngle = math.deg(math.atan2(py / scale - my, px / scale - mx))
      placeMinimap()
    end)
  end)
  mmButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mmButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff33ff99Flip|rForever")
    for _, l in ipairs(H:Summary()) do GameTooltip:AddLine(l, 0.85, 0.85, 0.85, true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: FlipForever window", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Advisor (what to do next)", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  mmButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  placeMinimap()
end

function H:ApplyMinimap()
  createMinimap()
  if mmButton then mmButton:SetShown(not FlipForeverDB.settings.hideMinimap) end
end

FF:On("PLAYER_LOGIN", function()
  H:ApplyMinimap()
  -- one entry in the AddOns menu (top-right of the minimap) for everything
  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
      text = "FlipForever", icon = "Interface\\Icons\\INV_Misc_Coin_01", notCheckable = true,
      func = function() H:Toggle() end,
    })
  end
end)

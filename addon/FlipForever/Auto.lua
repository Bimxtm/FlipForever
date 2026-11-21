-- FlipForever: autopilot while the auction house is open.
--  * every minute: run through the shopping list looking for flips
--  * every 30 minutes: a fresh full scan; searching is paused until the scan has finished
--  * a found flip triggers a sound, raid-warning text, a flashing panel and a taskbar flash
-- Buying itself still needs your key press (Blizzard rule).
local FF = FlipForever
local A = { phase = "off" }
FF.Auto = A

A.SEARCH_EVERY = 60
A.SCAN_EVERY = 1800
A.SCAN_TIMEOUT = 660      -- the scan itself gives up after 10 min; this is a safety net
A.YIELD_SECONDS = 30      -- stay quiet this long after you or another addon used the AH
A.lastExternal = 0

local function settings() return FlipForeverDB.settings end
local function ahOpen() return AuctionHouseFrame and AuctionHouseFrame:IsShown() end

-- Sharing the auction house: notice when you or another addon (Auctionator, Auctioneer, ...)
-- sends a query, and step aside. hooksecurefunc only observes - it never changes their calls.
local QUERY_FUNCS = { "SendSearchQuery", "SendSellSearchQuery", "SendBrowseQuery", "RequestMoreBrowseResults",
  "SearchForFavorites", "SearchForItemKeys", "QueryOwnedAuctions", "QueryBids",
  "RefreshCommoditySearchResults", "RefreshItemSearchResults" }
for _, fn in ipairs(QUERY_FUNCS) do
  if C_AuctionHouse and C_AuctionHouse[fn] then
    hooksecurefunc(C_AuctionHouse, fn, function()
      if not FF.ownCall then A.lastExternal = time() end
    end)
  end
end

local function otherAddonScanning()
  local scan = AucAdvanced and AucAdvanced.Scan
  if scan and scan.IsScanning then
    local ok, busy = pcall(scan.IsScanning)
    if ok and busy then return true end
  end
  return false
end

function A:Enabled() return settings().auto == true end

function A:LastScanTime()
  local last = 0
  for _, s in ipairs(FF:DB().scans) do
    if s.src ~= "partial" and (s.t or 0) > last then last = s.t end
  end
  return last
end

function A:SetEnabled(on)
  settings().auto = on and true or false
  if on then
    self.nextSearch = 0
    self.nextScan = self:LastScanTime() + self.SCAN_EVERY
    self.scanBlocked = false
    FF:Print("Autopilot ON: checks your list every minute, full scan every 30 min (only while the auction house is open).")
  else
    self.phase = "off"
    FF:Print("Autopilot OFF.")
  end
  if FF.UI then FF.UI:Refresh() end
end

-- Alerts -----------------------------------------------------------------------------
function FF:Alert(text, soundKit)
  if PlaySound then
    local kit = soundKit or (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959
    pcall(PlaySound, kit, "Master")
  end
  if RaidNotice_AddMessage and RaidWarningFrame then
    local color = (ChatTypeInfo and ChatTypeInfo.RAID_WARNING) or { r = 1, g = 0.82, b = 0 }
    pcall(RaidNotice_AddMessage, RaidWarningFrame, text, color)
  end
  if FlashClientIcon then pcall(FlashClientIcon) end
  FF:Print("|cffffd200" .. text .. "|r")
end

-- Scan results -----------------------------------------------------------------------
function A:ScanDone(ok)
  self.scanStarted = nil
  if ok then
    self.scanBlocked = false
    self.nextScan = time() + self.SCAN_EVERY
    self.nextSearch = 0 -- search right away with fresh data
  end
end

function A:ScanFailed(reason)
  self.scanStarted = nil
  self.scanBlocked = true
  if FF.Scan.poller then FF.Scan.poller:Cancel() end
  FF.Scan.busy, FF.Scan.watch = nil, nil
  FF:Alert("FlipForever: auto-scan needs you - click Full scan. (" .. reason .. ")", SOUNDKIT and SOUNDKIT.READY_CHECK)
  FF:SetStatus("Autopilot paused: click Full scan. Searching resumes after the scan finishes.")
end

FF:On("ADDON_ACTION_BLOCKED", function(addon)
  if addon == "FlipForever" and A.scanStarted then A:ScanFailed("the game blocked it") end
end)
FF:On("ADDON_ACTION_FORBIDDEN", function(addon)
  if addon == "FlipForever" and A.scanStarted then A:ScanFailed("the game blocked it") end
end)

-- The heartbeat ------------------------------------------------------------------------
function A:Tick()
  if not self:Enabled() then self.phase = "off" return end
  if not ahOpen() then self.phase = "closed" return end
  local now = time()
  local T = FF.Trader

  -- 1) a scan is running (ours or another addon's): everything else waits
  if FF.Scan.busy then
    self.phase = FF.Scan.busy == "external" and "otherscan" or "scanning"
    if self.scanStarted and now - self.scanStarted > self.SCAN_TIMEOUT then
      self:ScanFailed("it took too long")
    end
    return
  end
  -- 2) an automatic scan failed: wait for the manual one
  if self.scanBlocked then self.phase = "needscan" return end
  -- 2b) a new scan is saved: wait for the reload (new shopping list) before buying again
  if FF.needReload and not T:WaitingForUser() then
    if self.sweeping and T.state == "searching" then T:Stop("Paused - reload to load the new shopping list.") end
    self.phase = "needreload"
    return
  end
  -- 3) a deal is waiting for your key press: never interrupt it
  if T:WaitingForUser() then self.phase = "deal" return end
  -- 4) you or another addon is using the auction house: step aside
  if otherAddonScanning() or now - self.lastExternal < self.YIELD_SECONDS then
    if self.sweeping and T.state == "searching" then
      T:Stop("Paused - the auction house is in use (you or another addon).")
    end
    self.phase = "yield"
    return
  end
  if T.state ~= "idle" then self.phase = "searching" return end
  -- a sweep just finished -> schedule the next one
  if self.sweeping then
    self.sweeping = false
    self.nextSearch = now + self.SEARCH_EVERY
  end
  -- 5) time for a fresh scan (only between sweeps, never over a waiting deal)
  if now >= (self.nextScan or 0) then
    local started, wait = FF.Scan:StartFull(true)
    if started then
      self.phase = "scanning"
      self.scanStarted = now
    else
      -- the shared full-scan slot is taken (maybe another addon just scanned - we read
      -- that one too); try again when it frees up
      self.nextScan = now + math.min(wait or 60, self.SCAN_EVERY) + 5
    end
    return
  end
  -- 5) time to check the shopping list
  if now >= (self.nextSearch or 0) then
    local plan = FF:Plan()
    if not (plan and plan.buy and #plan.buy > 0) then
      self.phase = "noplan"
      self.nextSearch = now + self.SEARCH_EVERY
      return
    end
    self.sweeping = true
    self.phase = "searching"
    T:StartBuying()
    return
  end
  self.phase = "waiting"
end

function A:StatusLine()
  if not self:Enabled() then return "Autopilot off" end
  local now = time()
  local function mmss(s) s = math.max(0, s) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end
  local p = self.phase
  if p == "closed" then return "Autopilot on (open the auction house)" end
  if p == "scanning" then return "|cff66ccffAuto: scanning the auction house...|r searches paused" end
  if p == "otherscan" then return "|cff66ccffAnother addon is scanning - reading its data too|r" end
  if p == "yield" then return "Auto: waiting - auction house in use (you / another addon)" end
  if p == "needscan" then return "|cffff5555Auto paused: click Full scan|r" end
  if p == "needreload" then return "|cffffd200Auto paused: click Reload for the new shopping list|r" end
  if p == "deal" then return "|cffffd200DEAL FOUND - press the button!|r" end
  if p == "searching" then return "Auto: checking your list..." end
  if p == "noplan" then return "|cffff8800Auto: no shopping list for this character|r" end
  return ("Auto: next check %s  ·  next scan %s"):format(mmss((self.nextSearch or now) - now), mmss((self.nextScan or now) - now))
end

C_Timer.NewTicker(1, function()
  local ok, err = pcall(A.Tick, A)
  if not ok then FF:Print("|cffff5555autopilot error:|r " .. tostring(err)) FF:RecordError("autopilot", err) end
  if FF.UI and FF.UI.frame and FF.UI.frame:IsShown() then FF.UI:Refresh() end
end)

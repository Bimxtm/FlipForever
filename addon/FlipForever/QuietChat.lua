-- Quiet chat for roleplay (switch quietChat): on RP realms (RP and RP-PvP rules), FlipForever's chat
-- lines stay out of the shared chat. They go to a chat tab named "FlipForever" when you have one
-- (/ff chattab makes it), otherwise they are kept for /ff log. Answers to your own /ff commands,
-- enemy player alerts and errors still show in the main chat.
local FF = FlipForever
local Q = {}
FF.QuietChat = Q
Q.log = {}
Q.TAB = "FlipForever"

local basePrint = FF.Print

function Q:Enabled() return FlipForeverDB ~= nil and FlipForeverDB.settings.quietChat ~= false end

-- quiet right now: switch on and this realm runs RP rules
function Q:Active()
  if not self:Enabled() then return false end
  local ok, rules = pcall(FF.Ruleset, FF)
  return ok and type(rules) == "string" and rules:find("RP") ~= nil
end

function Q:Tab()
  if not GetChatWindowInfo then return nil end
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local name = GetChatWindowInfo(i)
    if name == self.TAB then return _G["ChatFrame" .. i] end
  end
end

local function join(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  return table.concat(parts, " ")
end

-- always to the main chat (alerts, errors)
function FF:Loud(...)
  basePrint(self, ...)
end

function FF:Print(...)
  if FF.inSlash or not Q:Active() then return basePrint(self, ...) end
  local text = join(...)
  local tab = Q:Tab()
  if tab and tab.AddMessage then
    tab:AddMessage("|cff33ff99FlipForever|r: " .. text)
    return
  end
  local log = Q.log
  log[#log + 1] = (date and date("%H:%M ") or "") .. text
  if #log > 50 then table.remove(log, 1) end
  if not Q.told then
    Q.told = true
    basePrint(self, FF:T("Quiet chat (RP realm): FlipForever's messages stay out of chat. /ff log shows them, /ff chattab gives them their own tab. Settings, Features turns this off."))
  end
end

function Q:ShowLog()
  if #self.log == 0 then
    basePrint(FF, FF:T("Quiet chat: no kept messages."))
    return
  end
  basePrint(FF, FF:T("Quiet chat: the last %d messages:"):format(math.min(20, #self.log)))
  for i = math.max(1, #self.log - 19), #self.log do basePrint(FF, "  " .. self.log[i]) end
end

function Q:MakeTab()
  if self:Tab() then
    basePrint(FF, FF:T("The FlipForever chat tab already exists."))
    return true
  end
  if not FCF_OpenNewWindow then
    basePrint(FF, FF:T("This game client can't open a chat tab from an addon - right-click a chat tab, Create New Window, and name it FlipForever."))
    return false
  end
  local ok, f = pcall(FCF_OpenNewWindow, self.TAB)
  if ok and f and ChatFrame_RemoveAllMessageGroups then pcall(ChatFrame_RemoveAllMessageGroups, f) end
  basePrint(FF, ok and FF:T("Chat tab FlipForever made: FlipForever's messages go there on RP realms.")
    or FF:T("Couldn't make the chat tab - right-click a chat tab, Create New Window, and name it FlipForever."))
  return ok
end

-- /ff log, /ff chattab; every other /ff command answers in the main chat as before
local baseSlash = SlashCmdList.FLIPFOREVER
SlashCmdList.FLIPFOREVER = function(msg)
  local cmd = ((msg or ""):match("^(%S*)") or ""):lower()
  if cmd == "log" then return Q:ShowLog() end
  if cmd == "chattab" then return Q:MakeTab() end
  FF.inSlash = true
  local ok, err = pcall(baseSlash, msg)
  FF.inSlash = false
  if not ok then error(err, 0) end
end

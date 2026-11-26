-- Speak in dialect (switch chatDialect): rewrites what you type in a lore dialect (troll, orc, dwarf,
-- goblin, pirate) and sends it to the chat channel you pick. A small window (/ff talk) shows a live
-- preview; /fft <text> sends straight away in your character's dialect. Item links stay untouched.
local FF = FlipForever
local D = {}
FF.Dialect = D

D.ORDER = { "troll", "orc", "dwarf", "goblin", "pirate" }
D.NAMES = { troll = "Troll", orc = "Orc", dwarf = "Dwarf", goblin = "Goblin", pirate = "Pirate" }
D.RACE = { Troll = "troll", ZandalariTroll = "troll", Orc = "orc", MagharOrc = "orc", Dwarf = "dwarf",
  DarkIronDwarf = "dwarf", Goblin = "goblin" }

D.WORDS = {
  troll = {
    the = "da", this = "dis", that = "dat", these = "dese", those = "dose", them = "dem", they = "dey",
    there = "dere", their = "dere", ["then"] = "den", than = "dan", with = "wit", think = "tink", thing = "ting",
    things = "tings", nothing = "nuttin", something = "someting", anything = "anyting", everything = "everyting",
    you = "ya", your = "ya", ["you're"] = "ya be", my = "me", ["i'm"] = "I be", am = "be", is = "be", are = "be",
    man = "mon", friend = "mon", little = "likkle", brother = "bruddah", hello = "Hey dere", hi = "Hey",
    goodbye = "Stay away from da voodoo", bye = "Later, mon", three = "tree", thanks = "Tanks", thank = "tank",
    mother = "muddah", father = "faddah", other = "udda", going = "goin'", magic = "mojo",
  },
  orc = {
    hello = "Throm-ka", hi = "Throm-ka", greetings = "Throm-ka", yes = "Zug zug", yeah = "Zug zug",
    okay = "Dabu", ok = "Dabu", thanks = "Aka'magosh", thank = "Aka'magosh", goodbye = "Lok'tar",
    bye = "Lok'tar", victory = "Lok'tar ogar", friend = "blood brother", friends = "blood brothers",
    weak = "puny", small = "puny", fight = "crush", kill = "smash", enemy = "foe", enemies = "foes",
    great = "mighty", good = "strong", food = "grub", stupid = "foolish",
  },
  dwarf = {
    you = "ye", your = "yer", ["you're"] = "ye're", yes = "aye", yeah = "aye", no = "nae", ["not"] = "nae",
    my = "me", myself = "meself", ["don't"] = "dinnae", ["can't"] = "cannae", ["won't"] = "willnae",
    ["didn't"] = "didnae", ["isn't"] = "isnae", ["couldn't"] = "couldnae", ["wouldn't"] = "wouldnae",
    small = "wee", little = "wee", boy = "lad", girl = "lass", friend = "laddie", friends = "lads",
    know = "ken", of = "o'", ["and"] = "an'", going = "goin'", nothing = "nothin'", something = "somethin'",
    old = "auld", about = "aboot", hello = "Well met", hi = "Well met", beer = "ale", drink = "pint",
    goodbye = "Mind yer beard", bye = "Off wi' ye", very = "right", before = "afore", to = "tae",
  },
  goblin = {
    friend = "pal", friends = "pals", money = "cash", gold = "moolah", hello = "Hey there, pal",
    hi = "Hey, pal", sir = "boss", madam = "boss", cheap = "a steal", buy = "snag", sell = "flip",
    good = "top-notch", great = "first-rate", bad = "lousy", explosive = "boom-tastic", bomb = "kaboom",
    goodbye = "Time is money, friend", bye = "Gotta run, pal", deal = "bargain", fast = "quick",
    yes = "You got it", no = "No deal", ["thanks"] = "Pleasure doin' business",
  },
  pirate = {
    you = "ye", your = "yer", ["you're"] = "ye be", my = "me", yes = "aye", yeah = "aye", no = "nay",
    hello = "Ahoy", hi = "Ahoy", friend = "matey", friends = "mateys", is = "be", are = "be", am = "be",
    the = "th'", gold = "doubloons", money = "plunder", treasure = "booty", ["of"] = "o'",
    stop = "avast", look = "spy", goodbye = "Fair winds", bye = "Fair winds", boy = "lad", girl = "lass",
    ["and"] = "an'", going = "sailin'", wow = "Shiver me timbers",
  },
}

-- whole phrases, changed before single words
D.PHRASES = {
  troll = { { "thank you", "tanks, mon" }, { "going to", "gonna" }, { "want to", "wanna" } },
  orc = { { "thank you", "Aka'magosh" }, { "for the horde", "For da Horde" } },
  dwarf = { { "thank you", "thank ye kindly" }, { "going to", "gonnae" }, { "want to", "wantae" } },
  goblin = { { "thank you", "pleasure doin' business" }, { "how much", "what's it gonna cost me" } },
  pirate = { { "thank you", "thank ye, matey" }, { "oh my god", "shiver me timbers" } },
}

-- extra flavour around the whole message: start text, end text, and a pattern that means it's there already
D.WRAP = {
  troll = { nil, ", mon", "%f[%a]mon%f[%A]" },
  pirate = { "Arr, ", nil, "^%W*arr" },
}

local function caseless(phrase)
  return (phrase:gsub("%a", function(c) return "[" .. c:lower() .. c:upper() .. "]" end))
end

function D:Enabled() return FlipForeverDB ~= nil and FlipForeverDB.settings.chatDialect ~= false end

local function matchCase(src, word)
  if src:upper() == src and #src > 1 then return word:upper() end
  if src:sub(1, 1):match("%u") then return word:sub(1, 1):upper() .. word:sub(2) end
  return word
end

-- The dialect text; item links, spell links and colour codes are kept as they are.
function D:Translate(dialect, text)
  local words = self.WORDS[dialect]
  text = text or ""
  if not words or text == "" then return text end
  local kept = {}
  local s = text:gsub("|c%x+|H.-|h.-|h|r", function(link) kept[#kept + 1] = link return "\1" .. #kept .. "\2" end)
  s = s:gsub("|H.-|h.-|h", function(link) kept[#kept + 1] = link return "\1" .. #kept .. "\2" end)
  s = s:gsub("{.-}", function(mark) kept[#kept + 1] = mark return "\1" .. #kept .. "\2" end)
  local changed = false
  for _, p in ipairs(self.PHRASES[dialect] or {}) do
    s = s:gsub("%f[%a]" .. caseless(p[1]) .. "%f[%A]", function(found)
      changed = true
      local to = p[2]:gsub("%%", "%%%%")
      return matchCase(found, to)
    end)
  end
  s = s:gsub("[%a']+", function(w)
    local to = words[w:lower()]
    if to and to:lower() ~= w:lower() then changed = true return matchCase(w, to) end
    return w
  end)
  local wrap = self.WRAP[dialect]
  if wrap and s:find("%a") and not s:lower():find(wrap[3]) then
    if wrap[1] then
      local lead = s:match("^%s*\1") and "" or s:sub(1, 1):lower()
      s = wrap[1] .. (lead ~= "" and lead .. s:sub(2) or s)
    end
    if wrap[2] then
      local body, tail = s:match("^(.-)([%.!%?]*)%s*$")
      s = body .. wrap[2] .. tail
    end
  end
  s = s:gsub("\1(%d+)\2", function(i) return kept[tonumber(i)] end)
  return s, changed
end

-- Per character: the dialect picked last, else the one of the character's race (troll, orc...).
function D:Current()
  local store = FF.Advisor and FF.Advisor.CharStore and FF.Advisor:CharStore()
  local d = store and store.dialect
  if d and self.WORDS[d] then return d end
  local _, race = UnitRace and UnitRace("player")
  return self.RACE[race or ""] or "troll"
end

function D:SetCurrent(d)
  if not self.WORDS[d] then return end
  local store = FF.Advisor and FF.Advisor.CharStore and FF.Advisor:CharStore()
  if store then store.dialect = d end
end

D.CHANNELS = { "SAY", "YELL", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "WHISPER" }
D.CHANNEL_NAMES = { SAY = "Say", YELL = "Yell", PARTY = "Party", RAID = "Raid", INSTANCE_CHAT = "Instance",
  GUILD = "Guild", OFFICER = "Officer", WHISPER = "Whisper", EMOTE = "Emote", CHANNEL = "Channel" }

-- The chat line you were typing in (the channel /fft was typed in), else Say.
function D:ChatTarget()
  local eb = (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
    or (ChatEdit_GetLastActiveWindow and ChatEdit_GetLastActiveWindow())
  local kind = eb and eb.GetAttribute and eb:GetAttribute("chatType")
  if kind == "WHISPER" then return kind, eb:GetAttribute("tellTarget") end
  if kind == "CHANNEL" then return kind, eb:GetAttribute("channelTarget") end
  if kind and self.CHANNEL_NAMES[kind] then return kind end
  return "SAY"
end

-- Sends the text in the dialect; long text is split at spaces into chat-sized lines.
function D:Send(dialect, text, kind, target)
  local out = self:Translate(dialect, text)
  if not out or not out:find("%S") then return 0 end
  if (kind == "WHISPER" or kind == "CHANNEL") and not (target and tostring(target) ~= "") then
    FF:Print(FF:T("Pick who to whisper first."))
    return 0
  end
  local sent = 0
  while out ~= "" do
    local line = out
    if #line > 255 then
      local cut = line:sub(1, 255):match("^.*()%s") or 255
      line = out:sub(1, cut - 1)
    end
    out = out:sub(#line + 1):gsub("^%s+", "")
    line = line:gsub("%s+$", "")
    if line:find("%S") then
      SendChatMessage(line, kind or "SAY", nil, target)
      sent = sent + 1
    end
  end
  return sent
end

-- Window ---------------------------------------------------------------------------------------------
local win

function D:Refresh()
  if not win then return end
  local cur = self:Current()
  for d, b in pairs(win.dialectButtons) do
    if d == cur then b:LockHighlight() else b:UnlockHighlight() end
  end
  local kind = win.kind or "SAY"
  win.channel:SetText(FF:T("Channel: %s"):format(FF:T(self.CHANNEL_NAMES[kind] or kind)))
  if kind == "WHISPER" then win.target:Show() win.targetLabel:Show() else win.target:Hide() win.targetLabel:Hide() end
  local text = win.input.GetText and win.input:GetText() or ""
  win.preview:SetText(text ~= "" and self:Translate(cur, text) or FF:T("|cff888888Type above - the dialect version shows here.|r"))
end

local function build()
  local f = FF:Window("FlipForeverTalk", 440, 230, { pos = "talkPos", default = { "CENTER", 0, 140 } })
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText(FF:T("Speak in dialect"))
  f.dialectButtons = {}
  local prev
  for _, d in ipairs(D.ORDER) do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(78, 22)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 14, -40) end
    b:SetText(FF:T(D.NAMES[d]))
    b:SetScript("OnClick", function() D:SetCurrent(d) D:Refresh() end)
    f.dialectButtons[d] = b
    prev = b
  end
  local input = CreateFrame("EditBox", "FlipForeverTalkInput", f, "InputBoxTemplate")
  input:SetSize(404, 22)
  input:SetPoint("TOPLEFT", 20, -74)
  input:SetAutoFocus(false)
  input:SetMaxLetters(500)
  input:SetScript("OnTextChanged", function() D:Refresh() end)
  input:SetScript("OnEnterPressed", function(self) D:SendFromWindow() end)
  input:SetScript("OnEscapePressed", function(self) self:ClearFocus() f:Hide() end)
  f.input = input
  local preview = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  preview:SetPoint("TOPLEFT", 16, -104)
  preview:SetWidth(408)
  preview:SetJustifyH("LEFT")
  if preview.SetWordWrap then preview:SetWordWrap(true) end
  f.preview = preview
  local channel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  channel:SetSize(130, 22)
  channel:SetPoint("BOTTOMLEFT", 14, 14)
  channel:SetScript("OnClick", function()
    local i = 1
    for n, k in ipairs(D.CHANNELS) do if k == f.kind then i = n end end
    f.kind = D.CHANNELS[i % #D.CHANNELS + 1]
    FlipForeverDB.settings.talkChannel = f.kind
    D:Refresh()
  end)
  f.channel = channel
  local targetLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  targetLabel:SetPoint("BOTTOMLEFT", 14, 44)
  targetLabel:SetText(FF:T("To:"))
  f.targetLabel = targetLabel
  local target = CreateFrame("EditBox", "FlipForeverTalkTarget", f, "InputBoxTemplate")
  target:SetSize(140, 20)
  target:SetPoint("LEFT", targetLabel, "RIGHT", 10, 0)
  target:SetAutoFocus(false)
  target:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  f.target = target
  local send = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  send:SetSize(90, 22)
  send:SetPoint("BOTTOMRIGHT", -14, 14)
  send:SetText(FF:T("Send"))
  send:SetScript("OnClick", function() D:SendFromWindow() end)
  local put = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  put:SetSize(130, 22)
  put:SetPoint("RIGHT", send, "LEFT", -6, 0)
  put:SetText(FF:T("Put in chat box"))
  put:SetScript("OnClick", function()
    local text = input:GetText() or ""
    if text ~= "" and ChatFrame_OpenChat then ChatFrame_OpenChat(D:Translate(D:Current(), text)) end
  end)
  f.kind = FlipForeverDB.settings.talkChannel or "SAY"
  return f
end

function D:SendFromWindow()
  if not win then return 0 end
  local text = win.input:GetText() or ""
  local target = win.kind == "WHISPER" and (win.target:GetText() or "") or nil
  local n = self:Send(self:Current(), text, win.kind, target)
  if n > 0 then win.input:SetText("") win.input:ClearFocus() end
  self:Refresh()
  return n
end

function D:Open(text)
  if not self:Enabled() then
    FF:Print(FF:T("Speak in dialect is off (FlipForever settings, Features)."))
    return
  end
  win = win or build()
  win:Show()
  if text and text ~= "" then win.input:SetText(text) end
  if win.input.SetFocus then win.input:SetFocus() end
  self:Refresh()
  return win
end

function D:Toggle()
  if win and win:IsShown() then win:Hide() else self:Open() end
end

-- Chat button (switch dialectChatButton): a small speech-bubble button at the top right of the main
-- chat window that opens the dialect window; shown only while both switches are on.
local chatButton

function D:ChatButtonOn()
  return self:Enabled() and FlipForeverDB.settings.dialectChatButton ~= false
end

function D:UpdateChatButton()
  local parent = _G.ChatFrame1
  if not self:ChatButtonOn() then
    if chatButton then chatButton:Hide() end
    return chatButton
  end
  if not parent then return nil end
  if not chatButton then
    chatButton = CreateFrame("Button", "FlipForeverDialectButton", parent)
    chatButton:SetSize(22, 22)
    chatButton:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, 6)
    chatButton:SetFrameStrata("MEDIUM")
    chatButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
    chatButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Down")
    chatButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    chatButton:SetScript("OnClick", function() D:Toggle() end)
    chatButton:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(FF:T("Speak in dialect"))
      GameTooltip:AddLine(FF:T("Click to write in a troll, orc, dwarf, goblin or pirate dialect."), 1, 1, 1, true)
      GameTooltip:AddLine(FF:T("Hide this button: FlipForever settings, Features."), 0.6, 0.6, 0.6, true)
      GameTooltip:Show()
    end)
    chatButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  chatButton:Show()
  return chatButton
end

FF:On("PLAYER_LOGIN", function() pcall(D.UpdateChatButton, D) end)

-- /ff talk [dialect] [text]: window (or send right away with text); /fft <text>: send in your dialect
function D:Command(rest)
  local first, more = (rest or ""):match("^(%S*)%s*(.-)%s*$")
  local d = self.WORDS[(first or ""):lower()] and first:lower()
  if d then self:SetCurrent(d) else more = rest or "" end
  if more == "" then return self:Open() end
  local kind, target = self:ChatTarget()
  return self:Send(self:Current(), more, kind, target)
end

local baseSlash = SlashCmdList.FLIPFOREVER
SlashCmdList.FLIPFOREVER = function(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
  if (cmd or ""):lower() == "talk" and D:Enabled() then
    FF.inSlash = true
    local ok, err = pcall(D.Command, D, rest)
    FF.inSlash = false
    if not ok then error(err, 0) end
    return
  end
  return baseSlash(msg)
end

SLASH_FLIPFOREVERTALK1 = "/fft"
SlashCmdList.FLIPFOREVERTALK = function(msg)
  if not D:Enabled() then return D:Open() end
  if (msg or ""):find("%S") then
    local kind, target = D:ChatTarget()
    return D:Send(D:Current(), msg, kind, target)
  end
  return D:Toggle()
end

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

function D:Enabled() return FlipForeverDB ~= nil and FlipForeverDB.settings.chatDialect ~= false end

-- ASCII-only case changes: string.lower/upper may follow the system locale and break UTF-8 letters
local function lower(s) return (s:gsub("[A-Z]", function(c) return string.char(c:byte() + 32) end)) end
local function upper(s) return (s:gsub("[a-z]", function(c) return string.char(c:byte() - 32) end)) end
D.lower = lower

local function caseless(phrase)
  return (phrase:gsub("[A-Za-z]", function(c) return "[" .. lower(c) .. upper(c) .. "]" end))
end

local function matchCase(src, word)
  if src:find("[A-Z].*[A-Z]") and not src:find("[a-z]") then return upper(word) end
  if src:sub(1, 1):find("^[A-Z]") then return upper(word:sub(1, 1)) .. word:sub(2) end
  return word
end

-- Autocorrect (switch dialectAutocorrect): common typos and chat shorthand in the language you type
-- are fixed first, so the dialect words match and the message reads well.
D.TYPOS = {
  en = { teh = "the", hte = "the", adn = "and", taht = "that", waht = "what", jsut = "just", knwo = "know",
    yuo = "you", wich = "which", thier = "their", becuase = "because", beacuse = "because", recieve = "receive",
    definately = "definitely", wierd = "weird", alot = "a lot", untill = "until", seperate = "separate",
    occured = "occurred", tommorow = "tomorrow", tomorow = "tomorrow", freind = "friend", beleive = "believe",
    dont = "don't", cant = "can't", wont = "won't", didnt = "didn't", doesnt = "doesn't", isnt = "isn't",
    wasnt = "wasn't", arent = "aren't", couldnt = "couldn't", shouldnt = "shouldn't", wouldnt = "wouldn't",
    havent = "haven't", im = "I'm", ive = "I've", youre = "you're", theyre = "they're", thats = "that's",
    whats = "what's", i = "I", u = "you", ur = "your", r = "are", pls = "please", plz = "please",
    thx = "thanks", ty = "thank you", np = "no problem", idk = "I don't know", btw = "by the way" },
  de = { nciht = "nicht", nich = "nicht", dsa = "das", udn = "und", ihc = "ich", vieleicht = "vielleicht",
    garnicht = "gar nicht", wiso = "wieso", warscheinlich = "wahrscheinlich", ["nähmlich"] = "nämlich",
    ["bitteschön"] = "bitte schön", thx = "danke",
    pls = "bitte", plz = "bitte", vllt = "vielleicht", evtl = "eventuell", iwie = "irgendwie", ka = "keine Ahnung" },
  fr = { ca = "ça", tres = "très", deja = "déjà", voila = "voilà", apres = "après", meme = "même",
    etre = "être", pk = "pourquoi", pq = "pourquoi", stp = "s'il te plaît", svp = "s'il vous plaît",
    mdr = "haha", jsp = "je sais pas", bcp = "beaucoup", tjrs = "toujours", qd = "quand" },
  es = { q = "que", xq = "porque", pq = "porque", tmb = "también", tb = "también", aki = "aquí", aqui = "aquí",
    tambien = "también", despues = "después", asi = "así", ahi = "ahí", pls = "por favor",
    porfa = "por favor", grax = "gracias", xfa = "por favor" },
  it = { xke = "perché", ["xché"] = "perché", perche = "perché", cmq = "comunque", nn = "non", ke = "che",
    pk = "perché", qlc = "qualcosa", tt = "tutto", sn = "sono", gia = "già", piu = "più", pero = "però" },
  pt = { vc = "você", voce = "você", tb = "também", tbm = "também", nao = "não", entao = "então", q = "que",
    pq = "porque", obg = "obrigado", vlw = "valeu", blz = "beleza", tmj = "tamo junto", ja = "já" },
}

function D:AutocorrectOn() return FlipForeverDB ~= nil and FlipForeverDB.settings.dialectAutocorrect ~= false end

function D:Correct(text, lang)
  local typos = self.TYPOS[lang or self:Lang()] or self.TYPOS.en
  local fixed = 0
  local s = (text or ""):gsub("[%a\128-\255']+", function(w)
    local to = typos[lower(w)]
    if to and to ~= w then
      local out = matchCase(w, to)
      if out ~= w then fixed = fixed + 1 return out end
    end
    return w
  end)
  return s, fixed
end

-- Languages (DialectLang.lua adds the others): the one picked in the window, else the game's language.
-- Without word lists for a language (Russian, Korean, Chinese) the English lists are used.
D.LANGS = { "en" }
D.LANG_NAMES = { en = "English" }
D.LANG = {}
D.LOCALES = { deDE = "de", frFR = "fr", esES = "es", esMX = "es", itIT = "it", ptBR = "pt", ptPT = "pt" }

function D:Lang()
  local pick = FlipForeverDB and FlipForeverDB.settings.dialectLang
  if pick and (pick == "en" or self.LANG[pick]) then return pick end
  local auto = self.LOCALES[(GetLocale and GetLocale()) or ""]
  return (auto and self.LANG[auto]) and auto or "en"
end

-- "auto" (nil) follows the game's language
function D:SetLang(lang)
  FlipForeverDB.settings.dialectLang = (lang ~= nil and lang ~= "auto") and lang or nil
end

function D:Tables(lang)
  local L = lang and lang ~= "en" and self.LANG[lang]
  if L then return L.WORDS, L.PHRASES or {}, L.WRAP or {} end
  return self.WORDS, self.PHRASES, self.WRAP
end

-- The dialect text; item links, spell links and colour codes are kept as they are.
function D:Translate(dialect, text, lang)
  local allWords, phrases, wraps = self:Tables(lang or self:Lang())
  local words = allWords[dialect]
  text = text or ""
  if not words or text == "" then return text end
  local kept = {}
  local s = text:gsub("|c%x+|H.-|h.-|h|r", function(link) kept[#kept + 1] = link return "\1" .. #kept .. "\2" end)
  s = s:gsub("|H.-|h.-|h", function(link) kept[#kept + 1] = link return "\1" .. #kept .. "\2" end)
  s = s:gsub("{.-}", function(mark) kept[#kept + 1] = mark return "\1" .. #kept .. "\2" end)
  if self:AutocorrectOn() then s = self:Correct(s, lang or self:Lang()) end
  local changed = false
  for _, p in ipairs(phrases[dialect] or {}) do
    s = s:gsub("%f[%a]" .. caseless(p[1]) .. "%f[%A]", function(found)
      changed = true
      local to = p[2]:gsub("%%", "%%%%")
      return matchCase(found, to)
    end)
  end
  -- words: letters, apostrophes and UTF-8 letters (ä, é, ñ...)
  s = s:gsub("[%a\128-\255']+", function(w)
    local to = words[lower(w)]
    if to and lower(to) ~= lower(w) then changed = true return matchCase(w, to) end
    return w
  end)
  local wrap = wraps[dialect]
  if wrap and s:find("%a") and not lower(s):find(wrap[3]) then
    if wrap[1] then
      local lead = s:match("^%s*\1") and "" or lower(s:sub(1, 1))
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
  local langName = self.LANG_NAMES[self:Lang()] or "English"
  win.lang:SetText(FlipForeverDB.settings.dialectLang and FF:T("Language: %s"):format(langName)
    or FF:T("Language: Auto (%s)"):format(langName))
  win.autocorrect:SetText(self:AutocorrectOn() and FF:T("Autocorrect: On") or FF:T("Autocorrect: Off"))
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
  -- language of what you type: Auto (the game's language), English, Deutsch, Français, Español...
  local lang = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  lang:SetSize(140, 22)
  lang:SetPoint("TOPRIGHT", -30, -10)
  lang:SetScript("OnClick", function()
    local order = { "auto" }
    for _, code in ipairs(D.LANGS) do order[#order + 1] = code end
    local cur = FlipForeverDB.settings.dialectLang or "auto"
    local i = 1
    for n, code in ipairs(order) do if code == cur then i = n end end
    D:SetLang(order[i % #order + 1])
    D:Refresh()
  end)
  f.lang = lang
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
  -- autocorrect on/off (the same setting as the switch in Settings, Features)
  local fix = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  fix:SetSize(130, 22)
  fix:SetPoint("BOTTOMRIGHT", -14, 40)
  fix:SetScript("OnClick", function()
    FlipForeverDB.settings.dialectAutocorrect = not D:AutocorrectOn()
    D:Refresh()
  end)
  f.autocorrect = fix
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

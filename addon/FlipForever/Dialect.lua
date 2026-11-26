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

-- More voices (switch dialectVoices): Forsaken, Tauren, Night Elf, Draenei
D.EXTRA = { "forsaken", "tauren", "nightelf", "draenei" }
D.NAMES.forsaken, D.NAMES.tauren, D.NAMES.nightelf, D.NAMES.draenei = "Forsaken", "Tauren", "Night Elf", "Draenei"
D.RACE.Scourge, D.RACE.Undead, D.RACE.Tauren, D.RACE.HighmountainTauren = "forsaken", "forsaken", "tauren", "tauren"
D.RACE.NightElf, D.RACE.Nightborne, D.RACE.Draenei, D.RACE.LightforgedDraenei = "nightelf", "nightelf", "draenei", "draenei"
D.IS_EXTRA = { forsaken = true, tauren = true, nightelf = true, draenei = true }
D.WORDS.forsaken = {
  hello = "Greetings, mortal", hi = "Hail", friend = "fellow Forsaken", friends = "fellow Forsaken",
  life = "unlife", alive = "undying", dead = "truly dead", die = "rot", food = "flesh", eat = "feast on",
  good = "delightfully grim", great = "exquisitely grim", happy = "less miserable", love = "tolerate",
  yes = "Indeed", no = "Never", thanks = "My gratitude, such as it is", goodbye = "Victory for Sylvanas",
  bye = "The Dark Lady watches", hope = "despair", warm = "cold", sun = "cursed sun", human = "living one",
  humans = "the living", wait = "be patient, the dead have time",
}
D.WORDS.tauren = {
  hello = "Peace, friend", hi = "Peace", goodbye = "Walk with the Earth Mother", bye = "Earth Mother guide you",
  friend = "brother", friends = "the tribe", yes = "It is so", no = "It is not so",
  thanks = "The Earth Mother thanks you", earth = "Earth Mother", sun = "An'she", moon = "Mu'sha",
  home = "Mulgore", fight = "defend", kill = "hunt", food = "kodo stew", run = "stampede", old = "ancient",
  good = "honorable", great = "noble", angry = "restless", wise = "wise as the elders",
}
D.WORDS.nightelf = {
  hello = "Ishnu-alah", hi = "Ishnu-alah", goodbye = "Elune-adore", bye = "Elune-adore", friend = "dear one",
  yes = "Indeed", no = "I think not", thanks = "Elune be praised", moon = "Elune's light",
  night = "starlit night", forest = "ancient forest", tree = "ancient", magic = "arcane meddling",
  young = "young one", fast = "swift", quiet = "silent as shadow", good = "graceful", great = "blessed",
  hurry = "have patience",
}
D.WORDS.draenei = {
  hello = "Archenon poros", hi = "Good fortune to you", goodbye = "May the Light embrace you",
  bye = "Light be with you", yes = "Of course", no = "I am afraid not", thanks = "Blessings upon you",
  light = "Light of the Naaru", home = "the Exodar", demon = "eredar", demons = "Burning Legion",
  hope = "hope of the Naaru", good = "blessed", great = "radiant", fight = "cleanse", kill = "purge",
  crystal = "sacred crystal", magic = "crystal magic",
}

-- whole phrases, changed before single words
D.PHRASES = {
  forsaken = { { "thank you", "my thanks, such as they are" }, { "good morning", "another grim morning" },
    { "for the horde", "For the Dark Lady" } },
  tauren = { { "thank you", "the Earth Mother thanks you" }, { "for the horde", "For Thunder Bluff and the Horde" } },
  nightelf = { { "thank you", "Elune be praised" }, { "good night", "Elune guide you through the night" } },
  draenei = { { "thank you", "the Light bless you" }, { "oh my god", "by the Naaru" } },
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
function D:VoicesOn() return FlipForeverDB ~= nil and FlipForeverDB.settings.dialectVoices ~= false end
function D:EmoteOn() return FlipForeverDB ~= nil and FlipForeverDB.settings.dialectEmote ~= false end
-- a voice that can be picked now (the four extra ones only with their switch on)
function D:Available(d)
  return d ~= nil and self.WORDS[d] ~= nil and (not self.IS_EXTRA[d] or self:VoicesOn())
end

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

-- RP words: lore names and places, written right (and fixed when misspelled) in every language
local LORE = [[Azeroth Kalimdor Northrend Outland Draenor Pandaria Lordaeron Quel'Thalas Gilneas Zandalar Zandalari
Thrall Jaina Sylvanas Arthas Illidan Garrosh Varian Anduin Vol'jin Baine Cairne Tyrande Malfurion Khadgar Medivh
Gul'dan Ner'zhul Kel'thas Kel'Thuzad Zul'jin Rexxar Saurfang Grommash Magni Velen Sargeras Kil'jaeden Archimonde
Deathwing Ragnaros Onyxia Nefarian Hakkar Elune Naaru A'dal Bwonsamdi Sen'jin Orgrimmar Darnassus Gadgetzan
Ratchet Everlook Shattrath Dalaran Karazhan Zul'Gurub Stratholme Scholomance Gnomeregan Uldaman Maraudon Ahn'Qiraj
Naxxramas Durotar Mulgore Tirisfal Elwynn Westfall Duskwood Stranglethorn Tanaris Feralas Ashenvale Winterspring
Silithus Azshara Darkshore Teldrassil Frostmourne Ashbringer Doomhammer Gorehowl Sulfuras Thunderfury Atiesh
Lok'tar Exodar]]
D.LORE = {}
for name in LORE:gmatch("%S+") do D.LORE[lower(name)] = name end
for wrong, right in pairs({ orgrimar = "Orgrimmar", orgrimmer = "Orgrimmar", silvanas = "Sylvanas",
  sylvannas = "Sylvanas", sylvanes = "Sylvanas", thral = "Thrall", iliden = "Illidan", illadan = "Illidan",
  ilidan = "Illidan", arthus = "Arthas", azaroth = "Azeroth", azerot = "Azeroth", darnasus = "Darnassus",
  voljin = "Vol'jin", guldan = "Gul'dan", nerzhul = "Ner'zhul", kelthas = "Kel'thas", kelthuzad = "Kel'Thuzad",
  zuljin = "Zul'jin", kiljaeden = "Kil'jaeden", ahnqiraj = "Ahn'Qiraj", zulgurub = "Zul'Gurub",
  quelthalas = "Quel'Thalas", senjin = "Sen'jin", naxramas = "Naxxramas", shatrath = "Shattrath",
  gadgetzam = "Gadgetzan", stratholm = "Stratholme", loktar = "Lok'tar", karazan = "Karazhan" }) do
  D.LORE[wrong] = right
end
-- places and factions with their own names per language
D.LORE_LANG = {
  en = { stormwind = "Stormwind", ironforge = "Ironforge", undercity = "Undercity", silvermoon = "Silvermoon",
    stormwnd = "Stormwind", ironforg = "Ironforge", horde = "Horde", alliance = "Alliance" },
  de = { sturmwind = "Sturmwind", eisenschmiede = "Eisenschmiede", unterstadt = "Unterstadt",
    silbermond = "Silbermond", donnerfels = "Donnerfels", beutebucht = "Beutebucht", stormwind = "Sturmwind",
    ironforge = "Eisenschmiede" },
  fr = { hurlevent = "Hurlevent", forgefer = "Forgefer", fossoyeuse = "Fossoyeuse", horde = "Horde",
    alliance = "Alliance" },
  es = { ventormenta = "Ventormenta", forjaz = "Forjaz", ["entrañas"] = "Entrañas", entranas = "Entrañas",
    lunargenta = "Lunargenta", horda = "Horda", alianza = "Alianza" },
  it = { roccavento = "Roccavento", forgiardente = "Forgiardente", orda = "Orda", alleanza = "Alleanza" },
  pt = { ventobravo = "Ventobravo", altaforja = "Altaforja", luaprata = "Luaprata", horda = "Horda",
    ["aliança"] = "Aliança", alianca = "Aliança" },
}
-- names of more than one word (only fixed when typed all in small letters)
D.LORE_PHRASES = {
  en = { "Booty Bay", "Thunder Bluff", "Blackrock Mountain", "Molten Core", "Blackwing Lair", "Kul Tiras",
    "Loch Modan", "Dun Morogh", "Burning Legion", "Scourge" },
  de = { "Brennende Legion", "Geschmolzener Kern", "Pechschwingenhort", "Kul Tiras", "Loch Modan", "Dun Morogh" },
  fr = { "Baie-du-Butin", "Pitons-du-Tonnerre", "Lune-d'Argent", "Cœur du Magma", "Légion ardente", "Kul Tiras" },
  es = { "Bahía del Botín", "Cima del Trueno", "Núcleo de Magma", "Legión Ardiente", "Kul Tiras" },
  it = { "Baia del Bottino", "Picco del Tuono", "Nucleo Ardente", "Legione Infuocata", "Kul Tiras" },
  pt = { "Angra do Butim", "Penhasco do Trovão", "Núcleo Derretido", "Legião Ardente", "Kul Tiras", "Cidade Baixa" },
}

-- German nouns written with a capital letter (common chat and game words; not every noun)
local DE_NOUNS = [[gold silber kupfer gilde gilden gruppe gruppen raid raids instanz instanzen dungeon dungeons
auktionshaus händler händlerin bank post briefkasten tasche taschen rüstung waffe waffen schwert schild stab
bogen ring ringe kette umhang helm handschuhe stiefel gürtel hose brust schultern quest quests aufgabe aufgaben
stufe level erfahrung beruf berufe kräuter erz erze leder stoff stoffe rezept rezepte tränke elixier zauber
fähigkeit fähigkeiten talent talente klasse klassen rasse krieger magier priester jäger schurke druide schamane
hexenmeister paladin heiler tank boss bosse mob mobs gegner feind feinde horde allianz orc orcs troll trolle
zwerg zwerge gnom gnome mensch menschen elfen tauren untote goblin goblins pirat piraten reittier reittiere
flugpunkt hauptstadt stadt dorf gasthaus wirt taverne zone gebiet karte server realm handel preis preise angebot
auktion auktionen gebot gewinn verlust geld münze münzen beute loot item items gegenstand gegenstände freund
freunde freundin leute mann frau kind kinder bruder schwester vater mutter familie name zeit tag tage woche monat
jahr stunde stunden minute minuten sekunde nacht abend mittag antwort hilfe problem probleme idee ideen grund
spaß spieler spielerin glück pech hand hände kopf auge augen herz bier wein wasser met brot fleisch fisch haus
welt land meer berg wald himmel sonne mond feuer eis sturm frieden ehre blut tod mut kraft ruhm sieg niederlage
ziel plan sache dinge ding wort worte sprache moment ahnung lust hunger durst arbeit chef meister lehrer
schamanen ahnen geister geist götter gott loa schicksal legende held helden schlacht]]
D.DE_NOUNS = {}
for w in DE_NOUNS:gmatch("%S+") do D.DE_NOUNS[w] = true end

-- one letter (a-z or a two-byte Latin letter such as ä, é, ñ) as a capital
local function capLetter(ch)
  if ch:find("^[a-z]$") then return upper(ch) end
  local b1, b2 = ch:byte(1, 2)
  if b1 == 195 and b2 and b2 >= 160 and b2 <= 190 and b2 ~= 183 then return string.char(195, b2 - 32) end
  return ch
end

local function capFirst(w)
  local first = w:match("^\195[\128-\191]") or w:sub(1, 1)
  return capLetter(first) .. w:sub(#first + 1)
end

function D:Correct(text, lang)
  lang = lang or self:Lang()
  local typos = self.TYPOS[lang] or self.TYPOS.en
  local lore = self.LORE_LANG[lang] or self.LORE_LANG.en
  local fixed = 0
  local s = text or ""
  for _, name in ipairs(self.LORE_PHRASES[lang] or {}) do
    local pat = caseless((name:gsub("[%-%.%+%*%?%^%$%(%)%[%]%%]", "%%%0")))
    s = s:gsub("%f[%a\128-\255]" .. pat .. "%f[^%a\128-\255]", function(found)
      if found ~= name and not found:find("[A-Z]") then fixed = fixed + 1 return name end
    end)
  end
  s = s:gsub("[%a\128-\255']+", function(w)
    local lw = lower(w)
    local to = typos[lw] or lore[lw] or self.LORE[lw]
    if not to and lang == "de" and self.DE_NOUNS[lw] and w == lw then to = capFirst(w) end
    if to and to ~= w then
      local out = matchCase(w, to)
      if out ~= w then fixed = fixed + 1 return out end
    end
    return w
  end)
  -- a capital letter at the start of each sentence (not after "...")
  local function cap(pre, ch)
    local up = capLetter(ch)
    if up ~= ch then fixed = fixed + 1 end
    return pre .. up
  end
  s = s:gsub("^(%s*)([a-z])", cap):gsub("^(%s*)(\195[\160-\190])", cap)
  s = s:gsub("([^%.][%.!%?]%s+)([a-z])", cap):gsub("([^%.][%.!%?]%s+)(\195[\160-\190])", cap)
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
  -- phrase results are held back so the word pass below doesn't change them again
  local said = {}
  for _, p in ipairs(phrases[dialect] or {}) do
    s = s:gsub("%f[%a]" .. caseless(p[1]) .. "%f[%A]", function(found)
      changed = true
      said[#said + 1] = matchCase(found, p[2])
      return "\3" .. #said .. "\4"
    end)
  end
  -- words: letters, apostrophes and UTF-8 letters (ä, é, ñ...)
  s = s:gsub("[%a\128-\255']+", function(w)
    local to = words[lower(w)]
    if to and lower(to) ~= lower(w) then changed = true return matchCase(w, to) end
    return w
  end)
  s = s:gsub("\3(%d+)\4", function(i) return said[tonumber(i)] end)
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
  if self:Available(d) then return d end
  local _, race = UnitRace and UnitRace("player")
  local byRace = self.RACE[race or ""]
  return self:Available(byRace) and byRace or "troll"
end

function D:SetCurrent(d)
  if not self:Available(d) then return end
  local store = FF.Advisor and FF.Advisor.CharStore and FF.Advisor:CharStore()
  if store then store.dialect = d end
end

D.CHANNELS = { "SAY", "YELL", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "WHISPER" }
D.CHANNEL_NAMES = { SAY = "Say", YELL = "Yell", PARTY = "Party", RAID = "Raid", INSTANCE_CHAT = "Instance",
  GUILD = "Guild", OFFICER = "Officer", WHISPER = "Whisper", EMOTE = "Emote", CHANNEL = "Channel" }

-- channels the window cycles through; Emote (switch dialectEmote) sends roleplay emotes in the dialect
function D:Channels()
  if not self:EmoteOn() then return self.CHANNELS end
  local list = {}
  for _, k in ipairs(self.CHANNELS) do list[#list + 1] = k end
  list[#list + 1] = "EMOTE"
  return list
end

-- The chat line you were typing in (the channel /fft was typed in), else Say.
function D:ChatTarget()
  local eb = (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
    or (ChatEdit_GetLastActiveWindow and ChatEdit_GetLastActiveWindow())
  local kind = eb and eb.GetAttribute and eb:GetAttribute("chatType")
  if kind == "WHISPER" then return kind, eb:GetAttribute("tellTarget") end
  if kind == "CHANNEL" then return kind, eb:GetAttribute("channelTarget") end
  if kind == "EMOTE" and not self:EmoteOn() then return "SAY" end
  if kind and self.CHANNEL_NAMES[kind] then return kind end
  return "SAY"
end

-- Sends the text in the dialect; long text is split at spaces into chat-sized lines.
function D:Send(dialect, text, kind, target)
  local out = self:Translate(dialect, text)
  if not out or not out:find("%S") then return 0 end
  -- an emote follows your character's name ("Alix waves..."): keep its first letter small
  if kind == "EMOTE" and (text or ""):match("^%s*[a-z]") then
    out = out:gsub("^(%s*)([A-Z])", function(sp, c) return sp .. lower(c) end)
  end
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
    if self.IS_EXTRA[d] then if self:VoicesOn() then b:Show() else b:Hide() end end
  end
  if win.kind == "EMOTE" and not self:EmoteOn() then win.kind = "SAY" end
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
  local f = FF:Window("FlipForeverTalk", 440, 256, { pos = "talkPos", default = { "CENTER", 0, 140 } })
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
  -- second row: the extra voices (shown while their switch is on)
  prev = nil
  for _, d in ipairs(D.EXTRA) do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(78, 22)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 14, -64) end
    b:SetText(FF:T(D.NAMES[d]))
    b:SetScript("OnClick", function() D:SetCurrent(d) D:Refresh() end)
    f.dialectButtons[d] = b
    prev = b
  end
  local input = CreateFrame("EditBox", "FlipForeverTalkInput", f, "InputBoxTemplate")
  input:SetSize(404, 22)
  input:SetPoint("TOPLEFT", 20, -98)
  input:SetAutoFocus(false)
  input:SetMaxLetters(500)
  input:SetScript("OnTextChanged", function() D:Refresh() end)
  input:SetScript("OnEnterPressed", function(self) D:SendFromWindow() end)
  input:SetScript("OnEscapePressed", function(self) self:ClearFocus() f:Hide() end)
  f.input = input
  local preview = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  preview:SetPoint("TOPLEFT", 16, -128)
  preview:SetWidth(408)
  preview:SetJustifyH("LEFT")
  if preview.SetWordWrap then preview:SetWordWrap(true) end
  f.preview = preview
  local channel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  channel:SetSize(130, 22)
  channel:SetPoint("BOTTOMLEFT", 14, 14)
  channel:SetScript("OnClick", function()
    local i = 1
    local list = D:Channels()
    for n, k in ipairs(list) do if k == f.kind then i = n end end
    f.kind = list[i % #list + 1]
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
  local name = (first or ""):lower():gsub("[%s_%-]", "")
  if name == "undead" then name = "forsaken" elseif name == "elf" then name = "nightelf" end
  local d = self:Available(name) and name or nil
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

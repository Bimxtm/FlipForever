-- Speak in dialect: word lists for the game's other languages (German, French, Spanish, Italian,
-- Portuguese). Same five voices as in English; written as playful lore flavour, not word-for-word.
-- Keys are lower case; phrases are matched before single words.
local D = FlipForever.Dialect

local function add(code, name, data)
  D.LANG[code] = data
  D.LANG_NAMES[code] = name
  D.LANGS[#D.LANGS + 1] = code
end

add("de", "Deutsch", {
  WORDS = {
    troll = {
      der = "de", die = "de", das = "dat", dies = "dis", diese = "dis", dieser = "dis", ist = "sein", sind = "sein",
      bin = "sein", bist = "sein", freund = "Mon", freunde = "Mons", hallo = "Hey Mon", hi = "Hey", nichts = "nix",
      etwas = "wat", was = "wat", mein = "mei", meine = "mei", dein = "dei", deine = "dei", bruder = "Bruddah",
      magie = "Mojo", ["tschüss"] = "Bleib weg vom Voodoo", danke = "Danke, Mon", klein = "kleen",
    },
    orc = {
      hallo = "Throm-ka", hi = "Throm-ka", ja = "Zug zug", okay = "Dabu", ok = "Dabu", danke = "Aka'magosh",
      ["tschüss"] = "Lok'tar", freund = "Blutsbruder", freunde = "Blutsbrüder", sieg = "Lok'tar ogar",
      schwach = "mickrig", klein = "mickrig", ["kämpfen"] = "zermalmen", ["töten"] = "zerschmettern", feind = "Gegner",
      essen = "Fraß", gut = "stark", toll = "mächtig", dumm = "töricht",
    },
    dwarf = {
      ja = "jo", nein = "nee", ich = "i", nicht = "net", hallo = "Servus", hi = "Servus", freund = "Kumpel",
      freunde = "Kumpels", junge = "Bub", ["mädchen"] = "Madl", ["tschüss"] = "Pfiat di", was = "wos", ist = "is",
      das = "des", haben = "ham", gehen = "geh'n", klein = "kloa", bier = "Maß", trinken = "a Maß zischen",
      sehr = "arg", nichts = "nix", etwas = "a bissl",
    },
    goblin = {
      freund = "Kumpel", freunde = "Kumpels", geld = "Kohle", gold = "Moneten", hallo = "Hey, Kumpel",
      hi = "Hey, Kumpel", billig = "ein Schnäppchen", kaufen = "abstauben", verkaufen = "verscherbeln",
      ["tschüss"] = "Zeit ist Geld, Freund", danke = "War mir ein Vergnügen", ja = "Geht klar", nein = "Kein Deal",
      gut = "erstklassig", schlecht = "mies", bombe = "Kawumm", herr = "Boss", schnell = "zackig",
    },
    pirate = {
      hallo = "Ahoi", hi = "Ahoi", freund = "Maat", freunde = "Maate", ja = "Aye", nein = "Nay", gold = "Dublonen",
      geld = "Beute", schatz = "Schatz", halt = "Avast", stopp = "Avast", ["tschüss"] = "Mast- und Schotbruch",
      junge = "Bursche", ["mädchen"] = "Deern", schau = "Spähe", ist = "is",
    },
  },
  PHRASES = {
    troll = { { "danke schön", "Danke, Mon" }, { "ich bin", "ich sein" }, { "du bist", "du sein" } },
    orc = { { "danke schön", "Aka'magosh" }, { "für die horde", "Für die Horde" } },
    dwarf = { { "danke schön", "Vergelt's Gott" }, { "ein bisschen", "a bissl" }, { "auf wiedersehen", "Pfiat di" } },
    goblin = { { "danke schön", "War mir ein Vergnügen" }, { "wie viel", "was kost' mich das" } },
    pirate = { { "danke schön", "Dank dir, Maat" }, { "oh mein gott", "Klabautermann noch eins" } },
  },
  WRAP = {
    troll = { nil, ", Mon", "%f[%a]mon%f[%A]" },
    pirate = { "Arr, ", nil, "^%W*arr" },
  },
})

add("fr", "Français", {
  WORDS = {
    troll = {
      ami = "man", amis = "mans", salut = "Salut, man", bonjour = "Salut, man", merci = "Merci, man",
      est = "être", suis = "être", es = "être", sont = "être", rien = "nada", ["frère"] = "frangin", magie = "mojo",
      petit = "p'tit", ceci = "ça", cela = "ça",
    },
    orc = {
      bonjour = "Throm-ka", salut = "Throm-ka", oui = "Zug zug", ok = "Dabu", merci = "Aka'magosh",
      ami = "frère de sang", amis = "frères de sang", victoire = "Lok'tar ogar", faible = "chétif",
      petit = "chétif", combattre = "écraser", tuer = "broyer", ennemi = "adversaire", nourriture = "bouffe",
      bon = "fort", super = "puissant", idiot = "insensé",
    },
    dwarf = {
      oui = "ouais", bonjour = "Bien le bonjour", salut = "Bien le bonjour", ami = "mon gars", amis = "les gars",
      ["bière"] = "chope", boire = "s'jeter une chope", petit = "p'tit", ["garçon"] = "gamin", fille = "gamine",
      rien = "que dalle", vieux = "vieux bougre", ["très"] = "sacrément",
    },
    goblin = {
      ami = "mon pote", amis = "les potes", argent = "blé", ["or"] = "pognon", bonjour = "Salut, mon pote",
      salut = "Salut, mon pote", acheter = "rafler", vendre = "refourguer", merci = "Un plaisir de faire affaire",
      oui = "Marché conclu", non = "Pas d'affaire", bon = "de premier choix", mauvais = "minable", bombe = "badaboum",
      monsieur = "patron", vite = "fissa",
    },
    pirate = {
      bonjour = "Ohé", salut = "Ohé", ami = "moussaillon", amis = "moussaillons", oui = "Aye", non = "Nenni",
      ["or"] = "doublons", argent = "butin", ["trésor"] = "magot", stop = "Avast", ["garçon"] = "mousse", fille = "donzelle",
    },
  },
  PHRASES = {
    troll = { { "je suis", "moi être" }, { "tu es", "toi être" } },
    orc = { { "au revoir", "Lok'tar" }, { "d'accord", "Dabu" }, { "pour la horde", "Pour la Horde" } },
    dwarf = { { "au revoir", "Prends soin d'ta barbe" }, { "un peu", "un p'tit brin" } },
    goblin = { { "au revoir", "Le temps, c'est de l'argent, l'ami" }, { "pas cher", "une affaire" },
      { "combien", "ça va m'coûter combien" } },
    pirate = { { "au revoir", "Bon vent" }, { "mon dieu", "mille sabords" } },
  },
  WRAP = {
    troll = { nil, ", man", "%f[%a]man%f[%A]" },
    pirate = { "Arr, ", nil, "^%W*arr" },
  },
})

add("es", "Español", {
  WORDS = {
    troll = {
      amigo = "mon", amigos = "mons", hola = "Ey, mon", gracias = "Gracias, mon", es = "ser", soy = "ser",
      eres = "ser", son = "ser", nada = "na'", hermano = "bróder", magia = "mojo", ["pequeño"] = "chiquito",
      esto = "esto, mon", para = "pa'",
    },
    orc = {
      hola = "Throm-ka", ["sí"] = "Zug zug", si = "Zug zug", vale = "Dabu", ok = "Dabu", gracias = "Aka'magosh",
      ["adiós"] = "Lok'tar", adios = "Lok'tar", amigo = "hermano de sangre", amigos = "hermanos de sangre",
      victoria = "Lok'tar ogar", ["débil"] = "enclenque", luchar = "aplastar", matar = "machacar",
      enemigo = "adversario", comida = "rancho", bueno = "fuerte", genial = "poderoso", tonto = "necio",
    },
    dwarf = {
      ["sí"] = "sip", si = "sip", hola = "Bien hallado", amigo = "muchacho", amigos = "muchachos",
      cerveza = "jarra", beber = "echar un trago", ["pequeño"] = "chiquitín", chico = "chaval", chica = "moza",
      ["adiós"] = "Cuida tu barba", adios = "Cuida tu barba", nada = "na'", viejo = "vejestorio", muy = "bien",
    },
    goblin = {
      amigo = "colega", amigos = "colegas", dinero = "pasta", oro = "guita", hola = "¿Qué hay, colega?",
      barato = "una ganga", comprar = "pillar", vender = "colocar", ["adiós"] = "El tiempo es oro, amigo",
      adios = "El tiempo es oro, amigo", gracias = "Un placer hacer negocios", ["sí"] = "Trato hecho",
      si = "Trato hecho", no = "Sin trato", bueno = "de primera", malo = "cutre", bomba = "kabum",
      ["señor"] = "jefe", ["rápido"] = "volando",
    },
    pirate = {
      hola = "Ahoy", amigo = "grumete", amigos = "grumetes", ["sí"] = "Aye", si = "Aye", oro = "doblones",
      dinero = "botín", tesoro = "tesoro", alto = "Avast", ["adiós"] = "Buenos vientos", adios = "Buenos vientos",
      chico = "mozo", chica = "moza",
    },
  },
  PHRASES = {
    troll = { { "yo soy", "yo ser" }, { "tú eres", "tú ser" } },
    orc = { { "por la horda", "Por la Horda" } },
    dwarf = { { "un poco", "un pelín" } },
    goblin = { { "cuánto cuesta", "cuánto me va a costar" } },
    pirate = { { "dios mío", "rayos y centellas" } },
  },
  WRAP = {
    troll = { nil, ", mon", "%f[%a]mon%f[%A]" },
    pirate = { "¡Arr! ", nil, "arr" },
  },
})

add("it", "Italiano", {
  WORDS = {
    troll = {
      amico = "mon", amici = "mons", ciao = "Ehi, mon", grazie = "Grazie, mon", sono = "essere", sei = "essere",
      ["è"] = "essere", niente = "nada", fratello = "fratè", magia = "mojo", piccolo = "piccoletto",
    },
    orc = {
      ciao = "Throm-ka", salve = "Throm-ka", ["sì"] = "Zug zug", si = "Zug zug", ok = "Dabu", grazie = "Aka'magosh",
      arrivederci = "Lok'tar", amico = "fratello di sangue", amici = "fratelli di sangue", vittoria = "Lok'tar ogar",
      debole = "gracile", combattere = "schiacciare", uccidere = "frantumare", nemico = "avversario",
      cibo = "sbobba", buono = "forte", stupido = "stolto",
    },
    dwarf = {
      ["sì"] = "già", si = "già", ciao = "Ben trovato", salve = "Ben trovato", amico = "ragazzo mio",
      amici = "ragazzi", birra = "boccale", bere = "farsi un boccale", piccolo = "piccoletto",
      arrivederci = "Cura la tua barba", niente = "un bel niente", molto = "parecchio",
    },
    goblin = {
      amico = "socio", amici = "soci", soldi = "grana", oro = "quattrini", ciao = "Ehi, socio",
      economico = "un affare", comprare = "arraffare", vendere = "piazzare", arrivederci = "Il tempo è denaro, amico",
      grazie = "Un piacere fare affari", ["sì"] = "Affare fatto", si = "Affare fatto", no = "Niente affare",
      buono = "di prima scelta", cattivo = "scadente", bomba = "kabum", signore = "capo", veloce = "in un lampo",
    },
    pirate = {
      ciao = "Ahoy", amico = "mozzo", amici = "mozzi", ["sì"] = "Aye", si = "Aye", oro = "dobloni",
      soldi = "bottino", tesoro = "tesoro", arrivederci = "Buon vento", ragazzo = "mozzo",
    },
  },
  PHRASES = {
    troll = { { "io sono", "io essere" } },
    orc = { { "va bene", "Dabu" }, { "per l'orda", "Per l'Orda" } },
    dwarf = { { "un po'", "un goccio" } },
    goblin = { { "quanto costa", "quanto mi costerà" } },
    pirate = { { "mio dio", "per mille balene" } },
  },
  WRAP = {
    troll = { nil, ", mon", "%f[%a]mon%f[%A]" },
    pirate = { "Arr, ", nil, "^%W*arr" },
  },
})

add("pt", "Português", {
  WORDS = {
    troll = {
      amigo = "mon", amigos = "mons", ["olá"] = "E aí, mon", oi = "E aí, mon", obrigado = "Valeu, mon",
      obrigada = "Valeu, mon", sou = "ser", ["é"] = "ser", ["és"] = "ser", nada = "nadinha", ["irmão"] = "irmão, mon",
      magia = "mojo", pequeno = "pequenino",
    },
    orc = {
      ["olá"] = "Throm-ka", oi = "Throm-ka", sim = "Zug zug", ok = "Dabu", beleza = "Dabu", obrigado = "Aka'magosh",
      obrigada = "Aka'magosh", tchau = "Lok'tar", amigo = "irmão de sangue", amigos = "irmãos de sangue",
      ["vitória"] = "Lok'tar ogar", fraco = "mirrado", lutar = "esmagar", matar = "triturar",
      inimigo = "adversário", comida = "rango", bom = "forte", burro = "tolo",
    },
    dwarf = {
      sim = "pois é", ["olá"] = "Bem-vindo, rapaz", oi = "Bem-vindo, rapaz", amigo = "rapaz", amigos = "rapazes",
      cerveja = "caneca", beber = "virar uma caneca", pequeno = "pequenino", tchau = "Cuide da sua barba",
      nada = "coisa nenhuma", muito = "um bocado",
    },
    goblin = {
      amigo = "parceiro", amigos = "parceiros", dinheiro = "grana", ouro = "bufunfa", ["olá"] = "E aí, parceiro",
      oi = "E aí, parceiro", barato = "uma pechincha", comprar = "faturar", vender = "passar adiante",
      tchau = "Tempo é dinheiro, amigo", obrigado = "Um prazer fazer negócios", obrigada = "Um prazer fazer negócios",
      sim = "Fechado", ["não"] = "Sem acordo", bom = "de primeira", ruim = "vagabundo", bomba = "kabum",
      senhor = "chefe", ["rápido"] = "num piscar",
    },
    pirate = {
      ["olá"] = "Ahoy", oi = "Ahoy", amigo = "marujo", amigos = "marujos", sim = "Aye", ouro = "dobrões",
      dinheiro = "pilhagem", tesouro = "tesouro", tchau = "Bons ventos", garoto = "grumete",
    },
  },
  PHRASES = {
    troll = { { "eu sou", "eu ser" } },
    orc = { { "pela horda", "Pela Horda" } },
    dwarf = { { "um pouco", "um tiquinho" } },
    goblin = { { "quanto custa", "quanto vai me custar" } },
    pirate = { { "meu deus", "raios e trovões" } },
  },
  WRAP = {
    troll = { nil, ", mon", "%f[%a]mon%f[%A]" },
    pirate = { "Arr, ", nil, "^%W*arr" },
  },
})

-- The extra voices (switch dialectVoices): Forsaken, Tauren, Night Elf, Skyborne in every language
local EXTRA = {
  de = {
    skyborne = { hallo = "Gute Winde", hi = "Gute Winde", ["tschüss"] = "Mögen die Winde dich tragen",
      freund = "Windgeschwister", freunde = "Windsippe", ja = "Wie der Wind es will", nein = "Der Wind sagt nein",
      danke = "Die Winde danken dir", schnell = "schnell wie der Sturm", himmel = "weiter Himmel",
      wind = "die Geister der Luft", sturm = "Al'Akirs Zorn", gut = "windgesegnet", toll = "himmelhoch" },
    forsaken = { hallo = "Sei gegrüßt, Sterblicher", hi = "Sei gegrüßt", freund = "Mitverlassener",
      leben = "Unleben", tot = "wahrhaft tot", gut = "herrlich düster", danke = "Mein Dank, so viel er wert ist",
      ja = "Gewiss", nein = "Niemals", ["tschüss"] = "Sieg für Sylvanas", hoffnung = "Verzweiflung", warm = "kalt" },
    tauren = { hallo = "Friede, Freund", hi = "Friede", ["tschüss"] = "Wandle mit der Erdmutter", freund = "Bruder",
      ja = "So sei es", nein = "Dem ist nicht so", danke = "Die Erdmutter dankt dir", erde = "Erdmutter",
      sonne = "An'she", mond = "Mu'sha", gut = "ehrenhaft", alt = "uralt" },
    nightelf = { hallo = "Ishnu-alah", hi = "Ishnu-alah", ["tschüss"] = "Elune-adore", freund = "Gefährte",
      ja = "Gewiss", nein = "Wohl kaum", danke = "Elune sei gepriesen", mond = "Elunes Licht",
      nacht = "Sternennacht", wald = "uralter Wald", schnell = "flink", gut = "anmutig" },
  },
  fr = {
    skyborne = { bonjour = "Bons vents", salut = "Bons vents", adieu = "Que les vents te portent",
      ami = "frère des vents", oui = "Comme le vent le veut", non = "Le vent dit non",
      merci = "Les vents te remercient", rapide = "vif comme la bourrasque", ciel = "ciel sans fin",
      vent = "les esprits de l'air", ["tempête"] = "fureur d'Al'Akir", bon = "béni des vents" },
    forsaken = { bonjour = "Salutations, mortel", salut = "Salutations", ami = "compagnon réprouvé",
      vie = "non-vie", mort = "vraiment mort", bon = "délicieusement sinistre",
      merci = "Ma gratitude, pour ce qu'elle vaut", oui = "Certes", non = "Jamais",
      adieu = "Victoire pour Sylvanas", espoir = "désespoir", chaud = "froid" },
    tauren = { bonjour = "Paix, ami", salut = "Paix", adieu = "Marche avec la Terre-Mère", ami = "frère",
      oui = "Ainsi soit-il", non = "Il n'en est rien", merci = "La Terre-Mère te remercie", terre = "Terre-Mère",
      soleil = "An'she", lune = "Mu'sha", bon = "honorable" },
    nightelf = { bonjour = "Ishnu-alah", salut = "Ishnu-alah", adieu = "Elune-adore", ami = "compagnon",
      oui = "Certes", non = "Je ne crois pas", merci = "Loué soit Élune", lune = "lumière d'Élune",
      nuit = "nuit étoilée", ["forêt"] = "forêt ancestrale", rapide = "vif", bon = "gracieux" },
  },
  es = {
    skyborne = { hola = "Buenos vientos", ["adiós"] = "Que los vientos te lleven", adios = "Que los vientos te lleven",
      amigo = "hermano del viento", ["sí"] = "Como el viento quiera", no = "El viento dice que no",
      gracias = "Los vientos te lo agradecen", ["rápido"] = "veloz como el vendaval", rapido = "veloz como el vendaval",
      cielo = "cielo infinito", viento = "los espíritus del aire", tormenta = "furia de Al'Akir",
      bueno = "bendecido por el viento" },
    forsaken = { hola = "Saludos, mortal", amigo = "compañero renegado", vida = "no-vida",
      muerto = "muerto de verdad", bueno = "deliciosamente lúgubre", gracias = "Mi gratitud, lo que valga",
      ["sí"] = "Ciertamente", no = "Jamás", ["adiós"] = "Victoria para Sylvanas", adios = "Victoria para Sylvanas",
      esperanza = "desesperación", caliente = "frío" },
    tauren = { hola = "Paz, amigo", ["adiós"] = "Camina con la Madre Tierra", adios = "Camina con la Madre Tierra",
      amigo = "hermano", ["sí"] = "Así es", no = "No es así", gracias = "La Madre Tierra te lo agradece",
      tierra = "Madre Tierra", sol = "An'she", luna = "Mu'sha", bueno = "honorable" },
    nightelf = { hola = "Ishnu-alah", ["adiós"] = "Elune-adore", adios = "Elune-adore", amigo = "compañero",
      ["sí"] = "Desde luego", no = "Creo que no", gracias = "Alabada sea Elune", luna = "luz de Elune",
      noche = "noche estrellada", bosque = "bosque ancestral", bueno = "grácil" },
  },
  it = {
    skyborne = { ciao = "Buoni venti", arrivederci = "Che i venti ti portino", amico = "fratello del vento",
      ["sì"] = "Come vuole il vento", no = "Il vento dice di no", grazie = "I venti ti ringraziano",
      veloce = "rapido come la burrasca", cielo = "cielo infinito", vento = "gli spiriti dell'aria",
      tempesta = "furia di Al'Akir", buono = "benedetto dal vento" },
    forsaken = { ciao = "Salute, mortale", amico = "compagno reietto", vita = "non-vita", morto = "morto davvero",
      buono = "deliziosamente cupo", grazie = "La mia gratitudine, per quel che vale", ["sì"] = "Certo",
      no = "Mai", arrivederci = "Vittoria per Sylvanas", speranza = "disperazione", caldo = "freddo" },
    tauren = { ciao = "Pace, amico", arrivederci = "Cammina con la Madre Terra", amico = "fratello",
      ["sì"] = "Così sia", no = "Non è così", grazie = "La Madre Terra ti ringrazia", terra = "Madre Terra",
      sole = "An'she", luna = "Mu'sha", buono = "onorevole" },
    nightelf = { ciao = "Ishnu-alah", arrivederci = "Elune-adore", amico = "compagno", ["sì"] = "Certamente",
      no = "Non credo", grazie = "Sia lodata Elune", luna = "luce di Elune", notte = "notte stellata",
      foresta = "foresta antica", buono = "aggraziato" },
  },
  pt = {
    skyborne = { ["olá"] = "Bons ventos", oi = "Bons ventos", tchau = "Que os ventos o levem",
      amigo = "irmão do vento", sim = "Como o vento quiser", ["não"] = "O vento diz que não",
      obrigado = "Os ventos agradecem", ["rápido"] = "veloz como a ventania", rapido = "veloz como a ventania",
      ["céu"] = "céu sem fim", vento = "os espíritos do ar", tempestade = "fúria de Al'Akir",
      bom = "abençoado pelo vento" },
    forsaken = { ["olá"] = "Saudações, mortal", oi = "Saudações", amigo = "companheiro renegado",
      vida = "morte-vida", morto = "morto de verdade", bom = "deliciosamente sombrio",
      obrigado = "Minha gratidão, pelo que vale", sim = "Certamente", ["não"] = "Jamais",
      tchau = "Vitória para Sylvanas", ["esperança"] = "desespero", quente = "frio" },
    tauren = { ["olá"] = "Paz, amigo", oi = "Paz", tchau = "Caminhe com a Mãe Terra", amigo = "irmão",
      sim = "Assim é", ["não"] = "Não é assim", obrigado = "A Mãe Terra agradece", terra = "Mãe Terra",
      sol = "An'she", lua = "Mu'sha", bom = "honrado" },
    nightelf = { ["olá"] = "Ishnu-alah", oi = "Ishnu-alah", tchau = "Elune-adore", amigo = "companheiro",
      sim = "Certamente", ["não"] = "Creio que não", obrigado = "Louvada seja Eluna", lua = "luz de Eluna",
      noite = "noite estrelada", floresta = "floresta ancestral", bom = "gracioso" },
  },
}
for code, voices in pairs(EXTRA) do
  local L = D.LANG[code]
  if L then
    for d, words in pairs(voices) do L.WORDS[d] = words end
  end
end

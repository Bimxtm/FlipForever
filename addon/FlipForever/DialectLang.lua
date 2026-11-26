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

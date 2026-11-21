"""The How to use page in every language, section by section (same order as gui.HELP).

Each entry starts with the first words of the English text it translates; when the English
section changes, that check fails and the page shows English until it is translated again.
Order: deDE, frFR, esES, esMX, itIT, ptBR, ruRU, koKR, zhCN, zhTW.
"""

_ES_LOOP = ("1. Ajustes -> Instalar / actualizar el addon.\n"
            "2. En el juego: abre la casa de subastas y pulsa 'Escaneo completo' en el panel de FlipForever (se puede una vez cada 15 min).\n"
            "3. Al terminar el escaneo, el addon rehace tu lista de compras en el juego, sin recargar.\n"
            "4. De vez en cuando pulsa Recargar en el juego: la app importa tus escaneos y operaciones, aprende de ellos y lo devuelve con la siguiente lista.\n"
            "5. En la casa de subastas, pulsa el botón grande: busca cada objeto y se detiene en las ofertas; pulsa otra vez para comprar "
            "(los materiales piden una confirmación más del precio final).\n"
            "6. Pulsa 'Publicar mis objetos' para poner en venta lo que compraste (y tu botín, si está activado). Rebaja al competidor "
            "más barato en 1 cobre, pero nunca baja de tu mínimo.\n"
            "7. Abre el buzón de vez en cuando: las facturas de venta le dicen a la app qué se vendió de verdad y por cuánto.\n"
            "Repite varias veces al día. Más escaneos = mejor conocimiento de los precios.")

SECTIONS = [
    ("What this is", (
        "Was das ist", "Qu'est-ce que c'est", "Qué es esto", "Qué es esto", "Che cos'è", "O que é isto",
        "Что это", "이 프로그램은", "这是什么", "這是什麼")),
    ("FlipForever finds items", (
        "FlipForever findet Gegenstände im Auktionshaus von WoW Forever, die unter ihrem üblichen Verkaufspreis angeboten werden, "
        "sagt dem Addon im Spiel genau, was es kaufen soll und wie viel es höchstens zahlen darf, und stellt sie dann zu einem "
        "vernünftigen Preis wieder ein. Es lernt aus jedem Verkauf und jedem Ablauf und wird so mit der Zeit immer besser.",
        "FlipForever repère à l'hôtel des ventes de WoW Forever les objets proposés sous leur prix de vente habituel, indique à "
        "l'addon en jeu exactement quoi acheter et le prix maximum, puis les remet en vente à un prix raisonnable. Il apprend de "
        "chaque vente et de chaque expiration, et s'améliore à l'usage.",
        "FlipForever encuentra en la casa de subastas de WoW Forever objetos publicados por debajo de su precio habitual, le dice "
        "al addon del juego exactamente qué comprar y cuánto pagar como máximo, y después los vuelve a publicar a un precio "
        "razonable. Aprende de cada venta y cada caducidad, así que mejora cuanto más lo usas.",
        "FlipForever encuentra en la casa de subastas de WoW Forever objetos publicados por debajo de su precio habitual, le dice "
        "al addon del juego exactamente qué comprar y cuánto pagar como máximo, y después los vuelve a publicar a un precio "
        "razonable. Aprende de cada venta y cada vencimiento, así que mejora cuanto más lo usas.",
        "FlipForever trova nella casa d'aste di WoW Forever gli oggetti in vendita sotto il loro prezzo abituale, dice all'addon "
        "in gioco esattamente cosa comprare e quanto pagare al massimo, poi li rimette all'asta a un prezzo sensato. Impara da "
        "ogni vendita e scadenza, quindi migliora più lo usi.",
        "O FlipForever encontra na Casa de Leilões do WoW Forever itens anunciados abaixo do preço normal, diz ao addon no jogo "
        "exatamente o que comprar e o máximo a pagar, e depois os anuncia de novo por um preço sensato. Ele aprende com cada "
        "venda e expiração, então melhora quanto mais você usa.",
        "FlipForever находит на аукционе WoW Forever предметы, выставленные дешевле обычной цены, говорит аддону в игре, что "
        "именно купить и сколько максимум заплатить, а затем выставляет их по разумной цене. Он учится на каждой продаже и "
        "каждом истёкшем лоте, поэтому со временем работает всё лучше.",
        "FlipForever는 WoW Forever 경매장에서 평소 판매가보다 싸게 올라온 아이템을 찾아, 게임 속 애드온에 무엇을 얼마까지 "
        "살지 정확히 알려 주고, 적당한 가격에 다시 등록합니다. 판매와 만료를 하나하나 학습하므로 쓸수록 좋아집니다.",
        "FlipForever 会在 WoW Forever 拍卖行中找出低于平常售价挂出的物品，告诉游戏内插件具体买什么、最多付多少，再以合理价格"
        "重新上架。它会从每次售出和过期中学习，用得越多越准。",
        "FlipForever 會在 WoW Forever 拍賣場中找出低於平常售價掛出的物品，告訴遊戲內插件具體買什麼、最多付多少，再以合理價格"
        "重新上架。它會從每次售出和過期中學習，用得越多越準。")),
    ("Why you still press a button", (
        "Warum du trotzdem eine Taste drückst", "Pourquoi il faut quand même appuyer sur un bouton", "Por qué sigues pulsando un botón",
        "Por qué sigues presionando un botón", "Perché devi comunque premere un tasto", "Por que você ainda aperta um botão",
        "Почему всё равно нужно нажимать кнопку", "그래도 버튼을 눌러야 하는 이유", "为什么仍需按键", "為什麼仍需按鍵")),
    ("Blizzard only allows", (
        "Blizzard erlaubt einem Addon nur während eines echten Tastendrucks oder Klicks, etwas zu kaufen oder einzustellen - "
        "vollautomatische Bots verstoßen gegen die Regeln und führen zu Sperren. FlipForever übernimmt das Denken und Suchen; du "
        "drückst eine Taste pro Kauf oder Auktion. Tipp: Tippe im Spiel  /ff key SPACE  (oder eine andere Taste), dann steuert "
        "diese Taste den großen Knopf, solange das Auktionshaus offen ist.",
        "Blizzard n'autorise un addon à acheter ou à mettre en vente que pendant un vrai appui de touche ou clic - les bots "
        "entièrement automatiques sont interdits et font bannir les comptes. FlipForever réfléchit et cherche à votre place ; vous "
        "appuyez sur une touche par achat ou mise en vente. Astuce : tapez en jeu  /ff key SPACE  (ou une autre touche) pour que "
        "cette touche actionne le gros bouton quand l'hôtel des ventes est ouvert.",
        "Blizzard solo permite que un addon compre o publique durante una pulsación real de tecla o un clic: los bots totalmente "
        "automáticos van contra las normas y hacen que se bloqueen cuentas. FlipForever piensa y busca por ti; tú pulsas una "
        "tecla por compra o publicación. Consejo: en el juego escribe  /ff key SPACE  (u otra tecla) para que esa tecla accione "
        "el botón grande mientras la casa de subastas esté abierta.",
        "Blizzard solo permite que un addon compre o publique durante una pulsación real de tecla o un clic: los bots totalmente "
        "automáticos van contra las reglas y hacen que se bloqueen cuentas. FlipForever piensa y busca por ti; tú presionas una "
        "tecla por compra o publicación. Consejo: en el juego escribe  /ff key SPACE  (u otra tecla) para que esa tecla active "
        "el botón grande mientras la casa de subastas esté abierta.",
        "Blizzard permette a un addon di comprare o mettere all'asta solo durante una vera pressione di tasto o un clic - i bot "
        "completamente automatici sono vietati e portano al ban dell'account. FlipForever pensa e cerca al posto tuo; tu premi un "
        "tasto per ogni acquisto o inserzione. Suggerimento: in gioco scrivi  /ff key SPACE  (o un altro tasto) così quel tasto "
        "aziona il pulsante grande quando la casa d'aste è aperta.",
        "A Blizzard só permite que um addon compre ou anuncie durante um aperto real de tecla ou clique - bots totalmente "
        "automáticos são contra as regras e levam a banimento. O FlipForever pensa e busca por você; você aperta uma tecla por "
        "compra ou anúncio. Dica: no jogo digite  /ff key SPACE  (ou outra tecla) para essa tecla acionar o botão grande "
        "enquanto a Casa de Leilões estiver aberta.",
        "Blizzard разрешает аддону покупать и выставлять лоты только во время настоящего нажатия клавиши или клика - полностью "
        "автоматические боты запрещены, за них блокируют аккаунты. FlipForever думает и ищет за вас; вы нажимаете одну клавишу на "
        "покупку или лот. Совет: введите в игре  /ff key SPACE  (или другую клавишу), и эта клавиша будет нажимать большую кнопку, "
        "пока открыт аукцион.",
        "블리자드는 실제 키 입력이나 클릭이 있을 때만 애드온이 구매하거나 등록하도록 허용합니다. 완전 자동 봇은 규칙 위반이며 "
        "계정이 정지됩니다. 생각과 검색은 FlipForever가 하고, 여러분은 구매나 등록마다 키를 한 번 누릅니다. 팁: 게임에서  "
        "/ff key SPACE  (또는 다른 키)를 입력하면 경매장이 열려 있는 동안 그 키로 큰 버튼을 누를 수 있습니다.",
        "暴雪只允许插件在真实按键或点击时购买或上架 - 全自动机器人违反规则，会导致封号。FlipForever 负责思考和搜索；你每次"
        "购买或上架按一次键。提示：在游戏中输入  /ff key SPACE （或其他键），拍卖行打开时这个键就会按下大按钮。",
        "暴雪只允許插件在真實按鍵或點擊時購買或上架 - 全自動機器人違反規則，會導致封號。FlipForever 負責思考和搜尋；你每次"
        "購買或上架按一次鍵。提示：在遊戲中輸入  /ff key SPACE （或其他鍵），拍賣場開啟時這個鍵就會按下大按鈕。")),
    ("The loop", (
        "Der Ablauf", "Le cycle", "El ciclo", "El ciclo", "Il ciclo", "O ciclo", "Порядок работы", "사용 순서", "流程", "流程")),
    ("1. Settings -> Install", (
        "1. Einstellungen -> Addon installieren / aktualisieren.\n"
        "2. Im Spiel: Öffne das Auktionshaus und klicke im FlipForever-Fenster auf 'Vollständiger Scan' (einmal alle 15 Min. möglich).\n"
        "3. Ist der Scan fertig, erstellt das Addon deine Einkaufsliste im Spiel neu - ohne Neuladen.\n"
        "4. Klicke ab und zu im Spiel auf Neu laden: Die App importiert deine Scans und Geschäfte, lernt daraus und gibt das mit der nächsten Liste zurück.\n"
        "5. Drücke im Auktionshaus den großen Knopf: Er sucht jeden Gegenstand und hält bei Angeboten an - drücke erneut zum Kaufen "
        "(Waren fragen noch einmal nach dem Endpreis).\n"
        "6. Klicke auf 'Meine Gegenstände einstellen', um Gekauftes (und deine Beute, falls eingeschaltet) anzubieten. Es unterbietet "
        "den günstigsten Konkurrenten um 1 Kupfer, geht aber nie unter deinen Mindestpreis.\n"
        "7. Schau ab und zu in deinen Briefkasten - die Verkaufsbelege zeigen der App, was wirklich verkauft wurde und zu welchem Preis.\n"
        "Mehrmals am Tag wiederholen. Mehr Scans = besseres Preiswissen.",
        "1. Paramètres -> Installer / mettre à jour l'addon.\n"
        "2. En jeu : ouvrez l'hôtel des ventes et cliquez sur 'Scan complet' dans le panneau FlipForever (possible une fois toutes les 15 min).\n"
        "3. Une fois le scan terminé, l'addon refait votre liste d'achats en jeu - sans recharger.\n"
        "4. De temps en temps, cliquez sur Recharger en jeu : l'appli importe vos scans et échanges, en tire des leçons et les renvoie avec la liste suivante.\n"
        "5. À l'hôtel des ventes, appuyez sur le gros bouton : il cherche chaque objet et s'arrête sur les bonnes affaires - appuyez "
        "encore pour acheter (les marchandises demandent une confirmation du prix final).\n"
        "6. Cliquez sur 'Vendre mes objets' pour mettre en vente vos achats (et votre butin, si activé). Il passe 1 cuivre sous le "
        "concurrent le moins cher, sans jamais descendre sous votre prix plancher.\n"
        "7. Ouvrez votre boîte aux lettres de temps en temps - les avis de vente indiquent à l'appli ce qui s'est vraiment vendu et à quel prix.\n"
        "À répéter plusieurs fois par jour. Plus de scans = une meilleure connaissance des prix.",
        _ES_LOOP,
        _ES_LOOP.replace("pulsa 'Escaneo", "haz clic en 'Escaneo").replace("pulsa Recargar", "haz clic en Recargar")
                .replace("pulsa el botón grande", "presiona el botón grande").replace("pulsa otra vez", "presiona otra vez")
                .replace("Pulsa 'Publicar", "Haz clic en 'Publicar"),
        "1. Impostazioni -> Installa / aggiorna l'addon.\n"
        "2. In gioco: apri la casa d'aste e clicca 'Scansione completa' nel pannello di FlipForever (possibile una volta ogni 15 min).\n"
        "3. Finita la scansione, l'addon rifà la lista della spesa in gioco - senza ricaricare.\n"
        "4. Ogni tanto clicca Ricarica in gioco: l'app importa scansioni e scambi, impara da essi e lo restituisce con la lista successiva.\n"
        "5. Alla casa d'aste premi il pulsante grande: cerca ogni oggetto e si ferma sugli affari - premi di nuovo per comprare "
        "(le merci chiedono un'altra conferma del prezzo finale).\n"
        "6. Clicca 'Metti all'asta i miei oggetti' per vendere ciò che hai comprato (e il tuo bottino, se attivo). Batte il "
        "concorrente più economico di 1 rame, ma non scende mai sotto il tuo minimo.\n"
        "7. Apri ogni tanto la cassetta della posta - le ricevute di vendita dicono all'app cosa si è venduto davvero e a quanto.\n"
        "Ripeti più volte al giorno. Più scansioni = prezzi conosciuti meglio.",
        "1. Configurações -> Instalar / atualizar o addon.\n"
        "2. No jogo: abra a Casa de Leilões e clique em 'Escaneamento completo' no painel do FlipForever (uma vez a cada 15 min).\n"
        "3. Quando o escaneamento termina, o addon refaz sua lista de compras no jogo - sem recarregar.\n"
        "4. De vez em quando clique em Recarregar no jogo: o app importa seus escaneamentos e negociações, aprende com eles e devolve isso com a próxima lista.\n"
        "5. Na Casa de Leilões, aperte o botão grande: ele busca cada item e para nas ofertas - aperte de novo para comprar "
        "(mercadorias pedem mais uma confirmação do preço final).\n"
        "6. Clique em 'Anunciar meus itens' para vender o que comprou (e seu saque, se ativado). Ele cobre o concorrente mais "
        "barato em 1 cobre, mas nunca fica abaixo do seu mínimo.\n"
        "7. Abra sua caixa de correio de vez em quando - os avisos de venda contam ao app o que realmente vendeu e por quanto.\n"
        "Repita algumas vezes por dia. Mais escaneamentos = melhor conhecimento de preços.",
        "1. Настройки -> Установить / обновить аддон.\n"
        "2. В игре: откройте аукцион и нажмите «Полное сканирование» на панели FlipForever (раз в 15 минут).\n"
        "3. Когда сканирование закончится, аддон пересоберёт список покупок прямо в игре - без перезагрузки.\n"
        "4. Время от времени нажимайте в игре «Перезагрузить»: приложение загружает сканирования и сделки, учится на них и передаёт это со следующим списком.\n"
        "5. На аукционе нажимайте большую кнопку: она ищет каждый предмет и останавливается на выгодных лотах - нажмите ещё раз, "
        "чтобы купить (для товаров нужно ещё раз подтвердить итоговую цену).\n"
        "6. Нажмите «Выставить мои предметы», чтобы выставить купленное (и добычу, если включено). Цена на 1 медь ниже самого "
        "дешёвого конкурента, но никогда не ниже вашего минимума.\n"
        "7. Иногда заглядывайте в почтовый ящик - уведомления о продаже показывают приложению, что действительно продалось и за сколько.\n"
        "Повторяйте несколько раз в день. Больше сканирований = точнее цены.",
        "1. 설정 -> 애드온 설치 / 업데이트.\n"
        "2. 게임에서: 경매장을 열고 FlipForever 패널의 '전체 스캔'을 누르세요 (15분마다 한 번 가능).\n"
        "3. 스캔이 끝나면 애드온이 게임 안에서 구매 목록을 다시 만듭니다 - 재시작 필요 없음.\n"
        "4. 가끔 게임에서 재시작을 누르세요: 앱이 스캔과 거래를 가져와 학습하고, 다음 목록에 반영합니다.\n"
        "5. 경매장에서 큰 버튼을 누르세요: 아이템을 하나씩 검색하다가 좋은 거래에서 멈춥니다 - 다시 누르면 구매합니다 "
        "(거래품은 최종 가격을 한 번 더 확인합니다).\n"
        "6. '내 아이템 등록'을 누르면 산 물건(설정한 경우 파밍한 전리품도)을 등록합니다. 가장 싼 경쟁자보다 1동화 싸게 "
        "올리지만 최저가 아래로는 절대 내려가지 않습니다.\n"
        "7. 가끔 우편함을 여세요 - 판매 영수증으로 앱이 실제로 무엇이 얼마에 팔렸는지 알게 됩니다.\n"
        "하루에 몇 번 반복하세요. 스캔이 많을수록 가격을 더 잘 압니다.",
        "1. 设置 -> 安装/更新插件。\n"
        "2. 游戏中：打开拍卖行，点击 FlipForever 面板上的“完整扫描”（每 15 分钟一次）。\n"
        "3. 扫描完成后，插件会在游戏内重建你的购物清单 - 无需重载。\n"
        "4. 时不时在游戏中点击重载：应用会导入你的扫描和交易，从中学习，并随下一份清单传回。\n"
        "5. 在拍卖行按大按钮：它逐个搜索物品，遇到好价会停下 - 再按一次购买（商品会再确认一次最终价格）。\n"
        "6. 点击“上架我的物品”出售你买到的东西（以及开启时你刷到的物品）。比最便宜的对手低 1 铜，但绝不低于你的底价。\n"
        "7. 时不时打开邮箱 - 售出通知会告诉应用实际卖出了什么、卖了多少。\n"
        "每天重复几次。扫描越多，价格越准。",
        "1. 設定 -> 安裝/更新插件。\n"
        "2. 遊戲中：打開拍賣場，點擊 FlipForever 面板上的「完整掃描」（每 15 分鐘一次）。\n"
        "3. 掃描完成後，插件會在遊戲內重建你的購物清單 - 無需重新載入。\n"
        "4. 不時在遊戲中點擊重新載入：應用程式會匯入你的掃描和交易，從中學習，並隨下一份清單傳回。\n"
        "5. 在拍賣場按大按鈕：它逐個搜尋物品，遇到好價會停下 - 再按一次購買（商品會再確認一次最終價格）。\n"
        "6. 點擊「上架我的物品」出售你買到的東西（以及開啟時你刷到的物品）。比最便宜的對手低 1 銅，但絕不低於你的底價。\n"
        "7. 不時打開郵箱 - 售出通知會告訴應用程式實際賣出了什麼、賣了多少。\n"
        "每天重複幾次。掃描越多，價格越準。")),
    ("Reading the Deals tab", (
        "Die Angebote-Seite lesen", "Lire l'onglet Affaires", "Cómo leer la pestaña Ofertas", "Cómo leer la pestaña Ofertas",
        "Leggere la scheda Affari", "Como ler a aba Ofertas", "Как читать вкладку «Сделки»", "거래 기회 탭 읽는 법", "看懂“好价”页", "看懂「好價」頁")),
    ("Now = cheapest listing", (
        "Jetzt = günstigstes Angebot beim letzten Scan. Fairer Wert = typischer Preis der letzten 14 Tage, neuere Preise zählen mehr. "
        "Max. Kauf = das Höchste, was du zahlen kannst und trotzdem deine Marge nach 5 % AH-Gebühr, Anzahlungen und dem Risiko, "
        "dass es nicht verkauft wird, erreichst. Die Verkaufschance ist anfangs eine Schätzung aus der Marktaktivität und wird "
        "dann deine eigene Erfolgsbilanz. Die Sicherheit sinkt bei sprunghaften Preisen und wenig Daten.",
        "Actuel = annonce la moins chère au dernier scan. Valeur juste = prix habituel sur 14 jours, les prix récents comptant "
        "davantage. Achat max = le plus que vous pouvez payer en gardant votre marge après la commission de 5 %, les dépôts et le "
        "risque de ne pas vendre. La chance de vente part d'une estimation selon l'activité du marché puis devient votre propre "
        "historique. La confiance baisse pour les prix instables et les données rares.",
        "Ahora = publicación más barata en el último escaneo. Valor justo = precio típico de los últimos 14 días, con más peso "
        "para los recientes. Compra máx. = lo máximo que puedes pagar y aun así lograr tu margen tras la comisión del 5 %, los "
        "depósitos y la posibilidad de no vender. La probabilidad de venta empieza como estimación según la actividad del mercado "
        "y pasa a ser tu propio historial. La confianza baja con precios inestables y pocos datos.",
        "Ahora = publicación más barata en el último escaneo. Valor justo = precio típico de los últimos 14 días, con más peso "
        "para los recientes. Compra máx. = lo máximo que puedes pagar y aun así lograr tu margen tras la comisión del 5 %, los "
        "depósitos y la posibilidad de no vender. La probabilidad de venta empieza como estimación según la actividad del mercado "
        "y pasa a ser tu propio historial. La confianza baja con precios inestables y pocos datos.",
        "Ora = inserzione più economica all'ultima scansione. Valore equo = prezzo tipico degli ultimi 14 giorni, con più peso ai "
        "più recenti. Acquisto max = il massimo che puoi pagare mantenendo il margine dopo la commissione del 5%, i depositi e il "
        "rischio di non vendere. La probabilità di vendita parte da una stima dell'attività del mercato e diventa il tuo storico. "
        "L'affidabilità cala con prezzi instabili e pochi dati.",
        "Agora = anúncio mais barato no último escaneamento. Valor justo = preço típico dos últimos 14 dias, com mais peso para os "
        "recentes. Compra máx. = o máximo que você pode pagar e ainda ter sua margem após a taxa de 5%, depósitos e a chance de "
        "não vender. A chance de venda começa como estimativa pela atividade do mercado e passa a ser seu próprio histórico. A "
        "confiança cai com preços instáveis e poucos dados.",
        "Сейчас = самый дешёвый лот в последнем сканировании. Справедливая цена = обычная цена за 14 дней, недавние цены весят "
        "больше. Макс. покупка = наибольшая цена, при которой сохраняется ваша маржа после 5% комиссии, залогов и риска, что лот "
        "не продастся. Шанс продажи сначала оценивается по активности рынка, а потом становится вашей собственной статистикой. "
        "Уверенность ниже при скачущих ценах и малом количестве данных.",
        "현재 = 마지막 스캔의 최저가 매물. 적정가 = 최근 14일의 일반 가격 (최근 가격일수록 비중이 큼). 최대 구매가 = 5% 수수료, "
        "보증금, 안 팔릴 가능성을 감안해도 마진을 지킬 수 있는 최고 가격. 판매 확률은 처음엔 시장 활동으로 추정하고, 이후엔 "
        "나의 실제 기록이 됩니다. 가격이 들쭉날쭉하거나 데이터가 적으면 신뢰도가 낮아집니다.",
        "当前 = 上次扫描的最低挂单。合理价 = 近 14 天的典型价格，越近的价格权重越高。最高买价 = 扣除 5% 手续费、押金和卖不出"
        "的风险后，仍能保住利润率的最高价。售出几率起初按市场活跃度估算，之后会变成你自己的实际记录。价格波动大或数据少时，"
        "可信度会降低。",
        "目前 = 上次掃描的最低掛單。合理價 = 近 14 天的典型價格，越近的價格權重越高。最高買價 = 扣除 5% 手續費、押金和賣不出"
        "的風險後，仍能保住利潤率的最高價。售出機率起初按市場活躍度估算，之後會變成你自己的實際紀錄。價格波動大或資料少時，"
        "可信度會降低。")),
    ("Staying safe", (
        "Sicher bleiben", "Rester prudent", "Ir con cuidado", "Ir con cuidado", "Andare sul sicuro", "Jogando com segurança",
        "Осторожность", "안전하게 쓰기", "稳妥使用", "穩妥使用")),
    ("Start with a small gold budget", (
        "Fang mit einem kleinen Gold-Budget an, solange die App deinen Server kennenlernt. Dünne Märkte (wenige Verkäufe pro Tag) "
        "lassen sich manipulieren - die App bevorzugt Gegenstände, die sich wirklich verkaufen. Nutze 'Ausgewählte nie kaufen' "
        "für alles, dem du nicht traust.",
        "Commencez avec un petit budget en or pendant que l'appli apprend votre serveur. Les marchés peu actifs (peu de ventes par "
        "jour) peuvent être manipulés - l'appli préfère les objets qui se vendent vraiment. Utilisez 'Ne jamais acheter la "
        "sélection' pour tout ce qui vous semble douteux.",
        "Empieza con un presupuesto de oro pequeño mientras la app conoce tu servidor. Los mercados con poca actividad (pocas "
        "ventas al día) se pueden manipular; la app prefiere objetos que se venden de verdad. Usa 'No comprar nunca lo "
        "seleccionado' con lo que no te dé confianza.",
        "Empieza con un presupuesto de oro pequeño mientras la app conoce tu servidor. Los mercados con poca actividad (pocas "
        "ventas al día) se pueden manipular; la app prefiere objetos que se venden de verdad. Usa 'No comprar nunca lo "
        "seleccionado' con lo que no te dé confianza.",
        "Inizia con un budget in oro piccolo mentre l'app impara il tuo server. I mercati poco attivi (poche vendite al giorno) "
        "si possono manipolare - l'app preferisce oggetti che si vendono davvero. Usa 'Non comprare mai i selezionati' per ciò "
        "di cui non ti fidi.",
        "Comece com um orçamento de ouro pequeno enquanto o app aprende o seu servidor. Mercados fracos (poucas vendas por dia) "
        "podem ser manipulados - o app prefere itens que realmente vendem. Use 'Nunca comprar o selecionado' no que você não "
        "confiar.",
        "Начните с небольшого бюджета, пока приложение изучает ваш сервер. Вялыми рынками (мало продаж в день) можно "
        "манипулировать - приложение предпочитает то, что действительно продаётся. Для всего сомнительного используйте "
        "«Никогда не покупать выбранное».",
        "앱이 서버를 익히는 동안은 적은 골드 예산으로 시작하세요. 거래가 적은 시장(하루 판매가 적음)은 조작될 수 있으므로 앱은 "
        "실제로 팔리는 아이템을 선호합니다. 믿기 어려운 아이템은 '선택 항목 구매 안 함'을 사용하세요.",
        "在应用熟悉你的服务器期间，先用少量金币预算。交易稀少的市场（每天卖得很少）可能被操纵 - 应用更偏好真正卖得动的物品。"
        "对不放心的物品使用“永不购买所选”。",
        "在應用程式熟悉你的伺服器期間，先用少量金幣預算。交易稀少的市場（每天賣得很少）可能被操縱 - 應用程式更偏好真正賣得動的"
        "物品。對不放心的物品使用「永不購買所選」。")),
]

ORDER = ["deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]


def translate(index: int, english: str, lang: str) -> str:
    """The How to use section at `index` in `lang`, or the English text when there is none
    (or when the English text has changed since it was translated)."""
    if lang not in ORDER or index >= len(SECTIONS):
        return english
    start, row = SECTIONS[index]
    if not english.startswith(start):
        return english
    return row[ORDER.index(lang)]

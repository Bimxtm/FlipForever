"""Translations for the desktop app and the in-game addon (one source for both).

The English text is the key. Anything not translated yet falls back to English.
tools/gen_locale.py writes addon/FlipForever/Locale.lua from this file.
"""
from __future__ import annotations

# WoW's client languages, in the order the game lists them
LANGUAGES = {
    "enUS": "English",
    "deDE": "Deutsch",
    "frFR": "Français",
    "esES": "Español (España)",
    "esMX": "Español (México)",
    "itIT": "Italiano",
    "ptBR": "Português (Brasil)",
    "ruRU": "Русский",
    "koKR": "한국어",
    "zhCN": "简体中文",
    "zhTW": "繁體中文",
}

# key: English text; values in LANGUAGES order (without enUS)
_ROWS = {
    # --- shared / addon window
    "Overview": ("Übersicht", "Aperçu", "Resumen", "Resumen", "Panoramica", "Visão geral", "Обзор", "개요", "概览", "概覽"),
    "Shopping list": ("Einkaufsliste", "Liste d'achats", "Lista de compras", "Lista de compras", "Lista della spesa", "Lista de compras", "Список покупок", "구매 목록", "购物清单", "購物清單"),
    "Gear": ("Ausrüstung", "Équipement", "Equipo", "Equipo", "Equipaggiamento", "Equipamento", "Снаряжение", "장비", "装备", "裝備"),
    "Settings": ("Einstellungen", "Paramètres", "Ajustes", "Configuración", "Impostazioni", "Configurações", "Настройки", "설정", "设置", "設定"),
    "Auction house": ("Auktionshaus", "Hôtel des ventes", "Casa de subastas", "Casa de subastas", "Casa d'aste", "Casa de Leilões", "Аукцион", "경매장", "拍卖行", "拍賣場"),
    "Next step (Advisor)": ("Nächster Schritt (Berater)", "Prochaine étape (Conseiller)", "Siguiente paso (Asesor)", "Siguiente paso (Asesor)", "Prossimo passo (Consigliere)", "Próximo passo (Conselheiro)", "Следующий шаг (Советник)", "다음 단계 (조언자)", "下一步（顾问）", "下一步（顧問）"),
    "Open": ("Öffnen", "Ouvrir", "Abrir", "Abrir", "Apri", "Abrir", "Открыть", "열기", "打开", "開啟"),
    "Advisor": ("Berater", "Conseiller", "Asesor", "Asesor", "Consigliere", "Conselheiro", "Советник", "조언자", "顾问", "顧問"),
    "Gathering": ("Sammeln", "Récolte", "Recolección", "Recolección", "Raccolta", "Coleta", "Сбор ресурсов", "채집", "采集", "採集"),
    "Professions": ("Berufe", "Métiers", "Profesiones", "Profesiones", "Professioni", "Profissões", "Профессии", "전문 기술", "专业", "專業"),
    "Combat helper": ("Kampfhelfer", "Aide au combat", "Ayudante de combate", "Ayudante de combate", "Assistente di combattimento", "Assistente de combate", "Помощник в бою", "전투 도우미", "战斗助手", "戰鬥助手"),
    "Combat helper on screen": ("Kampfhelfer anzeigen", "Aide au combat à l'écran", "Ayudante de combate en pantalla", "Ayudante de combate en pantalla", "Assistente di combattimento a schermo", "Assistente de combate na tela", "Помощник в бою на экране", "화면에 전투 도우미 표시", "在屏幕上显示战斗助手", "在螢幕上顯示戰鬥助手"),
    "Show the combat helper": ("Kampfhelfer anzeigen", "Afficher l'aide au combat", "Mostrar el ayudante de combate", "Mostrar el ayudante de combate", "Mostra l'assistente di combattimento", "Mostrar o assistente de combate", "Показать помощника в бою", "전투 도우미 표시", "显示战斗助手", "顯示戰鬥助手"),
    "Autopilot at the auction house": ("Autopilot im Auktionshaus", "Pilote automatique à l'hôtel des ventes", "Piloto automático en la casa de subastas", "Piloto automático en la casa de subastas", "Pilota automatico alla casa d'aste", "Piloto automático na Casa de Leilões", "Автопилот на аукционе", "경매장 자동 조종", "拍卖行自动模式", "拍賣場自動模式"),
    "See the shopping list": ("Einkaufsliste ansehen", "Voir la liste d'achats", "Ver la lista de compras", "Ver la lista de compras", "Vedi la lista della spesa", "Ver a lista de compras", "Открыть список покупок", "구매 목록 보기", "查看购物清单", "查看購物清單"),
    "Reload UI (sync)": ("UI neu laden (Sync)", "Recharger l'IU (synchro)", "Recargar IU (sincronizar)", "Recargar IU (sincronizar)", "Ricarica IU (sincronizza)", "Recarregar IU (sincronizar)", "Перезагрузить UI (синхр.)", "UI 재시작 (동기화)", "重载界面（同步）", "重新載入介面（同步）"),
    "Search my scan": ("Scan durchsuchen", "Chercher dans mon scan", "Buscar en mi escaneo", "Buscar en mi escaneo", "Cerca nella scansione", "Buscar no meu escaneamento", "Искать в скане", "스캔 검색", "搜索我的扫描", "搜尋我的掃描"),
    "Slot": ("Platz", "Emplacement", "Ranura", "Ranura", "Slot", "Espaço", "Слот", "부위", "部位", "部位"),
    "Item": ("Gegenstand", "Objet", "Objeto", "Objeto", "Oggetto", "Item", "Предмет", "아이템", "物品", "物品"),
    "Price": ("Preis", "Prix", "Precio", "Precio", "Prezzo", "Preço", "Цена", "가격", "价格", "價格"),
    "Better": ("Besser", "Mieux", "Mejor", "Mejor", "Meglio", "Melhor", "Лучше", "향상", "提升", "提升"),
    "Buy": ("Kaufen", "Acheter", "Comprar", "Comprar", "Compra", "Comprar", "Купить", "구매", "购买", "購買"),
    "Now": ("Jetzt", "Actuel", "Ahora", "Ahora", "Ora", "Agora", "Сейчас", "현재", "当前", "目前"),
    "Max": ("Max", "Max", "Máx", "Máx", "Max", "Máx", "Макс.", "최대", "上限", "上限"),
    "Got": ("Gekauft", "Acheté", "Comprado", "Comprado", "Preso", "Comprado", "Куплено", "구매함", "已买", "已買"),
    "Skip": ("Überspringen", "Ignorer", "Omitir", "Omitir", "Salta", "Pular", "Пропустить", "건너뛰기", "跳过", "略過"),
    "Auto-target": ("Auto-Ziel", "Ciblage auto", "Objetivo auto", "Objetivo auto", "Bersaglio auto", "Alvo automático", "Автовыбор цели", "자동 대상", "自动目标", "自動目標"),
    "Tank mode": ("Tank-Modus", "Mode tank", "Modo tanque", "Modo tanque", "Modalità tank", "Modo tanque", "Режим танка", "탱커 모드", "坦克模式", "坦克模式"),
    "Set key": ("Taste setzen", "Choisir touche", "Asignar tecla", "Asignar tecla", "Imposta tasto", "Definir tecla", "Назначить", "키 설정", "设置按键", "設定按鍵"),
    "Clear": ("Löschen", "Effacer", "Borrar", "Borrar", "Cancella", "Limpar", "Сбросить", "지우기", "清除", "清除"),
    "Check the whole list again": ("Ganze Liste neu prüfen", "Revérifier toute la liste", "Revisar toda la lista", "Revisar toda la lista", "Ricontrolla tutta la lista", "Verificar a lista inteira", "Проверить весь список снова", "목록 전체 다시 확인", "重新检查整个清单", "重新檢查整個清單"),
    "Buttons on screen": ("Schaltflächen auf dem Bildschirm", "Boutons à l'écran", "Botones en pantalla", "Botones en pantalla", "Pulsanti a schermo", "Botões na tela", "Кнопки на экране", "화면 버튼", "屏幕按钮", "螢幕按鈕"),
    "Prices in item tooltips": ("Preise in Tooltips", "Prix dans les infobulles", "Precios en las descripciones", "Precios en las descripciones", "Prezzi nei tooltip", "Preços nas dicas", "Цены в подсказках", "툴팁에 가격 표시", "在提示中显示价格", "在提示中顯示價格"),
    "Pop up my next steps on level-up": ("Nächste Schritte beim Stufenaufstieg zeigen", "Afficher mes étapes à chaque niveau", "Mostrar mis pasos al subir de nivel", "Mostrar mis pasos al subir de nivel", "Mostra i passi a ogni livello", "Mostrar meus passos ao subir de nível", "Показывать шаги при новом уровне", "레벨업 시 다음 단계 표시", "升级时弹出下一步", "升級時彈出下一步"),
    "Language": ("Sprache", "Langue", "Idioma", "Idioma", "Lingua", "Idioma", "Язык", "언어", "语言", "語言"),
    "Game language": ("Spielsprache", "Langue du jeu", "Idioma del juego", "Idioma del juego", "Lingua del gioco", "Idioma do jogo", "Язык игры", "게임 언어", "游戏语言", "遊戲語言"),
    "Buy deals": ("Angebote kaufen", "Acheter les affaires", "Comprar ofertas", "Comprar ofertas", "Compra affari", "Comprar ofertas", "Купить сделки", "거래 구매", "购买好价", "購買好價"),
    "Post my items": ("Meine Gegenstände einstellen", "Mettre mes objets en vente", "Publicar mis objetos", "Publicar mis objetos", "Metti in vendita", "Anunciar meus itens", "Выставить мои предметы", "내 아이템 등록", "上架我的物品", "上架我的物品"),
    "Stop": ("Stopp", "Arrêter", "Detener", "Detener", "Ferma", "Parar", "Стоп", "중지", "停止", "停止"),
    "Full scan": ("Komplett-Scan", "Scan complet", "Escaneo completo", "Escaneo completo", "Scansione completa", "Escaneamento completo", "Полное сканирование", "전체 스캔", "完整扫描", "完整掃描"),
    "Buy profession mats": ("Berufsmaterial kaufen", "Acheter les composants", "Comprar materiales", "Comprar materiales", "Compra materiali", "Comprar materiais", "Купить материалы", "전문 기술 재료 구매", "购买专业材料", "購買專業材料"),
    "Reload": ("Neu laden", "Recharger", "Recargar", "Recargar", "Ricarica", "Recarregar", "Перезагрузка", "재시작", "重载", "重新載入"),
    "Start": ("Start", "Démarrer", "Empezar", "Empezar", "Avvia", "Iniciar", "Старт", "시작", "开始", "開始"),
    "Searching...": ("Suche...", "Recherche...", "Buscando...", "Buscando...", "Ricerca...", "Buscando...", "Поиск...", "검색 중...", "搜索中...", "搜尋中..."),
    "Getting price...": ("Preis wird abgefragt...", "Obtention du prix...", "Obteniendo precio...", "Obteniendo precio...", "Recupero prezzo...", "Obtendo preço...", "Узнаём цену...", "가격 확인 중...", "获取价格中...", "取得價格中..."),
    "Buying...": ("Kaufe...", "Achat...", "Comprando...", "Comprando...", "Acquisto...", "Comprando...", "Покупка...", "구매 중...", "购买中...", "購買中..."),
    "Posting...": ("Stelle ein...", "Mise en vente...", "Publicando...", "Publicando...", "Messa in vendita...", "Anunciando...", "Выставляем...", "등록 중...", "上架中...", "上架中..."),
    "CONFIRM POST": ("EINSTELLEN BESTÄTIGEN", "CONFIRMER LA VENTE", "CONFIRMAR PUBLICACIÓN", "CONFIRMAR PUBLICACIÓN", "CONFERMA VENDITA", "CONFIRMAR ANÚNCIO", "ПОДТВЕРДИТЬ", "등록 확인", "确认上架", "確認上架"),
    "Autopilot: check my list every minute, scan every 30 min": ("Autopilot: Liste jede Minute prüfen, alle 30 Min. scannen", "Pilote auto : vérifier ma liste chaque minute, scanner toutes les 30 min", "Piloto automático: revisar la lista cada minuto, escanear cada 30 min", "Piloto automático: revisar la lista cada minuto, escanear cada 30 min", "Pilota automatico: controlla la lista ogni minuto, scansiona ogni 30 min", "Piloto automático: verificar a lista a cada minuto, escanear a cada 30 min", "Автопилот: проверять список каждую минуту, сканировать каждые 30 мин", "자동 조종: 매분 목록 확인, 30분마다 스캔", "自动模式：每分钟检查清单，每30分钟扫描", "自動模式：每分鐘檢查清單，每30分鐘掃描"),
    "Let Blizzard's one-button assistant decide": ("Blizzards Ein-Tasten-Assistent entscheiden lassen", "Laisser décider l'assistant à un bouton de Blizzard", "Dejar que decida el asistente de un botón de Blizzard", "Dejar que decida el asistente de un botón de Blizzard", "Lascia decidere l'assistente a un tasto di Blizzard", "Deixar o assistente de um botão da Blizzard decidir", "Пусть решает помощник Blizzard в одну кнопку", "블리자드 원버튼 도우미에게 맡기기", "让暴雪一键助手决定", "讓暴雪一鍵助手決定"),
    "After a scan: rebuild my shopping list in game (no reload)": ("Nach einem Scan: Einkaufsliste im Spiel neu erstellen (ohne Neuladen)", "Après un scan : refaire ma liste en jeu (sans recharger)", "Tras un escaneo: rehacer mi lista en el juego (sin recargar)", "Tras un escaneo: rehacer mi lista en el juego (sin recargar)", "Dopo una scansione: rifai la lista nel gioco (senza ricaricare)", "Após um escaneamento: refazer minha lista no jogo (sem recarregar)", "После скана: пересобрать список в игре (без перезагрузки)", "스캔 후: 게임에서 구매 목록 다시 만들기 (재시작 없이)", "扫描后：在游戏中重建购物清单（无需重载）", "掃描後：在遊戲中重建購物清單（無需重新載入）"),
    "Otherwise: alert + pause autopilot until Reload": ("Sonst: Hinweis + Autopilot bis zum Neuladen pausieren", "Sinon : alerte + pause du pilote auto jusqu'au rechargement", "Si no: aviso + pausar el piloto automático hasta recargar", "Si no: aviso + pausar el piloto automático hasta recargar", "Altrimenti: avviso + pausa del pilota automatico fino al ricaricamento", "Senão: alerta + pausar o piloto automático até recarregar", "Иначе: сигнал + пауза автопилота до перезагрузки", "아니면: 알림 + 재시작까지 자동 조종 일시정지", "否则：提醒并暂停自动模式直到重载", "否則：提醒並暫停自動模式直到重新載入"),
    "FlipForever minimap button": ("FlipForever-Minikartenknopf", "Bouton FlipForever sur la minicarte", "Botón de FlipForever en el minimapa", "Botón de FlipForever en el minimapa", "Pulsante FlipForever sulla minimappa", "Botão do FlipForever no minimapa", "Кнопка FlipForever у миникарты", "미니맵 FlipForever 버튼", "小地图 FlipForever 按钮", "小地圖 FlipForever 按鈕"),
    "Gathering (ore) minimap button": ("Sammeln-Minikartenknopf", "Bouton Récolte sur la minicarte", "Botón de recolección en el minimapa", "Botón de recolección en el minimapa", "Pulsante Raccolta sulla minimappa", "Botão de coleta no minimapa", "Кнопка сбора у миникарты", "미니맵 채집 버튼", "小地图采集按钮", "小地圖採集按鈕"),
    "Gathering tracker (next stop, live gold)": ("Sammel-Anzeige (nächster Halt, Gold live)", "Suivi de récolte (prochain arrêt, or en direct)", "Seguimiento de recolección (siguiente parada, oro en vivo)", "Seguimiento de recolección (siguiente parada, oro en vivo)", "Tracker raccolta (prossima tappa, oro in tempo reale)", "Rastreador de coleta (próxima parada, ouro ao vivo)", "Трекер сбора (следующая точка, золото)", "채집 추적기 (다음 지점, 실시간 골드)", "采集追踪（下一站、实时金币）", "採集追蹤（下一站、即時金幣）"),
    "Planner next to profession windows": ("Planer neben Berufsfenstern", "Planificateur à côté des fenêtres de métier", "Planificador junto a las ventanas de profesión", "Planificador junto a las ventanas de profesión", "Pianificatore accanto alle finestre delle professioni", "Planejador ao lado das janelas de profissão", "Планировщик рядом с окнами профессий", "전문 기술 창 옆에 계획표", "专业窗口旁显示规划", "專業視窗旁顯示規劃"),
    "Vendor flips: buy below merchant price, sell at merchants": ("Händler-Flips: unter Händlerpreis kaufen, an Händler verkaufen", "Reventes marchand : acheter sous le prix marchand, vendre aux marchands", "Reventa a vendedores: comprar por debajo del precio de vendedor y venderlo", "Reventa a vendedores: comprar por debajo del precio de vendedor y venderlo", "Rivendita ai mercanti: compra sotto il prezzo del mercante e rivendi", "Revenda a mercadores: comprar abaixo do preço do mercador e vender", "Перепродажа торговцам: покупать дешевле цены торговца и продавать", "상인 되팔기: 상인가 이하로 사서 상인에게 판매", "商人倒卖：低于商人价买入，卖给商人", "商人倒賣：低於商人價買入，賣給商人"),
    "Do this next:": ("Als Nächstes:", "À faire ensuite :", "Haz esto ahora:", "Haz esto ahora:", "Fai questo dopo:", "Faça isto a seguir:", "Сделайте дальше:", "다음에 할 일:", "接下来做：", "接下來做："),
    "Build details": ("Build-Details", "Détails du build", "Detalles del build", "Detalles del build", "Dettagli build", "Detalhes da build", "Детали билда", "빌드 상세", "天赋详情", "天賦詳情"),
    "Re-check": ("Neu prüfen", "Revérifier", "Revisar", "Revisar", "Ricontrolla", "Verificar de novo", "Проверить", "다시 확인", "重新检查", "重新檢查"),
    "Pop up on level-up": ("Bei Stufenaufstieg anzeigen", "Afficher au niveau supérieur", "Mostrar al subir de nivel", "Mostrar al subir de nivel", "Mostra a ogni livello", "Mostrar ao subir de nível", "Показывать при новом уровне", "레벨업 시 표시", "升级时弹出", "升級時彈出"),
    "Cheapest skill-ups": ("Günstigste Skillpunkte", "Points de métier les moins chers", "Subidas de habilidad más baratas", "Subidas de habilidad más baratas", "Punti abilità più economici", "Pontos de perícia mais baratos", "Самые дешёвые очки навыка", "가장 저렴한 숙련도 상승", "最便宜的技能提升", "最便宜的技能提升"),
    "Materials for the top craft": ("Material für die beste Herstellung", "Composants pour la meilleure fabrication", "Materiales para la mejor fabricación", "Materiales para la mejor fabricación", "Materiali per la migliore creazione", "Materiais para a melhor criação", "Материалы для лучшего рецепта", "최상위 제작 재료", "首选制作的材料", "首選製作的材料"),
    "Buy missing mats at the AH": ("Fehlendes Material im AH kaufen", "Acheter les composants manquants à l'HV", "Comprar materiales que faltan en la CS", "Comprar materiales que faltan en la CS", "Compra i materiali mancanti all'asta", "Comprar materiais que faltam no leilão", "Купить недостающие материалы на аукционе", "부족한 재료를 경매장에서 구매", "在拍卖行购买缺少的材料", "在拍賣場購買缺少的材料"),
    "Crafts that sell for more than their materials": ("Herstellungen, die mehr als ihr Material einbringen", "Fabrications qui rapportent plus que leurs composants", "Fabricaciones que valen más que sus materiales", "Fabricaciones que valen más que sus materiales", "Creazioni che valgono più dei materiali", "Criações que valem mais que os materiais", "Изделия дороже своих материалов", "재료보다 비싸게 팔리는 제작품", "售价高于材料的制作", "售價高於材料的製作"),
    "Show skill-ups": ("Skillpunkte zeigen", "Afficher les points de métier", "Mostrar subidas de habilidad", "Mostrar subidas de habilidad", "Mostra punti abilità", "Mostrar pontos de perícia", "Показать очки навыка", "숙련도 상승 보기", "显示技能提升", "顯示技能提升"),
    "Show profitable crafts": ("Gewinnbringende Herstellungen", "Afficher les fabrications rentables", "Mostrar fabricaciones rentables", "Mostrar fabricaciones rentables", "Mostra creazioni redditizie", "Mostrar criações lucrativas", "Показать выгодные изделия", "수익성 있는 제작 보기", "显示赚钱的制作", "顯示賺錢的製作"),
    "Buy mats for the top craft": ("Material für die beste Herstellung kaufen", "Acheter les composants de la meilleure fabrication", "Comprar materiales para la mejor fabricación", "Comprar materiales para la mejor fabricación", "Compra materiali per la migliore creazione", "Comprar materiais para a melhor criação", "Купить материалы для лучшего изделия", "최상위 제작 재료 구매", "购买首选制作的材料", "購買首選製作的材料"),
    "Map pin": ("Kartenmarkierung", "Repère sur la carte", "Marcador del mapa", "Marcador del mapa", "Segnalino mappa", "Marcador do mapa", "Метка на карте", "지도 표시", "地图标记", "地圖標記"),
    "Next gathering stop": ("Nächster Sammelpunkt", "Prochain point de récolte", "Siguiente punto de recolección", "Siguiente punto de recolección", "Prossima tappa di raccolta", "Próximo ponto de coleta", "Следующая точка сбора", "다음 채집 지점", "下一个采集点", "下一個採集點"),
    "on another map": ("auf einer anderen Karte", "sur une autre carte", "en otro mapa", "en otro mapa", "su un'altra mappa", "em outro mapa", "на другой карте", "다른 지도에 있음", "在另一张地图", "在另一張地圖"),
    "You've arrived.": ("Du bist angekommen.", "Vous êtes arrivé.", "Has llegado.", "Llegaste.", "Sei arrivato.", "Você chegou.", "Вы на месте.", "도착했습니다.", "你已到达。", "你已抵達。"),
    "Waypoint cleared.": ("Wegpunkt entfernt.", "Point de passage effacé.", "Punto de ruta borrado.", "Punto de ruta borrado.", "Punto di passaggio rimosso.", "Ponto de rota removido.", "Точка маршрута убрана.", "경유지를 지웠습니다.", "已清除路径点。", "已清除路徑點。"),
    "Arrow points to": ("Pfeil zeigt auf", "La flèche pointe vers", "La flecha apunta a", "La flecha apunta a", "La freccia punta a", "A seta aponta para", "Стрелка указывает на", "화살표 목표", "箭头指向", "箭頭指向"),
    "Waypoint arrow (map pin, /ffway x y, next gathering stop)": ("Wegpunkt-Pfeil (Kartenmarkierung, /ffway x y, nächster Sammelpunkt)", "Flèche de navigation (repère, /ffway x y, prochain point de récolte)", "Flecha de ruta (marcador, /ffway x y, siguiente recolección)", "Flecha de ruta (marcador, /ffway x y, siguiente recolección)", "Freccia di navigazione (segnalino, /ffway x y, prossima raccolta)", "Seta de navegação (marcador, /ffway x y, próxima coleta)", "Стрелка-навигатор (метка, /ffway x y, следующий сбор)", "길 안내 화살표 (지도 표시, /ffway x y, 다음 채집)", "导航箭头（地图标记、/ffway x y、下一个采集点）", "導航箭頭（地圖標記、/ffway x y、下一個採集點）"),
    # --- desktop app
    "TRADING": ("HANDEL", "COMMERCE", "COMERCIO", "COMERCIO", "COMMERCIO", "COMÉRCIO", "ТОРГОВЛЯ", "거래", "交易", "交易"),
    "CHARACTER": ("CHARAKTER", "PERSONNAGE", "PERSONAJE", "PERSONAJE", "PERSONAGGIO", "PERSONAGEM", "ПЕРСОНАЖ", "캐릭터", "角色", "角色"),
    "APP": ("APP", "APPLI", "APP", "APP", "APP", "APP", "ПРИЛОЖЕНИЕ", "앱", "应用", "應用程式"),
    "Dashboard": ("Übersicht", "Tableau de bord", "Panel", "Panel", "Pannello", "Painel", "Сводка", "대시보드", "仪表盘", "儀表板"),
    "Deals": ("Angebote", "Affaires", "Ofertas", "Ofertas", "Affari", "Ofertas", "Сделки", "거래 기회", "好价", "好價"),
    "Inventory & selling": ("Bestand & Verkauf", "Stock et ventes", "Inventario y ventas", "Inventario y ventas", "Scorte e vendite", "Estoque e vendas", "Запасы и продажи", "재고 및 판매", "库存与出售", "庫存與出售"),
    "Trade history": ("Handelsverlauf", "Historique", "Historial", "Historial", "Cronologia", "Histórico", "История сделок", "거래 기록", "交易记录", "交易紀錄"),
    "What it learned": ("Gelerntes", "Apprentissage", "Lo aprendido", "Lo aprendido", "Cosa ha imparato", "O que aprendeu", "Чему научилось", "학습 결과", "学习结果", "學習結果"),
    "How to use": ("Anleitung", "Mode d'emploi", "Cómo usar", "Cómo usar", "Come si usa", "Como usar", "Как пользоваться", "사용법", "使用方法", "使用方法"),
    "About & updates": ("Info & Updates", "À propos et mises à jour", "Acerca de y actualizaciones", "Acerca de y actualizaciones", "Info e aggiornamenti", "Sobre e atualizações", "О программе и обновления", "정보 및 업데이트", "关于与更新", "關於與更新"),
    "Development": ("Entwicklung", "Développement", "Desarrollo", "Desarrollo", "Sviluppo", "Desenvolvimento", "Разработка", "개발", "开发", "開發"),
    "profit, stock and what to do next": ("Gewinn, Bestand und nächste Schritte", "profits, stock et prochaines étapes", "beneficios, inventario y qué hacer ahora", "ganancias, inventario y qué hacer ahora", "profitto, scorte e prossimi passi", "lucro, estoque e próximos passos", "прибыль, запасы и что делать дальше", "수익, 재고, 다음 할 일", "利润、库存和下一步", "利潤、庫存和下一步"),
    "everything worth buying, best first": ("alles, was sich lohnt, das Beste zuerst", "tout ce qui vaut l'achat, le meilleur d'abord", "todo lo que vale la pena comprar, lo mejor primero", "todo lo que vale la pena comprar, lo mejor primero", "tutto ciò che conviene comprare, il meglio prima", "tudo que vale a pena comprar, o melhor primeiro", "всё, что стоит купить, лучшее сверху", "구매할 가치가 있는 것, 좋은 순", "值得买的东西，最好的在前", "值得買的東西，最好的在前"),
    "what you hold and the prices the addon posts at": ("was du hast und zu welchem Preis das Addon einstellt", "ce que vous avez et les prix de mise en vente", "lo que tienes y los precios de publicación", "lo que tienes y los precios de publicación", "cosa possiedi e i prezzi di vendita", "o que você tem e os preços de anúncio", "что у вас есть и по какой цене выставлять", "보유 아이템과 등록 가격", "持有物品和上架价格", "持有物品和上架價格"),
    "every buy, post, sale and expiry": ("jeder Kauf, jede Auktion, jeder Verkauf", "chaque achat, mise en vente, vente et expiration", "cada compra, publicación, venta y caducidad", "cada compra, publicación, venta y vencimiento", "ogni acquisto, inserzione, vendita e scadenza", "cada compra, anúncio, venda e expiração", "каждая покупка, выставление, продажа и истечение", "모든 구매, 등록, 판매, 만료", "每次购买、上架、售出和过期", "每次購買、上架、售出和過期"),
    "sell chances, price accuracy and margin tuning": ("Verkaufschancen, Preisgenauigkeit und Margen", "chances de vente, précision des prix et marges", "probabilidad de venta, precisión y márgenes", "probabilidad de venta, precisión y márgenes", "probabilità di vendita, precisione e margini", "chance de venda, precisão e margens", "шансы продажи, точность цен и маржа", "판매 확률, 가격 정확도, 마진 조정", "售出几率、价格准确度和利润率调整", "售出機率、價格準確度和利潤率調整"),
    "your build, gear and next steps": ("deine Skillung, Ausrüstung und nächsten Schritte", "votre build, équipement et prochaines étapes", "tu build, equipo y próximos pasos", "tu build, equipo y próximos pasos", "la tua build, equipaggiamento e prossimi passi", "sua build, equipamento e próximos passos", "ваш билд, снаряжение и следующие шаги", "빌드, 장비, 다음 단계", "你的天赋、装备和下一步", "你的天賦、裝備和下一步"),
    "gold per hour by zone and resource": ("Gold pro Stunde nach Zone und Ressource", "or par heure par zone et ressource", "oro por hora por zona y recurso", "oro por hora por zona y recurso", "oro all'ora per zona e risorsa", "ouro por hora por zona e recurso", "золото в час по зонам и ресурсам", "지역 및 자원별 시간당 골드", "按区域和资源的每小时金币", "按區域和資源的每小時金幣"),
    "budget, speed rules and your WoW folder": ("Budget, Tempo-Regeln und WoW-Ordner", "budget, règles de vitesse et dossier WoW", "presupuesto, reglas de velocidad y carpeta de WoW", "presupuesto, reglas de velocidad y carpeta de WoW", "budget, regole di velocità e cartella di WoW", "orçamento, regras de velocidade e pasta do WoW", "бюджет, правила скорости и папка WoW", "예산, 판매 속도 규칙, WoW 폴더", "预算、速度规则和 WoW 文件夹", "預算、速度規則和 WoW 資料夾"),
    "the short version": ("die Kurzfassung", "la version courte", "la versión corta", "la versión corta", "la versione breve", "a versão curta", "коротко", "간단 요약", "简要说明", "簡要說明"),
    "news, changelog and updates": ("Neuigkeiten, Änderungen und Updates", "nouveautés, journal et mises à jour", "novedades, cambios y actualizaciones", "novedades, cambios y actualizaciones", "novità, modifiche e aggiornamenti", "novidades, alterações e atualizações", "новости, изменения и обновления", "소식, 변경 내역, 업데이트", "新闻、更新日志和更新", "新聞、更新日誌和更新"),
    "this week's plan, test checklist and roadmap": ("Wochenplan, Testliste und Fahrplan", "plan de la semaine, liste de tests et feuille de route", "plan semanal, lista de pruebas y hoja de ruta", "plan semanal, lista de pruebas y hoja de ruta", "piano settimanale, lista di test e roadmap", "plano da semana, lista de testes e roteiro", "план недели, список проверок и дорожная карта", "이번 주 계획, 테스트 목록, 로드맵", "本周计划、测试清单和路线图", "本週計畫、測試清單和路線圖"),
    "Import": ("Importieren", "Importer", "Importar", "Importar", "Importa", "Importar", "Импорт", "가져오기", "导入", "匯入"),
    "Build shopping list": ("Einkaufsliste erstellen", "Créer la liste d'achats", "Crear lista de compras", "Crear lista de compras", "Crea lista della spesa", "Criar lista de compras", "Составить список покупок", "구매 목록 만들기", "生成购物清单", "產生購物清單"),
    "realm:": ("Realm:", "royaume :", "reino:", "reino:", "reame:", "reino:", "мир:", "서버:", "服务器：", "伺服器："),
    "character:": ("Charakter:", "personnage :", "personaje:", "personaje:", "personaggio:", "personagem:", "персонаж:", "캐릭터:", "角色：", "角色："),
    "budget:": ("Budget:", "budget :", "presupuesto:", "presupuesto:", "budget:", "orçamento:", "бюджет:", "예산:", "预算：", "預算："),
    "Language changes apply after restarting the app.": ("Die Sprache wird nach einem Neustart der App übernommen.", "La langue s'applique après le redémarrage de l'appli.", "El idioma se aplica al reiniciar la app.", "El idioma se aplica al reiniciar la app.", "La lingua si applica dopo il riavvio dell'app.", "O idioma é aplicado ao reiniciar o app.", "Язык применится после перезапуска приложения.", "언어는 앱을 다시 시작하면 적용됩니다.", "语言将在重启应用后生效。", "語言將在重新啟動應用程式後生效。"),
}

_ORDER = [k for k in LANGUAGES if k != "enUS"]
TRANSLATIONS: dict[str, dict[str, str]] = {lang: {} for lang in _ORDER}
for _en, _row in _ROWS.items():
    assert len(_row) == len(_ORDER), _en
    for _lang, _text in zip(_ORDER, _row):
        TRANSLATIONS[_lang][_en] = _text

_current = "enUS"


def set_language(code: str | None):
    global _current
    _current = code if code in LANGUAGES else "enUS"


def language() -> str:
    return _current


def tr(text: str) -> str:
    """Translate English UI text into the selected language (English if not translated yet)."""
    if _current == "enUS":
        return text
    return TRANSLATIONS.get(_current, {}).get(text, text)

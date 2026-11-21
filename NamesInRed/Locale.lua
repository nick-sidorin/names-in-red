local _, addon = ...
-- Wins, losses, empty state, level label.
local strings = {
    enUS = { "Wins", "Losses", "No encounters recorded yet.", "Level" },
    ruRU = { "Победы", "Поражения", "Встреч пока нет.", "Уровень" },
    deDE = { "Siege", "Niederlagen", "Noch keine Begegnungen erfasst.", "Stufe" },
    frFR = { "Victoires", "Défaites", "Aucune rencontre enregistrée.", "Niveau" },
    esES = { "Victorias", "Derrotas", "Aún no hay encuentros registrados.", "Nivel" },
    itIT = { "Vittorie", "Sconfitte", "Nessun incontro registrato.", "Livello" },
    ptBR = { "Vitórias", "Derrotas", "Nenhum encontro registrado.", "Nível" },
    koKR = { "승리", "패배", "기록된 전투가 없습니다.", "레벨" },
    zhCN = { "胜利", "失败", "尚无交锋记录。", "等级" },
    zhTW = { "勝利", "失敗", "尚無交鋒紀錄。", "等級" },
}
strings.enGB = strings.enUS
strings.esMX = strings.esES
local text = strings[GetLocale()] or strings.enUS
addon.title = "Names in Red"
addon.L = { wins = text[1], losses = text[2], empty = text[3], level = text[4] }

-- Add button, dialog title, name label, win choice, loss choice, manual marker.
local manualStrings = {
    enUS = { "Add", "Add an encounter", "Full character name", "I killed them", "They killed me", "Added manually" },
    ruRU = { "Добавить", "Добавить стычку", "Полное имя персонажа", "Мой фраг", "Фраг противника", "Добавлено вручную" },
    deDE = { "Hinzufügen", "Begegnung hinzufügen", "Vollständiger Charaktername", "Ich habe gewonnen", "Ich wurde getötet", "Manuell hinzugefügt" },
    frFR = { "Ajouter", "Ajouter une rencontre", "Nom complet du personnage", "J’ai tué ce rival", "Ce rival m’a tué", "Ajouté manuellement" },
    esES = { "Añadir", "Añadir un encuentro", "Nombre completo del personaje", "Derroté al rival", "El rival me derrotó", "Añadido manualmente" },
    itIT = { "Aggiungi", "Aggiungi un incontro", "Nome completo del personaggio", "Ho ucciso il rivale", "Il rivale mi ha ucciso", "Aggiunto manualmente" },
    ptBR = { "Adicionar", "Adicionar um encontro", "Nome completo do personagem", "Matei o rival", "O rival me matou", "Adicionado manualmente" },
    koKR = { "추가", "전투 추가", "캐릭터 전체 이름", "내가 처치함", "상대에게 죽음", "수동으로 추가됨" },
    zhCN = { "添加", "添加交锋", "角色全名", "我击杀了对手", "对手击杀了我", "手动添加" },
    zhTW = { "新增", "新增交鋒", "角色全名", "我擊殺了對手", "對手擊殺了我", "手動新增" },
}
manualStrings.enGB = manualStrings.enUS
manualStrings.esMX = manualStrings.esES
local manual = manualStrings[GetLocale()] or manualStrings.enUS
addon.L.add, addon.L.addTitle, addon.L.fullName = manual[1], manual[2], manual[3]
addon.L.win, addon.L.loss, addon.L.manual = manual[4], manual[5], manual[6]

local searchStrings = {
    enUS = { "No matching rivals.", "Delete the profile for %s and its personal history?" },
    ruRU = { "Соперники не найдены.", "Удалить профиль %s и личную историю стычек с этим противником?" },
    deDE = { "Keine passenden Rivalen.", "Das Profil von %s und die persönlichen Begegnungen löschen?" },
    frFR = { "Aucun rival correspondant.", "Supprimer le profil de %s et l’historique personnel associé ?" },
    esES = { "No se encontraron rivales.", "¿Eliminar el perfil de %s y su historial personal?" },
    itIT = { "Nessun rivale corrispondente.", "Eliminare il profilo di %s e la relativa cronologia personale?" },
    ptBR = { "Nenhum rival encontrado.", "Excluir o perfil de %s e o histórico pessoal com esse rival?" },
    koKR = { "일치하는 라이벌이 없습니다.", "%s의 프로필과 이 상대와의 개인 기록을 삭제하시겠습니까?" },
    zhCN = { "未找到匹配的对手。", "删除%s的资料以及与该对手的个人交锋记录？" },
    zhTW = { "未找到符合的對手。", "刪除%s的資料以及與該對手的個人交鋒紀錄？" },
}
searchStrings.enGB = searchStrings.enUS
searchStrings.esMX = searchStrings.esES
local search = searchStrings[GetLocale()] or searchStrings.enUS
addon.L.noMatches, addon.L.deleteConfirm = search[1], search[2]

local scoreStrings = {
    enUS = { "Personal score", "My victory", "My defeat", "Skirmish", "Open skirmish" },
    ruRU = { "Личный счёт", "Моя победа", "Моё поражение", "Стычка", "Открыть стычку" },
    deDE = { "Persönliche Bilanz", "Mein Sieg", "Meine Niederlage", "Gefecht", "Gefecht öffnen" },
    frFR = { "Bilan personnel", "Ma victoire", "Ma défaite", "Escarmouche", "Voir l’escarmouche" },
    esES = { "Balance personal", "Mi victoria", "Mi derrota", "Escaramuza", "Ver escaramuza" },
    itIT = { "Bilancio personale", "La mia vittoria", "La mia sconfitta", "Schermaglia", "Vedi schermaglia" },
    ptBR = { "Placar pessoal", "Minha vitória", "Minha derrota", "Escaramuça", "Ver escaramuça" },
    koKR = { "개인 전적", "나의 승리", "나의 패배", "교전", "교전 보기" },
    zhCN = { "个人战绩", "我的胜利", "我的失败", "交锋", "查看交锋" },
    zhTW = { "個人戰績", "我的勝利", "我的失敗", "交鋒", "查看交鋒" },
}
scoreStrings.enGB = scoreStrings.enUS
scoreStrings.esMX = scoreStrings.esES
addon.L.personalScore, addon.L.winTooltip, addon.L.lossTooltip, addon.L.skirmish, addon.L.openSkirmish =
    unpack(scoreStrings[GetLocale()] or scoreStrings.enUS)

-- Info tab, history tab, last encounter, map action, unknown location, levels, map error, empty history.
local encounterStrings = {
    enUS = { "Information", "Skirmishes", "Last skirmish", "Show on map", "Location unknown", "My level", "Opponent’s level", "The map waypoint could not be placed.", "No skirmishes recorded." },
    ruRU = { "Информация", "Стычки", "Последняя стычка", "Показать на карте", "Место неизвестно", "Мой уровень", "Уровень противника", "Не удалось поставить метку на карте.", "Стычек пока нет." },
    deDE = { "Informationen", "Gefechte", "Letztes Gefecht", "Auf Karte zeigen", "Unbekannter Ort", "Meine Stufe", "Stufe des Gegners", "Die Kartenmarkierung konnte nicht gesetzt werden.", "Noch keine Gefechte erfasst." },
    frFR = { "Informations", "Escarmouches", "Dernière escarmouche", "Voir sur la carte", "Lieu inconnu", "Mon niveau", "Niveau de l’adversaire", "Impossible de placer le repère sur la carte.", "Aucune escarmouche enregistrée." },
    esES = { "Información", "Escaramuzas", "Última escaramuza", "Mostrar en el mapa", "Lugar desconocido", "Mi nivel", "Nivel del oponente", "No se pudo colocar el marcador en el mapa.", "No hay escaramuzas registradas." },
    itIT = { "Informazioni", "Schermaglie", "Ultima schermaglia", "Mostra sulla mappa", "Luogo sconosciuto", "Il mio livello", "Livello dell’avversario", "Impossibile posizionare l’indicatore sulla mappa.", "Nessuna schermaglia registrata." },
    ptBR = { "Informações", "Escaramuças", "Última escaramuça", "Mostrar no mapa", "Local desconhecido", "Meu nível", "Nível do adversário", "Não foi possível posicionar o marcador no mapa.", "Nenhuma escaramuça registrada." },
    koKR = { "정보", "교전 기록", "최근 교전", "지도에 표시", "알 수 없는 위치", "내 레벨", "상대 레벨", "지도에 위치를 표시할 수 없습니다.", "기록된 교전이 없습니다." },
    zhCN = { "信息", "交锋", "最近一次交锋", "在地图上显示", "地点未知", "我的等级", "对手等级", "无法在地图上设置标记。", "暂无交锋记录。" },
    zhTW = { "資訊", "交鋒", "最近一次交鋒", "在地圖上顯示", "地點未知", "我的等級", "對手等級", "無法在地圖上設定標記。", "暫無交鋒紀錄。" },
}
encounterStrings.enGB = encounterStrings.enUS
encounterStrings.esMX = encounterStrings.esES
local encounter = encounterStrings[GetLocale()] or encounterStrings.enUS
addon.L.infoTab, addon.L.historyTab, addon.L.latestEncounter, addon.L.showOnMap = unpack(encounter, 1, 4)
addon.L.unknownLocation, addon.L.myLevel, addon.L.rivalLevel, addon.L.waypointError = unpack(encounter, 5, 8)
addon.L.noSkirmishes = encounter[9]
local russian = GetLocale() == "ruRU"
addon.L.attackers = russian and "Нападавшие" or "Attackers"
addon.L.finishingBlow = russian and "%s (добивающий удар)" or "%s (finishing blow)"

local bookViews = {
    enUS = { "Rivals", "Skirmish history", "Unknown rival" },
    ruRU = { "Противники", "История стычек", "Неизвестный противник" },
    deDE = { "Rivalen", "Gefechtsverlauf", "Unbekannter Rivale" },
    frFR = { "Rivaux", "Historique des escarmouches", "Rival inconnu" },
    esES = { "Rivales", "Historial de escaramuzas", "Rival desconocido" },
    itIT = { "Rivali", "Cronologia delle schermaglie", "Rivale sconosciuto" },
    ptBR = { "Rivais", "Histórico de escaramuças", "Rival desconhecido" },
    koKR = { "상대", "전체 교전 기록", "알 수 없는 상대" },
    zhCN = { "对手", "交锋记录", "未知对手" },
    zhTW = { "對手", "交鋒紀錄", "未知對手" },
}
bookViews.enGB = bookViews.enUS
bookViews.esMX = bookViews.esES
addon.L.rivalsView, addon.L.recentView, addon.L.unknownRival = unpack(bookViews[GetLocale()] or bookViews.enUS)

-- Side labels, incomplete roster, timeline and anonymous participant.
local skirmishStrings = {
    enUS = { "Allies", "Opponents", "Partial roster", "Finishing blows", "Unknown player" },
    ruRU = { "Союзники", "Противники", "Неполный состав", "Добивающие удары", "Неизвестный игрок" },
    deDE = { "Verbündete", "Gegner", "Unvollständige Besetzung", "Todesstöße", "Unbekannter Spieler" },
    frFR = { "Alliés", "Adversaires", "Composition partielle", "Coups fatals", "Joueur inconnu" },
    esES = { "Aliados", "Oponentes", "Lista incompleta", "Golpes de gracia", "Jugador desconocido" },
    itIT = { "Alleati", "Avversari", "Formazione parziale", "Colpi di grazia", "Giocatore sconosciuto" },
    ptBR = { "Aliados", "Adversários", "Lista incompleta", "Golpes fatais", "Jogador desconhecido" },
    koKR = { "아군", "적군", "일부 참가자 확인", "결정타", "알 수 없는 플레이어" },
    zhCN = { "盟友", "对手", "阵容不完整", "最后一击", "未知玩家" },
    zhTW = { "盟友", "對手", "陣容不完整", "最後一擊", "未知玩家" },
}
skirmishStrings.enGB = skirmishStrings.enUS
skirmishStrings.esMX = skirmishStrings.esES
addon.L.alliedSide, addon.L.enemySide, addon.L.partialRoster, addon.L.finishingBlows, addon.L.unknownPlayer =
    unpack(skirmishStrings[GetLocale()] or skirmishStrings.enUS)

local minimapHints = {
    enUS = "Left-click — open the journal\nDrag — move the icon",
    ruRU = "ЛКМ — открыть журнал\nПеретащи — переместить значок",
    deDE = "Linksklick — Journal öffnen\nZiehen — Symbol verschieben",
    frFR = "Clic gauche — ouvrir le journal\nGlisser — déplacer l’icône",
    esES = "Clic izquierdo — abrir el diario\nArrastra — mover el icono",
    itIT = "Clic sinistro — apri il diario\nTrascina — sposta l’icona",
    ptBR = "Clique esquerdo — abrir o diário\nArraste — mover o ícone",
    koKR = "왼쪽 클릭 — 기록 열기\n드래그 — 아이콘 이동",
    zhCN = "左键点击 — 打开日志\n拖动 — 移动图标",
    zhTW = "按左鍵 — 開啟日誌\n拖曳 — 移動圖示",
}
minimapHints.enGB = minimapHints.enUS
minimapHints.esMX = minimapHints.esES
addon.L.minimapHint = minimapHints[GetLocale()] or minimapHints.enUS

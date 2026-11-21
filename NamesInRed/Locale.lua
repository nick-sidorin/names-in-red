local _, addon = ...
-- Wins, losses, empty state, level label.
local strings = {
    enUS = { "Skirmishes won", "Skirmishes lost", "No encounters recorded yet.", "Level" },
    ruRU = { "Выиграно стычек", "Проиграно стычек", "Встреч пока нет.", "Уровень" },
    deDE = { "Gefechte gewonnen", "Gefechte verloren", "Noch keine Begegnungen erfasst.", "Stufe" },
    frFR = { "Escarmouches gagnées", "Escarmouches perdues", "Aucune rencontre enregistrée.", "Niveau" },
    esES = { "Escaramuzas ganadas", "Escaramuzas perdidas", "Aún no hay encuentros registrados.", "Nivel" },
    itIT = { "Schermaglie vinte", "Schermaglie perse", "Nessun incontro registrato.", "Livello" },
    ptBR = { "Escaramuças vencidas", "Escaramuças perdidas", "Nenhum encontro registrado.", "Nível" },
    koKR = { "교전 승리", "교전 패배", "기록된 전투가 없습니다.", "레벨" },
    zhCN = { "交锋胜场", "交锋负场", "尚无交锋记录。", "等级" },
    zhTW = { "交鋒勝場", "交鋒敗場", "尚無交鋒紀錄。", "等級" },
}
strings.enGB = strings.enUS
strings.esMX = strings.esES
local text = strings[GetLocale()] or strings.enUS
addon.title = "Names in Red"
addon.L = { wins = text[1], losses = text[2], empty = text[3], level = text[4] }

-- Add button, dialog title, name label, win choice, loss choice, manual marker.
local manualStrings = {
    enUS = { "Add", "Add an encounter", "Full character name", "We won", "We lost", "Added manually" },
    ruRU = { "Добавить", "Добавить стычку", "Полное имя персонажа", "Мы победили", "Мы проиграли", "Добавлено вручную" },
    deDE = { "Hinzufügen", "Begegnung hinzufügen", "Vollständiger Charaktername", "Wir haben gewonnen", "Wir haben verloren", "Manuell hinzugefügt" },
    frFR = { "Ajouter", "Ajouter une rencontre", "Nom complet du personnage", "Nous avons gagné", "Nous avons perdu", "Ajouté manuellement" },
    esES = { "Añadir", "Añadir un encuentro", "Nombre completo del personaje", "Ganamos", "Perdimos", "Añadido manualmente" },
    itIT = { "Aggiungi", "Aggiungi un incontro", "Nome completo del personaggio", "Abbiamo vinto", "Abbiamo perso", "Aggiunto manualmente" },
    ptBR = { "Adicionar", "Adicionar um encontro", "Nome completo do personagem", "Vencemos", "Perdemos", "Adicionado manualmente" },
    koKR = { "추가", "전투 추가", "캐릭터 전체 이름", "아군 승리", "아군 패배", "수동으로 추가됨" },
    zhCN = { "添加", "添加交锋", "角色全名", "我方获胜", "我方落败", "手动添加" },
    zhTW = { "新增", "新增交鋒", "角色全名", "我方獲勝", "我方落敗", "手動新增" },
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
    enUS = { "Skirmish stats", "Victory", "Defeat", "Open skirmish", "Honorable kills", "Honor", "Skirmish outcome unknown" },
    ruRU = { "Статистика встреч", "Победа", "Поражение", "Открыть стычку", "Почётные победы", "Честь", "Исход стычки неизвестен" },
    deDE = { "Gefechtsstatistik", "Sieg", "Niederlage", "Gefecht öffnen", "Ehrenhafte Siege", "Ehre", "Gefechtsausgang unbekannt" },
    frFR = { "Bilan des escarmouches", "Victoire", "Défaite", "Voir l’escarmouche", "Victoires honorables", "Honneur", "Issue de l’escarmouche inconnue" },
    esES = { "Estadísticas de escaramuza", "Victoria", "Derrota", "Ver escaramuza", "Muertes con honor", "Honor", "Resultado de la escaramuza desconocido" },
    itIT = { "Statistiche schermaglie", "Vittoria", "Sconfitta", "Vedi schermaglia", "Uccisioni onorevoli", "Onore", "Esito della schermaglia sconosciuto" },
    ptBR = { "Estatísticas de escaramuças", "Vitória", "Derrota", "Ver escaramuça", "Abates honrosos", "Honra", "Resultado da escaramuça desconhecido" },
    koKR = { "교전 통계", "승리", "패배", "교전 보기", "명예 승수", "명예", "교전 결과 미확인" },
    zhCN = { "交锋统计", "胜利", "失败", "查看交锋", "荣誉击杀", "荣誉", "交锋结果未知" },
    zhTW = { "交鋒統計", "勝利", "失敗", "查看交鋒", "榮譽擊殺", "榮譽", "交鋒結果未知" },
}
scoreStrings.enGB = scoreStrings.enUS
scoreStrings.esMX = scoreStrings.esES
addon.L.personalScore, addon.L.winTooltip, addon.L.lossTooltip, addon.L.openSkirmish =
    unpack(scoreStrings[GetLocale()] or scoreStrings.enUS, 1, 4)
addon.L.honorableKills, addon.L.honor, addon.L.unknownOutcome =
    unpack(scoreStrings[GetLocale()] or scoreStrings.enUS, 5)

local portraitOutcomeStrings = {
    enUS = "Died",
    ruRU = "Погиб",
    deDE = "Gestorben",
    frFR = "Est mort",
    esES = "Murió",
    itIT = "È morto",
    ptBR = "Morreu",
    koKR = "사망",
    zhCN = "死亡",
    zhTW = "死亡",
}
portraitOutcomeStrings.enGB = portraitOutcomeStrings.enUS
portraitOutcomeStrings.esMX = portraitOutcomeStrings.esES
addon.L.portraitDeath = portraitOutcomeStrings[GetLocale()] or portraitOutcomeStrings.enUS

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
    enUS = { "Allies", "Opponents", "Full roster unconfirmed", "Finishing blows", "Unknown player" },
    ruRU = { "Союзники", "Противники", "Полный состав не подтверждён", "Добивающие удары", "Неизвестный игрок" },
    deDE = { "Verbündete", "Gegner", "Vollständige Besetzung nicht bestätigt", "Todesstöße", "Unbekannter Spieler" },
    frFR = { "Alliés", "Adversaires", "Effectif complet non confirmé", "Coups fatals", "Joueur inconnu" },
    esES = { "Aliados", "Oponentes", "Lista completa sin confirmar", "Golpes de gracia", "Jugador desconocido" },
    itIT = { "Alleati", "Avversari", "Formazione completa non confermata", "Colpi di grazia", "Giocatore sconosciuto" },
    ptBR = { "Aliados", "Adversários", "Lista completa não confirmada", "Golpes fatais", "Jogador desconhecido" },
    koKR = { "아군", "적군", "전체 참가자 미확인", "결정타", "알 수 없는 플레이어" },
    zhCN = { "盟友", "对手", "完整阵容未确认", "最后一击", "未知玩家" },
    zhTW = { "盟友", "對手", "完整陣容未確認", "最後一擊", "未知玩家" },
}
skirmishStrings.enGB = skirmishStrings.enUS
skirmishStrings.esMX = skirmishStrings.esES
addon.L.alliedSide, addon.L.enemySide, addon.L.partialRoster, addon.L.finishingBlows, addon.L.unknownPlayer =
    unpack(skirmishStrings[GetLocale()] or skirmishStrings.enUS)

local rosterHints = {
    enUS = "This record lists known participants. The full size of either side is unconfirmed.",
    ruRU = "Здесь показаны известные участники. Точное число игроков на каждой стороне неизвестно.",
    deDE = "Dieser Eintrag zeigt die bekannten Teilnehmer. Die vollständige Größe der beiden Seiten ist unbekannt.",
    frFR = "Cette fiche présente les participants connus. L’effectif complet de chaque camp reste inconnu.",
    esES = "Este registro muestra a los participantes conocidos. Se desconoce el tamaño total de cada bando.",
    itIT = "Questa scheda mostra i partecipanti noti. Il numero totale di giocatori per schieramento è sconosciuto.",
    ptBR = "Este registro mostra os participantes conhecidos. O tamanho total de cada lado é desconhecido.",
    koKR = "확인된 참가자만 표시합니다. 양측의 전체 인원은 확인되지 않았습니다.",
    zhCN = "这条记录仅显示已知参与者。双方的总人数尚未确认。",
    zhTW = "這筆紀錄僅顯示已知參與者。雙方的總人數尚未確認。",
}
rosterHints.enGB = rosterHints.enUS
rosterHints.esMX = rosterHints.esES
addon.L.partialRosterHint = rosterHints[GetLocale()] or rosterHints.enUS

local minimapHints = {
    enUS = "Left-click — open the journal\nRight-click — open settings\nDrag — move the icon",
    ruRU = "ЛКМ — открыть журнал\nПКМ — открыть настройки\nПеретащи — переместить значок",
    deDE = "Linksklick — Journal öffnen\nRechtsklick — Einstellungen öffnen\nZiehen — Symbol verschieben",
    frFR = "Clic gauche — ouvrir le journal\nClic droit — ouvrir les paramètres\nGlisser — déplacer l’icône",
    esES = "Clic izquierdo — abrir el diario\nClic derecho — abrir los ajustes\nArrastra — mover el icono",
    itIT = "Clic sinistro — apri il diario\nClic destro — apri le impostazioni\nTrascina — sposta l’icona",
    ptBR = "Clique esquerdo — abrir o diário\nClique direito — abrir as configurações\nArraste — mover o ícone",
    koKR = "왼쪽 클릭 — 기록 열기\n오른쪽 클릭 — 설정 열기\n드래그 — 아이콘 이동",
    zhCN = "左键点击 — 打开日志\n右键点击 — 打开设置\n拖动 — 移动图标",
    zhTW = "按左鍵 — 開啟日誌\n按右鍵 — 開啟設定\n拖曳 — 移動圖示",
}
minimapHints.enGB = minimapHints.enUS
minimapHints.esMX = minimapHints.esES
addon.L.minimapHint = minimapHints[GetLocale()] or minimapHints.enUS

local settingsStrings = {
    enUS = {
        "Show icons above players", "Show information in unit tooltips", "Reset data",
        "Delete all rivals, skirmishes and diagnostic logs for this character?",
        "Report an issue", "Copy this link and open it in your browser to report an issue on GitHub.",
    },
    ruRU = {
        "Показывать значки над головой", "Показывать информацию во всплывающей подсказке", "Сбросить данные",
        "Удалить всех противников, стычки и диагностические записи этого персонажа?",
        "Сообщить о проблеме", "Скопируй ссылку и открой её в браузере, чтобы сообщить о проблеме на GitHub.",
    },
    deDE = {
        "Symbole über Spielern anzeigen", "Infos in Einheitentooltips anzeigen", "Daten zurücksetzen",
        "Alle Rivalen, Gefechte und Diagnoseprotokolle dieses Charakters löschen?",
        "Problem melden", "Kopiere den Link und öffne ihn im Browser, um ein Problem auf GitHub zu melden.",
    },
    frFR = {
        "Afficher les icônes au-dessus des joueurs", "Afficher les infos dans les infobulles", "Réinitialiser les données",
        "Supprimer tous les rivaux, les escarmouches et les journaux de diagnostic de ce personnage ?",
        "Signaler un problème", "Copiez ce lien et ouvrez-le dans votre navigateur pour signaler un problème sur GitHub.",
    },
    esES = {
        "Mostrar iconos sobre los jugadores", "Mostrar información en las descripciones emergentes", "Restablecer datos",
        "¿Eliminar todos los rivales, escaramuzas y registros de diagnóstico de este personaje?",
        "Informar de un problema", "Copia este enlace y ábrelo en el navegador para informar de un problema en GitHub.",
    },
    itIT = {
        "Mostra le icone sopra i giocatori", "Mostra le informazioni nei tooltip", "Reimposta i dati",
        "Eliminare tutti i rivali, le schermaglie e i registri diagnostici di questo personaggio?",
        "Segnala un problema", "Copia il link e aprilo nel browser per segnalare un problema su GitHub.",
    },
    ptBR = {
        "Mostrar ícones acima dos jogadores", "Mostrar informações nas dicas de interface", "Redefinir dados",
        "Excluir todos os rivais, escaramuças e registros de diagnóstico deste personagem?",
        "Relatar um problema", "Copie este link e abra-o no navegador para relatar um problema no GitHub.",
    },
    koKR = {
        "플레이어 위에 아이콘 표시", "툴팁에 정보 표시", "데이터 초기화",
        "이 캐릭터의 모든 상대, 교전 기록 및 진단 로그를 삭제하시겠습니까?",
        "문제 신고", "이 링크를 복사해 브라우저에서 열고 GitHub에 문제를 신고하세요.",
    },
    zhCN = {
        "在玩家头顶显示图标", "在单位鼠标提示中显示信息", "重置数据",
        "删除此角色的所有对手、交锋记录和诊断日志？",
        "报告问题", "复制此链接并在浏览器中打开，即可在 GitHub 报告问题。",
    },
    zhTW = {
        "在玩家頭頂顯示圖示", "在單位提示中顯示資訊", "重設資料",
        "刪除此角色的所有對手、交鋒紀錄及診斷日誌？",
        "回報問題", "複製此連結並在瀏覽器中開啟，即可在 GitHub 回報問題。",
    },
}
settingsStrings.enGB = settingsStrings.enUS
settingsStrings.esMX = settingsStrings.esES
addon.L.showNameplateIcons, addon.L.showUnitTooltip, addon.L.resetData, addon.L.resetDataConfirm,
    addon.L.reportIssue, addon.L.reportIssueLink = unpack(settingsStrings[GetLocale()] or settingsStrings.enUS)

local _, addon = ...
-- Kills, deaths, empty state, level label.
local strings = {
    enUS = { "Kills", "Deaths", "No encounters recorded yet.", "Level" },
    ruRU = { "Победы", "Смерти", "Встреч пока нет.", "Уровень" },
    deDE = { "Siege", "Tode", "Noch keine Begegnungen erfasst.", "Stufe" },
    frFR = { "Victoires", "Morts", "Aucune rencontre enregistrée.", "Niveau" },
    esES = { "Victorias", "Muertes", "Aún no hay encuentros registrados.", "Nivel" },
    itIT = { "Vittorie", "Morti", "Nessun incontro registrato.", "Livello" },
    ptBR = { "Vitórias", "Mortes", "Nenhum encontro registrado.", "Nível" },
    koKR = { "승리", "죽음", "기록된 전투가 없습니다.", "레벨" },
    zhCN = { "击杀", "死亡", "尚无交锋记录。", "等级" },
    zhTW = { "擊殺", "死亡", "尚無交鋒紀錄。", "等級" },
}
strings.enGB = strings.enUS
strings.esMX = strings.esES
local text = strings[GetLocale()] or strings.enUS
addon.title = "Names in Red"
addon.L = { kills = text[1], deaths = text[2], empty = text[3], level = text[4] }

-- Add button, dialog title, name label, win choice, loss choice, manual marker.
local manualStrings = {
    enUS = { "Add", "Add an encounter", "Full character name", "I killed them", "They killed me", "Added manually" },
    ruRU = { "Добавить", "Добавить встречу", "Полное имя персонажа", "Я убил соперника", "Соперник убил меня", "Добавлено вручную" },
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
    enUS = { "No matching rivals.", "Delete %s and all encounters with this rival?" },
    ruRU = { "Соперники не найдены.", "Удалить %s и все встречи с этим соперником?" },
    deDE = { "Keine passenden Rivalen.", "%s und alle Begegnungen mit diesem Rivalen löschen?" },
    frFR = { "Aucun rival correspondant.", "Supprimer %s et toutes les rencontres avec ce rival ?" },
    esES = { "No se encontraron rivales.", "¿Eliminar a %s y todos los encuentros con este rival?" },
    itIT = { "Nessun rivale corrispondente.", "Eliminare %s e tutti gli incontri con questo rivale?" },
    ptBR = { "Nenhum rival encontrado.", "Excluir %s e todos os encontros com esse rival?" },
    koKR = { "일치하는 라이벌이 없습니다.", "%s 및 이 라이벌과의 모든 기록을 삭제하시겠습니까?" },
    zhCN = { "未找到匹配的对手。", "删除%s及与此对手的全部交锋记录？" },
    zhTW = { "未找到符合的對手。", "刪除%s及與此對手的所有交鋒記錄？" },
}
searchStrings.enGB = searchStrings.enUS
searchStrings.esMX = searchStrings.esES
local search = searchStrings[GetLocale()] or searchStrings.enUS
addon.L.noMatches, addon.L.deleteConfirm = search[1], search[2]

local statisticsStrings = {
    enUS = { "Statistics:", "My wins against this player", "This player’s wins against me" },
    ruRU = { "Статистика:", "Мои победы над игроком", "Победы игрока надо мной" },
    deDE = { "Statistik:", "Meine Siege gegen diesen Spieler", "Siege dieses Spielers gegen mich" },
    frFR = { "Statistiques :", "Mes victoires contre ce joueur", "Les victoires de ce joueur contre moi" },
    esES = { "Estadísticas:", "Mis victorias contra este jugador", "Victorias de este jugador contra mí" },
    itIT = { "Statistiche:", "Le mie vittorie contro questo giocatore", "Le vittorie di questo giocatore contro di me" },
    ptBR = { "Estatísticas:", "Minhas vitórias contra este jogador", "Vitórias deste jogador contra mim" },
    koKR = { "통계:", "이 플레이어에게 거둔 승리", "이 플레이어가 나에게 거둔 승리" },
    zhCN = { "统计：", "我战胜该玩家的次数", "该玩家战胜我的次数" },
    zhTW = { "統計：", "我戰勝該玩家的次數", "該玩家戰勝我的次數" },
}
statisticsStrings.enGB = statisticsStrings.enUS
statisticsStrings.esMX = statisticsStrings.esES
local statistics = statisticsStrings[GetLocale()] or statisticsStrings.enUS
addon.L.statistics, addon.L.winTooltip, addon.L.lossTooltip = statistics[1], statistics[2], statistics[3]

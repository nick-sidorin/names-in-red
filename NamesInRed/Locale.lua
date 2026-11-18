local _, addon = ...
-- Book title, kills, deaths, empty state, level label.
local strings = {
    enUS = { "Rival Book", "Kills", "Deaths", "No encounters recorded yet.", "Level" },
    ruRU = { "Книга соперников", "Победы", "Смерти", "Встреч пока нет.", "Уровень" },
    deDE = { "Rivalenbuch", "Siege", "Tode", "Noch keine Begegnungen erfasst.", "Stufe" },
    frFR = { "Registre des rivaux", "Victoires", "Morts", "Aucune rencontre enregistrée.", "Niveau" },
    esES = { "Libro de rivales", "Victorias", "Muertes", "Aún no hay encuentros registrados.", "Nivel" },
    itIT = { "Registro dei rivali", "Vittorie", "Morti", "Nessun incontro registrato.", "Livello" },
    ptBR = { "Livro de rivais", "Vitórias", "Mortes", "Nenhum encontro registrado.", "Nível" },
    koKR = { "라이벌 기록부", "승리", "죽음", "기록된 전투가 없습니다.", "레벨" },
    zhCN = { "宿敌名册", "击杀", "死亡", "尚无交锋记录。", "等级" },
    zhTW = { "宿敵名冊", "擊殺", "死亡", "尚無交鋒紀錄。", "等級" },
}
strings.enGB = strings.enUS
strings.esMX = strings.esES
local text = strings[GetLocale()] or strings.enUS
addon.L = { book = text[1], kills = text[2], deaths = text[3], empty = text[4], level = text[5] }

-- Add button, dialog title, name label, win choice, loss choice, manual marker.
local manualStrings = {
    enUS = { "Add", "Add an encounter", "Full character name", "I killed them", "They killed me", "Manual entry" },
    ruRU = { "Добавить", "Добавить встречу", "Полное имя персонажа", "Я убил соперника", "Соперник убил меня", "Ручная запись" },
    deDE = { "Hinzufügen", "Begegnung hinzufügen", "Vollständiger Charaktername", "Ich habe gewonnen", "Ich wurde getötet", "Manueller Eintrag" },
    frFR = { "Ajouter", "Ajouter une rencontre", "Nom complet du personnage", "J’ai tué ce rival", "Ce rival m’a tué", "Saisie manuelle" },
    esES = { "Añadir", "Añadir un encuentro", "Nombre completo del personaje", "Derroté al rival", "El rival me derrotó", "Registro manual" },
    itIT = { "Aggiungi", "Aggiungi un incontro", "Nome completo del personaggio", "Ho ucciso il rivale", "Il rivale mi ha ucciso", "Voce manuale" },
    ptBR = { "Adicionar", "Adicionar um encontro", "Nome completo do personagem", "Matei o rival", "O rival me matou", "Registro manual" },
    koKR = { "추가", "전투 추가", "캐릭터 전체 이름", "내가 처치함", "상대에게 죽음", "수동 기록" },
    zhCN = { "添加", "添加交锋", "角色全名", "我击杀了对手", "对手击杀了我", "手动记录" },
    zhTW = { "新增", "新增交鋒", "角色全名", "我擊殺了對手", "對手擊殺了我", "手動記錄" },
}
manualStrings.enGB = manualStrings.enUS
manualStrings.esMX = manualStrings.esES
local manual = manualStrings[GetLocale()] or manualStrings.enUS
addon.L.add, addon.L.addTitle, addon.L.fullName = manual[1], manual[2], manual[3]
addon.L.win, addon.L.loss, addon.L.manual = manual[4], manual[5], manual[6]

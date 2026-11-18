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

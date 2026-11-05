-- =============================================================================
-- Random given names of the time and place, for the name screen. They come from the
-- people of the game, in its Czech text (text_ui_soul.xml). All in lower case: Typing
-- capitalizes when it shows them.
-- =============================================================================
local ML = MedievalLife

ML.Names = {}
local Names = ML.Names

Names.MAN = 1
Names.WOMAN = 2

Names.GIVEN = {
	[Names.MAN] = {
		"adam", "albrecht", "albík", "arnošt", "bartoš", "beneš", "boček", "bořut", "bureš", "ctibor",
		"ctirad", "drslav", "hanuš", "havel", "heřman", "hynek", "chval", "jakub", "jakeš", "jan",
		"janek", "jaroslav", "jíra", "kašpar", "konrád", "kuneš", "lukáš", "marek", "markvart", "martin",
		"matěj", "matouš", "mikeš", "mikuláš", "mysliboř", "odolen", "oldřich", "ondřej", "pešek", "petr",
		"radmil", "stibor", "stislav", "tomáš", "ulrich", "vašek", "vencl", "zbyněk", "zdeněk",
	},
	[Names.WOMAN] = {
		"adéla", "adléta", "anežka", "anna", "barbora", "běta", "berta", "božena", "dorota", "doubravka",
		"drahomíra", "eliška", "hanka", "helena", "hedvika", "jitka", "judita", "kateřina", "klára", "kristýna",
		"ludmila", "magdaléna", "mandelina", "markéta", "marie", "matylda", "milada", "milena", "mlada", "pavlena",
		"svatava", "vendula",
	},
}

-- The tanned models come from Hungary, next to Bohemia: the Czech text of the game has no names for them.
Names.TANNED = {
	[Names.MAN] = { "ambrus", "balázs", "bálint", "gergely", "imre", "istván", "jános", "lászló", "mátyás", "miklós" },
	[Names.WOMAN] = { "ágnes", "borbála", "dorottya", "erzsébet", "ilona", "katalin", "margit", "orsolya", "piroska", "zsófia" },
}

-- The Romani faces. The men are heads of Romani households in a charter of Alexander the Good, prince of Moldavia, of
-- 1428, with Grozav, of another of 1436, and Karol, of the nomads' camp of the game. No record of the time names Romani
-- women, and the Roma took the names of the land where they lived: these are women's names of the 15th-century
-- documents of Moldavia and Wallachia. Romanian letters such as s with comma are left out.
Names.ROMANI = {
	[Names.MAN] = { "coman", "marco", "sinata", "costea", "nan", "cernat", "danciul", "giurgiu", "golea", "cojan",
		"voicu", "zavid", "grozav", "karol" },
	[Names.WOMAN] = { "stana", "stanca", "neaga", "rada", "voica", "dobra", "marena", "ileana", "anca", "mara",
		"tudora", "calea", "cerna", "grada" },
}

Names.BY_ETHNICITY = { czech = Names.GIVEN, hungarian = Names.TANNED, romani = Names.ROMANI }

function Names.Random(gender, ethnicity)
	local list = (Names.BY_ETHNICITY[ethnicity] or Names.GIVEN)[gender]
	return list[math.random(#list)]
end

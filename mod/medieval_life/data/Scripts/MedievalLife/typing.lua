-- =============================================================================
-- Typing the name of the new character. The game has no text field in any screen, so
-- a temporary action map takes one key at a time, over the open dialog, like the
-- barber screen does (Libs/Config/ml_typing.xml), and the black screen shows the text.
-- Keys are physical keys: Lua gets no letters, so the keyboard gives no accents, and on
-- a layout that is not QWERTY the letters follow the US positions. Random names can
-- have them: see names.lua. Letters are saved as codes.
-- =============================================================================
local ML = MedievalLife

ML.Typing = {}
local Typing = ML.Typing

Typing.ACTION_MAP = "ml_typing"
Typing.ACTION_MAP_FILE = "Libs/Config/ml_typing.xml"
Typing.PROMPT = "@ml_type_name"
Typing.HINT = "@ml_type_hint"
Typing.HINT_SECONDS = 3600
Typing.MAX_LENGTH = 30
Typing.CURSOR = "_"
Typing.SPACE = " "

-- A code is the position in this list, and 0 means no letter. New letters go at the end: saves keep the codes.
Typing.ALPHABET = {
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
	"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
	"ñ", Typing.SPACE,
	"á", "č", "ď", "é", "ě", "í", "ň", "ó", "ř", "š", "ť", "ú", "ů", "ý", "ž",
}
Typing.UPPER = {
	["ñ"] = "Ñ", ["á"] = "Á", ["č"] = "Č", ["ď"] = "Ď", ["é"] = "É", ["ě"] = "Ě", ["í"] = "Í", ["ň"] = "Ň",
	["ó"] = "Ó", ["ř"] = "Ř", ["š"] = "Š", ["ť"] = "Ť", ["ú"] = "Ú", ["ů"] = "Ů", ["ý"] = "Ý", ["ž"] = "Ž",
}
-- These stay in lower case: Henry of Skalitz, Jan ze Semína.
Typing.LOWER_WORDS = { of = true, de = true, del = true, la = true, le = true, von = true, van = true, the = true, z = true, ze = true }

local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"

local codeOf = {}
for code, letter in ipairs(Typing.ALPHABET) do
	codeOf[letter] = code
end

local KEY_CODES = { ml_key_enye = codeOf["ñ"], ml_key_space = codeOf[Typing.SPACE] }
for code = 1, 26 do
	KEY_CODES["ml_key_" .. Typing.ALPHABET[code]] = code
end

local codes
local gender

local function capitalize(word)
	if Typing.LOWER_WORDS[word] then
		return word
	end
	local first = string.match(word, "^" .. UTF8_CHAR)
	return (Typing.UPPER[first] or string.upper(first)) .. string.sub(word, #first + 1)
end

local function render(list)
	local letters = {}
	for index, code in ipairs(list) do
		letters[index] = Typing.ALPHABET[code]
	end
	return (string.gsub(table.concat(letters), "[^ ]+", capitalize))
end

local function toCodes(text)
	local list = {}
	for letter in string.gmatch(text, UTF8_CHAR) do
		list[#list + 1] = codeOf[letter]
	end
	return list
end

local function show()
	if #codes == 0 then
		ML.Screen.SetText(Typing.PROMPT)
	else
		ML.Screen.SetText(render(codes) .. Typing.CURSOR)
	end
end

local function finish()
	if #codes == 0 then
		return
	end
	Typing.active = false
	ML.Try("typing map", function()
		ActionMapManager.EnableActionMap(Typing.ACTION_MAP, false)
		Game.HideInfoText()
	end)
	ML.Log("typed name", render(codes))
	ML.Selector.SetName(codes)
	ML.Screen.Hide()
end

local function press(action)
	local code = KEY_CODES[action]
	if action == "ml_key_enter" then
		finish()
		return
	elseif action == "ml_key_back" then
		codes[#codes] = nil
	elseif action == "ml_key_random" then
		codes = toCodes(ML.Female.RandomName(gender, ML.Selector.Ethnicity()))
	elseif code and #codes < Typing.MAX_LENGTH and (code ~= KEY_CODES.ml_key_space or #codes > 0) then
		codes[#codes + 1] = code
	end
	show()
end

-- Vanilla Player.OnAction gets every action of the maps it listens to.
local function hook()
	if Typing.hooked then
		return
	end
	Typing.hooked = true
	local original = Player.OnAction
	Player.OnAction = function(self, action, activation, value)
		if Typing.active and string.sub(action, 1, 7) == "ml_key_" then
			ML.Try("typing key", press, action)
			return
		end
		return original(self, action, activation, value)
	end
end

function Typing.Start(chosenGender)
	if not Typing.loaded then
		Typing.loaded = ML.Try("typing load", function() return ActionMapManager.LoadFromXML(Typing.ACTION_MAP_FILE) or true end)
		if not Typing.loaded then
			return
		end
	end
	ML.Try("typing hook", hook)
	codes = {}
	gender = chosenGender
	Typing.active = true
	ML.Screen.Show(Typing.PROMPT)
	ML.Try("typing map", function()
		ActionMapManager.SetActionListener(Typing.ACTION_MAP, player.id)
		ActionMapManager.EnableActionMap(Typing.ACTION_MAP, true)
		Game.SendInfoText(Typing.HINT, true, nil, Typing.HINT_SECONDS)
	end)
end

function Typing.RandomName(chosenGender)
	return render(toCodes(ML.Female.RandomName(chosenGender, ML.Store.Get("ethnicity", "czech"))))
end

function Typing.Save(list)
	ML.Store.Set("name", list)
end

function Typing.Load()
	return render(ML.Store.Get("name", {}))
end

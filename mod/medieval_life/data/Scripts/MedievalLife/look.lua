-- =============================================================================
-- Look of the new character: KCD2 Life only calls the frameworks, KCD2 Female Framework
-- for a woman and KCD2 Male Framework for a man. Before the
-- switch, the framework gives Henry the token of the look. Skald, in the framework,
-- turns it on when the switch ends, because SwitchPlayer does not show what was turned
-- on before. Then the framework puts on hair and beard and rebuilds the model, which
-- only shows the look after a rebuild. Game.QuickLoad does nothing, so the mod cannot
-- reload the game to show it.
-- =============================================================================
local ML = MedievalLife

ML.Look = {}
local Look = ML.Look

Look.MAN = 1
Look.WOMAN = 2
-- Skald leaves one of these when the player ends up with nothing on or puts something on: ml_look.xml.
Look.NAKED_TOKENS = {
	["66ee02d8-a476-5527-aeea-d667119d57ae"] = 1,
	["8e24f336-8593-5abf-925a-7626dd8e0082"] = 0,
}

local function framework(gender)
	return gender == Look.WOMAN and FemaleCore or MaleCore
end

function Look.Choose(index)
	local look = ML.Female.GetLook(index)
	if not look then
		return false
	end
	return ML.Try("look token", function() return framework(look.gender).ChooseNewCharacter(index) end) == true
end

-- Shows what the soul has now. It runs on every load and map: arriving in Kuttenberg brings the head of Henry back.
function Look.Refresh()
	local gender = ML.Store.Get("woman") == 1 and Look.WOMAN or Look.MAN
	ML.Try("look refresh", function() framework(gender).Refresh() end)
end

-- KCD2 Female Framework changes the clothes of a woman for copies she can wear, so it must know she is one.
function Look.Update()
	if Look.shownGen ~= ML.gen and ML.Female.IsSpawned() then
		Look.shownGen = ML.gen
		local woman = ML.Store.Get("woman") == 1
		ML.Try("new character", function() FemaleCore.UseNewCharacter(woman and ML.Store.Get("look") or 0) end)
		Look.Refresh()
	end
end

ML.TickHandlers[#ML.TickHandlers + 1] = Look.Update

-- Once the new character is in use: hair, beard and a rebuild. A woman's hair is the one of her look, and the barber of
-- KCD2 Female Framework keeps the one she chooses later, in the soul.
function Look.Rebuild(index, after)
	Look.shownGen = ML.gen
	local look = ML.Female.GetLook(index)
	if look.gender == Look.WOMAN then
		ML.Store.Set("woman_hair_style", look.style)
		ML.Store.Set("woman_hair_color", look.color)
		ML.Try("look show", function() FemaleCore.ShowNewCharacter(index, look.style, look.color, after) end)
	else
		ML.Try("look show", function() MaleCore.ShowNewCharacter(index, after) end)
	end
	ML.Log("look shown by the framework", look.name)
end

-- =============================================================================
-- Henry's first recipes. The mod hides the game's alchemy recipes and teaches copies of them that nobody knows, so Henry, with the mod installed, knows none, and the book at Bozhena's is empty. The prologue (the quest
-- Fortuna) asks him for a chamomile decoction for Hans, and no quest of the game teaches it: Henry knows it from the
-- start. So he gets the copies of chamomile decoction and Saviour schnapps once his part of the game has begun, outside
-- a cutscene, on every load: in a new game, when he takes over after Godwin; in a save of his, at once.
-- =============================================================================
local ML = MedievalLife

ML.HenryRecipes = {}
local HenryRecipes = ML.HenryRecipes

-- The perks of the copies, from tools/generate_recipes.py (perk_recipe__medieval_life.xml): chamomile decoction is
-- recipe 49 of the game and copy 9049, Saviour schnapps is 13 and 9013.
HenryRecipes.PERKS = {
	chamomile_decoction = "de21122c-9de7-5c0a-b891-ae4f84804c72",
	saviour_schnapps = "d7e8b131-f211-50d7-a4ad-8e58e359ae3e",
}
-- A new game begins with Godwin on the first day of the world, and Henry's part on the second (KCD2 Female Framework,
-- HENRY_FIRST_DAY).
HenryRecipes.FIRST_DAY = 2
-- Only the game's Cutscene.cfg sets it to 1, while a cutscene plays (KCD2 Female Framework, CUTSCENE_CVAR).
HenryRecipes.CUTSCENE_CVAR = "e_SkipInFrustumOptimizationWH"

local givenGen

local function update()
	-- The character of a new life learns from recipe documents, like any copy.
	if givenGen == ML.gen or ML.Life.IsStarted() then
		return
	end
	local day = ML.Try("calendar", Calendar.GetWorldDay)
	if not day or day < HenryRecipes.FIRST_DAY then
		return
	end
	if tonumber(ML.Try("cutscene", System.GetCVar, HenryRecipes.CUTSCENE_CVAR)) == 1 then
		return
	end
	givenGen = ML.gen
	for name, perk in pairs(HenryRecipes.PERKS) do
		ML.Try("recipe " .. name, function() player.soul:AddPerk(perk) end)
	end
	ML.Log("Henry knows the copies of chamomile decoction and Saviour schnapps")
end

ML.TickHandlers[#ML.TickHandlers + 1] = update

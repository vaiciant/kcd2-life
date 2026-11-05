-- =============================================================================
-- The Nutrition Mod, by djb. Each food gives a buff that lasts some time, and when it is over the character
-- lacks fruit, protein, vegetables or water. Work moves the clock by hand (jobs.lua), and those buffs do not count the
-- hours worked: after a day of work the character was as well fed as before. So, after work, each of those buffs that
-- would have run out in those hours goes. Lua cannot read how long a buff has left, only remove it: one that lasts less
-- than the hours worked has run out for sure, and one that lasts more stays. The mod is known by its global table, as
-- it names it. Without it, nothing.
-- =============================================================================
local ML = MedievalLife

ML.Nutrition = {}
local Nutrition = ML.Nutrition

-- Its buffs of eating and drinking, and how long they last, in seconds of game time (buff__djbnutrition_mod.xml): the
-- duration of the buffs of the game is in game seconds, as the potion of Bard 3, 5760, an hour and 36 minutes.
Nutrition.BUFFS = {
	{ guid = "92bcf10e-80da-48af-97cb-73a5b2b94ca2", seconds = 15000 }, -- fruit
	{ guid = "a4e7c589-3b21-4d28-8f9c-e5619d8a6b76", seconds = 15000 }, -- protein
	{ guid = "7bc31f25-e6ae-4d97-a742-c61dfb3e54a0", seconds = 15000 }, -- vegetables
	{ guid = "7ce1d99c-4c3c-4302-acc9-63c96881ebab", seconds = 4000 }, -- water
}
Nutrition.HOUR_SECONDS = 3600

-- After some hours of work: what the Nutrition Mod would have used up in them.
function Nutrition.Pass(hours)
	if type(NutritionStatusSystem) ~= "table" then
		return
	end
	local gone = 0
	for _, buff in ipairs(Nutrition.BUFFS) do
		if hours * Nutrition.HOUR_SECONDS >= buff.seconds then
			ML.Try("nutrition buff", function() player.soul:RemoveAllBuffsByGuid(buff.guid) end)
			gone = gone + 1
		end
	end
	ML.Log("nutrition: after", hours, "hours of work,", gone, "kinds of food or drink are used up")
end

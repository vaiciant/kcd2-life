-- =============================================================================
-- KCD2 Life: startup. The game loads this file when it opens.
-- It only defines tables, commands and events: there is no world or player yet.
-- =============================================================================
MedievalLife = MedievalLife or {}

Script.LoadScript("Scripts/MedievalLife/core.lua")
Script.LoadScript("Scripts/MedievalLife/store.lua")
Script.LoadScript("Scripts/MedievalLife/economy.lua")
Script.LoadScript("Scripts/MedievalLife/days.lua")
Script.LoadScript("Scripts/MedievalLife/factions_data.lua")
Script.LoadScript("Scripts/MedievalLife/reputation.lua")
Script.LoadScript("Scripts/MedievalLife/settings.lua")
Script.LoadScript("Scripts/MedievalLife/screen.lua")
Script.LoadScript("Scripts/MedievalLife/names.lua")
Script.LoadScript("Scripts/MedievalLife/typing.lua")
Script.LoadScript("Scripts/MedievalLife/look.lua")
Script.LoadScript("Scripts/MedievalLife/origins_data.lua")
Script.LoadScript("Scripts/MedievalLife/origins.lua")
Script.LoadScript("Scripts/MedievalLife/life.lua")
Script.LoadScript("Scripts/MedievalLife/work_book.lua")
Script.LoadScript("Scripts/MedievalLife/employee_bed.lua")
Script.LoadScript("Scripts/MedievalLife/jobs_data.lua")
Script.LoadScript("Scripts/MedievalLife/jobs.lua")
Script.LoadScript("Scripts/MedievalLife/employment.lua")
Script.LoadScript("Scripts/MedievalLife/orders_data.lua")
Script.LoadScript("Scripts/MedievalLife/orders.lua")
Script.LoadScript("Scripts/MedievalLife/rent.lua")
Script.LoadScript("Scripts/MedievalLife/nutrition.lua")
Script.LoadScript("Scripts/MedievalLife/bed_marker.lua")
Script.LoadScript("Scripts/MedievalLife/woman_test.lua")
Script.LoadScript("Scripts/MedievalLife/woman_clothes_data.lua")
Script.LoadScript("Scripts/MedievalLife/female_core.lua")
Script.LoadScript("Scripts/MedievalLife/selector.lua")
Script.LoadScript("Scripts/MedievalLife/host.lua")
Script.LoadScript("Scripts/MedievalLife/map_points.lua")
Script.LoadScript("Scripts/MedievalLife/map_marks.lua")
Script.LoadScript("Scripts/MedievalLife/fast_travel.lua")
Script.LoadScript("Scripts/MedievalLife/story.lua")
Script.LoadScript("Scripts/MedievalLife/tutorial.lua")
Script.LoadScript("Scripts/MedievalLife/stash.lua")
Script.LoadScript("Scripts/MedievalLife/switch.lua")
Script.LoadScript("Scripts/MedievalLife/uninstall.lua")
Script.LoadScript("Scripts/MedievalLife/commands.lua")

local ML = MedievalLife

if not (ML.Log and ML.Store and ML.Economy and ML.Days and ML.Reputation and ML.Settings and ML.Screen and ML.Names and ML.Typing and ML.Look and ML.Origins and ML.Life and ML.WorkBook and ML.EmployeeBed and ML.Jobs and ML.Employment and ML.Orders and ML.Rent and ML.Nutrition and ML.BedMarker and ML.WomanTest and ML.Female and ML.Selector and ML.Host and ML.MapMarks and ML.FastTravel and ML.Story and ML.Tutorial and ML.Stash and ML.Switch and ML.Uninstall and ML.Commands) then
	System.LogAlways("[ML] ERROR a module did not load")
	return
end

-- Runs on every load and region change.
function ML:OnGameplayStarted(actionName, eventName, argTable)
	ML.gen = ML.gen + 1
	ML.Log("gameplay started gen=", ML.gen)
	-- Without both frameworks nothing of the mod starts: no tick, no wayfarer, no work.
	if ML.Try("frameworks", ML.Life.CheckFrameworks) == false then
		return
	end
	-- With a mod that changes the game's prices, the money of the mod follows them.
	ML.Try("economy", ML.Economy.Detect)
	-- The new character is not Henry: the frameworks must not put a look on Henry's soul from it.
	MaleCore.OtherCharacter = ML.Life.IsStarted
	FemaleCore.OtherCharacter = ML.Life.IsStarted
	ML.TickStart()
	-- After ml_uninstall, or while Henry plays after ml_switch, he plays as in the game alone: nothing else of the mod
	-- starts.
	if ML.Uninstall.IsDone() then
		ML.Log("uninstalled in this save: the mod stays off")
		return
	end
	if ML.Switch.HenryPlays() then
		ML.Log("Henry plays: the new life waits for ml_switch")
		return
	end
	ML.Try("world time", function() ML.Log("world day=", Calendar.GetWorldDay(), "time=", Calendar.GetWorldTime()) end)
	ML.Try("settings", ML.Settings.Register)
	ML.BedMarker.Start()
	ML.FastTravel.Listen()
end

ML.Try("listener", function()
	UIAction.RegisterEventSystemListener(ML, "System", "OnGameplayStarted", "OnGameplayStarted")
	ML.WorkBook.Listen()
end)
ML.Try("settings", ML.Settings.Register)

ML.Log("loaded")

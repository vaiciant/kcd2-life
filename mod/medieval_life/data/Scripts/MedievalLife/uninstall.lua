-- =============================================================================
-- ml_uninstall: the new character gives the game back to Henry, player 0, and the new life ends, before the mods are
-- removed. Under a black screen, it closes what the new life keeps open in the save: its quests in the journal, the
-- steady job and its bed, the errands, their slips and what is owed. Those quests only hear the inventory of the new
-- character, so it runs before the switch, and only in the Trosky region, where they are. Then the switch goes back to
-- Henry (switch.lua), Mutt comes back, a warning shows, the game is saved, and the mod stays off in that save.
-- Quitting and removing the mods gives Henry his recipes back.
-- =============================================================================
local ML = MedievalLife

ML.Uninstall = {}
local Uninstall = ML.Uninstall

Uninstall.KEY = "uninstalled"
Uninstall.CONFIRM = "yes"
Uninstall.SCREEN_TEXT = "@ml_uninstall_screen"
Uninstall.DONE_TEXT = "@ml_uninstall_done"
Uninstall.FAILED_TEXT = "@ml_uninstall_failed"
Uninstall.REGION_TEXT = "@ml_uninstall_region"
-- On the black screen once Henry is back, before it lifts: a save from before the new life is the safest way
-- back, because nobody has tested whether what the new character did can break a quest of the story.
Uninstall.ADVICE_TEXT = "@ml_uninstall_advice"
-- The screen goes black first; the quests hear their closing tokens before the switch.
Uninstall.SCREEN_MS = 1500
Uninstall.CLOSE_MS = 2500
-- The dialog options of the mod read these: at 0 they stay hidden.
Uninstall.HIDDEN_VARIABLES = { "ml_new_life", "ml_woman", "ml_job_offer", "ml_shift_state" }

-- While the switch runs, the tick leaves the mod alone, as after it.
Uninstall.running = false

function Uninstall.IsDone()
	return ML.Store.Get(Uninstall.KEY) == 1
end

function Uninstall.IsQuiet()
	return Uninstall.running or Uninstall.IsDone() or ML.Switch.IsQuiet()
end

-- The tick runs only this while it is quiet: variables are lost on a region change.
function Uninstall.Quiet()
	for _, name in ipairs(Uninstall.HIDDEN_VARIABLES) do
		Variables.SetGlobal(name, 0)
	end
end

-- Henry plays again: the new life is over, Mutt comes back, the frameworks hear it, and the game saves.
local function backAsHenry()
	ML.Store.Set("state", ML.Life.STATE_ENDED)
	ML.Store.Set(Uninstall.KEY, 1)
	Uninstall.running = false
	Uninstall.Quiet()
	-- Henry's stash back in his master chest.
	ML.Try("uninstall stash", ML.Stash.Arrive, ML.Stash.HENRY)
	-- His beds and homes, back on the compass.
	ML.Try("uninstall beds", ML.BedMarker.ShowGameBeds)
	ML.Try("uninstall dog", ML.Life.ReturnDog)
	ML.Try("uninstall woman", function() FemaleCore.UseNewCharacter(0) end)
	ML.Log("back to Henry")
	ML.Switch.Finish(Uninstall.ADVICE_TEXT, function() ML.Switch.Notice(Uninstall.DONE_TEXT) end)
end

local function failed()
	Uninstall.running = false
	ML.Try("uninstall stash", ML.Stash.Arrive, ML.Stash.LIFE)
	ML.Screen.Hide()
	ML.Switch.Notice(Uninstall.FAILED_TEXT)
	ML.Log("ERROR uninstall: the switch back to Henry did not end")
end

function Uninstall.Run(line)
	if Uninstall.IsDone() then
		ML.Log("ml_uninstall is done already in this save: Henry plays, and the mods can be removed")
		ML.Switch.Notice(Uninstall.DONE_TEXT)
		return
	end
	if Uninstall.running or ML.Switch.running then
		return
	end
	-- The quests of the life close from the inventory of the new character.
	if ML.Switch.HenryPlays() then
		ML.Log("Henry plays now: switch to the new character first, with ml_switch yes, and then type ml_uninstall yes")
		return
	end
	if not ML.Life.IsStarted() then
		ML.Log("no new life in this save: there is nothing to clear, and the mods can be removed")
		return
	end
	if string.match(line or "", "^%s*(%S*)") ~= Uninstall.CONFIRM then
		ML.Log("ml_uninstall ends the new life: it closes its quests, the steady job and the errands, goes back to Henry, "
			.. "gives Mutt back and saves. The safest way back is a save from before the new life: nobody has tested whether "
			.. "what the new character did can break a quest of the story. To do it here anyway, type: ml_uninstall " .. Uninstall.CONFIRM)
		return
	end
	if ML.Region() ~= "trosky" then
		ML.Log("ml_uninstall: go back to the Trosky region first, where the quests of the mod are")
		ML.Switch.Notice(Uninstall.REGION_TEXT)
		return
	end
	ML.Log("uninstall starts")
	Uninstall.running = true
	ML.Screen.Show(Uninstall.SCREEN_TEXT)
	Script.SetTimer(Uninstall.SCREEN_MS, function()
		ML.Try("uninstall job", ML.Employment.Leave)
		ML.Try("uninstall orders", ML.Orders.Clear)
		Script.SetTimer(Uninstall.CLOSE_MS, function()
			-- The new character takes their stash along, and Henry's comes back once he plays.
			ML.Switch.DismissMercenaries("ml_uninstall")
			ML.Try("uninstall rent", ML.Rent.Clear)
			ML.Try("uninstall stash", ML.Stash.Leave, ML.Stash.LIFE)
			ML.Switch.ToHenry(backAsHenry, failed)
		end)
	end)
end

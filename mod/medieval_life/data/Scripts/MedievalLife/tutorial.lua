-- =============================================================================
-- The first steps of the new life, as tutorials of the game (Libs/Tables/ui/tutorial__medieval_life.xml): what the new
-- life is, sleeping and saving, work, errands and Fiala's free haircut. One at a time once the life has begun, right
-- after the black screen goes and the first save is done. The next one to show is kept in the save, so a load goes on where it stopped.
-- They do not wait for dialogs: after the talk with the wayfarer, IsInDialog stayed true until the inventory opened, and
-- the first one came late.
-- =============================================================================
local ML = MedievalLife

ML.Tutorial = {}
local Tutorial = ML.Tutorial

-- Names of the rows of the tutorial table, in order.
Tutorial.LIST = { "ML_NewLife", "ML_Sleep", "ML_Work", "ML_Errands", "ML_Barber" }
Tutorial.KEY = "tutorial_next"
-- In ticks of the mod, a second each: after the black screen, as it fades, and between two (the table shows each for
-- 30 s).
Tutorial.FIRST_TICKS = 2
Tutorial.GAP_TICKS = 32

local wait = nil

-- Not under the black screen, and not before the first save of the new life is done.
local function busy()
	return ML.Screen.active or ML.Life.savePending
end

function Tutorial.Update()
	if not ML.Life.IsStarted() then
		return
	end
	local index = ML.Store.Get(Tutorial.KEY, 1)
	if index > #Tutorial.LIST or busy() then
		return
	end
	if not wait or wait.gen ~= ML.gen then
		wait = { gen = ML.gen, ticks = Tutorial.FIRST_TICKS }
	end
	wait.ticks = wait.ticks - 1
	if wait.ticks > 0 then
		return
	end
	local name = Tutorial.LIST[index]
	ML.Try("tutorial", function() Game.ShowTutorial(name) end)
	ML.Store.Set(Tutorial.KEY, index + 1)
	wait.ticks = Tutorial.GAP_TICKS
	ML.Log("tutorial shown", name)
end

ML.TickHandlers[#ML.TickHandlers + 1] = Tutorial.Update

-- Test shortcut: shows them all again, from the first.
function Tutorial.Reset()
	ML.Store.Set(Tutorial.KEY, 1)
	wait = nil
	ML.Log("tutorials will show again")
end

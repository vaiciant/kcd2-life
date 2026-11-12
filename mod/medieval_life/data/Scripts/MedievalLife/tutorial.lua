-- =============================================================================
-- The first steps of the new life, as tutorials of the game (Libs/Tables/ui/tutorial__medieval_life.xml): what the new
-- life is, sleeping and saving, work, errands and Fiala's free haircut. All of them are sent at the start, right after
-- the black screen goes and the first save is done, a moment apart: the game shows the next one only when the one on
-- screen is closed. Until 0.1.29 one went every 32 s, and the game crashed more than once with the book open
-- just as one was sent. Not while the inventory or a book is open either. The next one to send
-- is kept in the save, so a load goes on where it stopped.
-- They do not wait for dialogs: after the talk with the wayfarer, IsInDialog stayed true until the inventory opened, and
-- the first one came late.
-- =============================================================================
local ML = MedievalLife

ML.Tutorial = {}
local Tutorial = ML.Tutorial

-- Names of the rows of the tutorial table, in order.
Tutorial.LIST = { "ML_NewLife", "ML_Sleep", "ML_Work", "ML_Errands", "ML_Barber" }
Tutorial.KEY = "tutorial_next"
-- In ticks of the mod, a second each: after the black screen or a menu, and between two.
Tutorial.FIRST_TICKS = 2
Tutorial.GAP_TICKS = 1

local wait = nil

-- The interface the tutorials wait for, open now, by element: the inventory, and the book read from it.
Tutorial.MENUS = { "ApseCharacter", "GeneralBook" }
Tutorial.MENU_EVENTS = { "OnShow", "OnHide", "OnUnload" }
local menus = {}

function Tutorial:OnMenu(elementName, instanceId, eventName, args)
	menus[tostring(elementName)] = eventName == "OnShow" or nil
end

function Tutorial.Listen()
	for _, element in ipairs(Tutorial.MENUS) do
		for _, event in ipairs(Tutorial.MENU_EVENTS) do
			UIAction.RegisterElementListener(Tutorial, element, -1, event, "OnMenu")
		end
	end
end

-- Not under the black screen, not before the first save of the new life is done, and not in the inventory.
local function busy()
	return ML.Screen.active or ML.Life.savePending or next(menus) ~= nil
end

function Tutorial.Update()
	if not ML.Life.IsStarted() then
		return
	end
	local index = ML.Store.Get(Tutorial.KEY, 1)
	if index > #Tutorial.LIST then
		return
	end
	if not wait or wait.gen ~= ML.gen then
		-- A load closes every menu.
		wait, menus = { gen = ML.gen, ticks = Tutorial.FIRST_TICKS }, {}
	end
	if busy() then
		wait.ticks = math.max(wait.ticks, Tutorial.FIRST_TICKS)
		return
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

-- =============================================================================
-- New life: the switch from Henry to the new character, under the black screen.
-- SwitchPlayer with a dialog open locks the new character, so this starts after the
-- selector closes. The switch takes a few seconds.
-- =============================================================================
local ML = MedievalLife

ML.Life = {}
local Life = ML.Life

Life.STATE_STARTED = 1
-- After ml_uninstall went back to Henry: the new life is over in that save.
Life.STATE_ENDED = 2
Life.STATE_VARIABLE = "ml_new_life"
-- 1 while the new character is a woman: the barber of KCD2 Life is only for a man.
Life.WOMAN_VARIABLE = "ml_woman"
-- Each shop discovered gives experience to whoever is playing, so they open as Henry, well before the switch.
Life.SHOPS_TOKEN = "09516a0f-bfb0-55d9-8293-9783edb12872"
Life.TOKEN_MS = 1000
Life.SAVE_DELAY_MS = 1500
-- The date shows once the black screen has faded.
Life.DATE_DELAY_MS = 2500
Life.STORY_TEXT = "@ml_new_life_story"
Life.COIN_ITEM = "5ef63059-322e-4e1b-abe8-926e100c770e"
Life.DOG_CLASS = "Dog"
Life.DOG_NAMES = { "dogcompanion", "vorech" }
Life.DOG_EXILE = { x = 200, y = 200, z = 300 }
Life.DOG_EXILE_RANGE = 10

-- Every bed is a save point, even a stranger's and even if the owner throws the character
-- out. Skald adds 1 of this token when a wait or a sleep starts, and
-- 2 when it ends (ml_sleep.xml). Only a sleep brings tiredness up, though being thrown out
-- at once with it nearly full brings it up very little. A wait lowers it, and under a
-- potion that stops tiredness it stays as it was.
Life.SLEEP_TOKEN = "aaee9462-4303-5c2e-8454-11d1696e29bd"
Life.SLEEP_MIN_RISE = 0.05
-- A wait or a sleep shorter than this, in hours of the game, says in the log what stopped it.
Life.SHORT_SKIP_HOURS = 0.25

-- KCD2 Life needs both frameworks: without the men's one, a man keeps Henry's look. Each one sets LOADED when it loads.
-- It is checked once the game runs, never at load, because the load order of mods is not fixed.
-- Without them nothing of KCD2 Life runs, and a notice says which one is missing.
Life.FRAMEWORKS_TEXTS = {
	female = "@ml_frameworks_missing_female",
	male = "@ml_frameworks_missing_male",
	both = "@ml_frameworks_missing",
}
Life.FRAMEWORKS_SECONDS = 12

local function hasFemale()
	return FemaleCore ~= nil and FemaleCore.LOADED == true
end

local function hasMale()
	return MaleCore ~= nil and MaleCore.LOADED == true
end

function Life.FrameworksReady()
	return hasFemale() and hasMale()
end

-- Returns whether both are there. If not, it says which one is missing.
function Life.CheckFrameworks()
	if Life.FrameworksReady() then
		return true
	end
	local missing = not hasFemale() and not hasMale() and "both" or (hasFemale() and "male" or "female")
	ML.Log("frameworks missing:", missing)
	ML.Try("frameworks notice", function() Game.SendInfoText(Life.FRAMEWORKS_TEXTS[missing], false, nil, Life.FRAMEWORKS_SECONDS) end)
	return false
end

-- The new character plays. While Henry plays after ml_switch, the life waits and this is false.
function Life.IsStarted()
	return ML.Store.Get("state") == Life.STATE_STARTED and ML.Store.Get("henry_playing") ~= 1
end

-- Skald reacts when it arrives.
local function sendToken(guid)
	ML.Try("life token", function() player.inventory:CreateItem(guid, 1, 1) end)
	Script.SetTimer(Life.TOKEN_MS, function()
		ML.Try("life token", function() player.inventory:DeleteItemOfClass(guid, 1) end)
	end)
end

Life.SendToken = sendToken

local chosenName

-- All of it belongs to the new character, and the first save has it in place.
local function finish()
	ML.Try("life stash", ML.Stash.Arrive, ML.Stash.LIFE)
	-- Henry's beds and homes, off the compass.
	ML.Try("life beds", ML.BedMarker.HideGameBeds)
	ML.Origins.Wear(ML.Store.Get("origin"))
	ML.Days.Start()
	ML.Store.Set("state", Life.STATE_STARTED)
	if chosenName then
		ML.Typing.Save(chosenName)
	end
	ML.WorkBook.Issue()
	local job = ML.Origins.LIST[ML.Store.Get("origin")].steady_job
	if job then
		ML.Employment.StartWith(job)
	end
	-- The reputation goes back to that of a new game first: it stops the game for moments.
	ML.Reputation.Update(function()
		-- The tutorials wait for the first save.
		Life.savePending = true
		ML.Screen.Hide()
		-- The date of the first day, as each new day shows it, once the black screen has gone.
		Script.SetTimer(Life.DATE_DELAY_MS, function() ML.Try("first date", ML.Days.Show) end)
		Script.SetTimer(Life.SAVE_DELAY_MS, function()
			ML.Log("first save returned", ML.Try("first save", function() return Game.SaveGameViaResting() end))
			Life.savePending = false
		end)
	end)
end

local dogNamesGen

-- Mutt is the Dog whose name matches. The names are logged once per load, to see them if he is not found.
local function findDog()
	local names = {}
	local found
	for _, dog in pairs(System.GetEntitiesByClass(Life.DOG_CLASS) or {}) do
		local name = dog:GetName()
		names[#names + 1] = name
		for _, part in ipairs(Life.DOG_NAMES) do
			if string.find(string.lower(name), part, 1, true) then
				found = dog
			end
		end
	end
	if dogNamesGen ~= ML.gen then
		dogNamesGen = ML.gen
		ML.Log("dogs", names)
	end
	return found
end

-- The new character has no dog. Mutt is not deleted: he waits hidden, far away, so nothing is lost if the mod goes
-- away. He comes back after a load or a region change, so this checks every tick. The dog action map has the key
-- that calls him. The engine enables it again, so it is turned off every tick too.
-- The inventory still shows Mutt, with his obedience, next to the horse: for the game he stays the player's dog.
-- player.player:SetPlayerDog(NULL_ENTITY) to take him away is a Lua error, and no other way is known.
local function keepDogAway()
	if not Life.IsStarted() then
		return
	end
	ActionMapManager.EnableActionMap("dog", false)
	local dog = findDog()
	if not dog then
		return
	end
	local position = dog:GetWorldPos()
	local away = math.abs(position.x - Life.DOG_EXILE.x) + math.abs(position.y - Life.DOG_EXILE.y)
	if away > Life.DOG_EXILE_RANGE then
		ML.Try("dog mode", function() XGenAIModule.SetPlayerDogMode("Wait") end)
		dog:SetWorldPos(Life.DOG_EXILE)
		dog:Hide(1)
		ML.Log("dog sent away from", position.x, position.y)
	end
end

ML.TickHandlers[#ML.TickHandlers + 1] = keepDogAway

-- For ml_uninstall: Mutt comes back next to the player, visible, and the whistle works again. After the mods are
-- removed, Henry finds him there.
function Life.ReturnDog()
	ActionMapManager.EnableActionMap("dog", true)
	local dog = findDog()
	if not dog then
		ML.Log("dog not found: nothing to give back")
		return false
	end
	local position = player:GetWorldPos()
	dog:SetWorldPos({ x = position.x + 2, y = position.y, z = position.z })
	dog:Hide(0)
	ML.Log("dog given back")
	return true
end

-- The dialogs of the mod read it with gvar. A region change loses it, so it is set on every tick.
local function publishState()
	Variables.SetGlobal(Life.STATE_VARIABLE, Life.IsStarted() and 1 or 0)
	Variables.SetGlobal(Life.WOMAN_VARIABLE, ML.Store.Get("woman") == 1 and 1 or 0)
end

ML.TickHandlers[#ML.TickHandlers + 1] = publishState

function Life.Begin(look, name, origin)
	ML.Log("new life begins")
	chosenName = name
	-- Henry takes his stash with him: the new character starts with an empty one of their own.
	ML.Try("life stash", ML.Stash.Leave, ML.Stash.HENRY)
	-- Henry's company stays with him, paid off: the new character starts with none.
	ML.Switch.DismissMercenaries("the new life")
	sendToken(Life.SHOPS_TOKEN)
	if ML.Origins.LIST[origin].wield_token then
		sendToken(ML.Origins.LIST[origin].wield_token)
	end
	ML.Screen.Show(Life.STORY_TEXT)
	ML.Female.RequestSpawn({
		look = look,
		context = { origin = origin },
		onSwitched = function(context) ML.Origins.Apply(context.origin) end,
		onReady = finish,
	})
end

local function checkSleep()
	local exhaust = ML.Try("sleep exhaust", function() return player.soul:GetState("exhaust") end)
	local amount = ML.Try("sleep token", function() return player.inventory:GetCountOfClass(Life.SLEEP_TOKEN) end) or 0
	if amount > 0 and exhaust then
		ML.Try("sleep token", function() player.inventory:DeleteItemOfClass(Life.SLEEP_TOKEN, amount) end)
		if amount == 1 then
			Life.sleepStart = Life.exhaust
			Life.skipStartTime = Calendar.GetWorldTime()
		else
			local before = Life.sleepStart or Life.exhaust or exhaust
			Life.sleepStart = nil
			ML.Log("skip ended, tiredness", before, "->", exhaust)
			-- A wait or a sleep that the game stops at once: what the game looks at to let time pass, so the log says why
			-- (after a rental ended, sleeping and waiting with T stopped at once).
			local hours = Life.skipStartTime and (Calendar.GetWorldTime() - Life.skipStartTime) / 3600
			Life.skipStartTime = nil
			if hours and hours < Life.SHORT_SKIP_HOURS then
				ML.Try("short skip", function()
					local soul = player.soul
					local canSleep, why = player.player.CanSleep()
					ML.Log("skip cut short after", hours, "h: hunger", soul:GetState("hunger"), "tiredness", exhaust, "health",
						soul:GetState("health"), "tense", soul:IsInTenseCircumstance(), "combat danger", soul:IsInCombatDanger(),
						"can sleep", canSleep, why, "no trespass area", ML.Employment.inArea)
				end)
			end
			if exhaust - before >= Life.SLEEP_MIN_RISE and Life.IsStarted() then
				ML.Log("sleep save returned", ML.Try("sleep save", function() return Game.SaveGameViaResting() end))
			end
		end
	end
	Life.exhaust = exhaust
end

ML.TickHandlers[#ML.TickHandlers + 1] = checkSleep
-- After checkSleep, to know that a wait or a sleep has started.
ML.TickHandlers[#ML.TickHandlers + 1] = ML.Days.Update

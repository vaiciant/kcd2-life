-- =============================================================================
-- Switching the player between Henry, player 0, and the new character, player 2 (Quests/medieval_life/ml_switch.xml).
-- ml_switch moves between them while the new life goes on: a way out when, for instance, the new character took one
-- of Henry's quests and it broke the life. ml_uninstall uses the way back to Henry to end the life. Under a black
-- screen, with a warning that it can break a save of KCD2 Life, and a save at the end.
-- =============================================================================
local ML = MedievalLife

ML.Switch = {}
local Switch = ML.Switch

Switch.CONFIRM = "yes"
-- 1 while Henry plays and the new life waits. The mod stays quiet then, as after ml_uninstall.
Switch.HENRY_KEY = "henry_playing"
-- ml_switch.xml: to Henry from the inventory of the new character, with a token for Henry when it ends; to the new
-- character from Henry's inventory.
Switch.TO_HENRY_TOKEN = "421028ce-b581-5ab3-9871-961d9b23cff0"
Switch.HENRY_DONE_TOKEN = "2a80de10-48c6-5fc2-aeb2-a5d8fb72309a"
Switch.TO_LIFE_TOKEN = "c5521005-5030-5d98-8910-c3055ba168fe"
Switch.HENRY_SCREEN_TEXT = "@ml_uninstall_screen"
Switch.LIFE_SCREEN_TEXT = "@ml_switch_life_screen"
Switch.ADVICE_TEXT = "@ml_switch_advice"
Switch.FAILED_TEXT = "@ml_switch_failed"
Switch.SCREEN_MS = 1500
Switch.POLL_MS = 500
Switch.WAIT_MS = 20000
Switch.ADVICE_MS = 9000
Switch.SAVE_DELAY_MS = 2000
Switch.TEXT_SECONDS = 10

Switch.running = false

function Switch.HenryPlays()
	return ML.Store.Get(Switch.HENRY_KEY) == 1
end

-- The tick leaves the mod alone while a switch runs and while Henry plays.
function Switch.IsQuiet()
	return Switch.running or Switch.HenryPlays()
end

function Switch.Notice(text)
	ML.Try("switch notice", function() Game.SendInfoText(text, false, nil, Switch.TEXT_SECONDS) end)
end

-- With Mercenaries, the company is paid off before the player changes: starting a new life, ml_switch and
-- ml_uninstall. Men hired by one would follow the other, so each one starts with none. It is what its own
-- command merc_dismiss does, mercenaries:SetState("dismiss"): it breaks camp and the men leave the world a moment later.
-- Without Mercenaries, nothing.
function Switch.DismissMercenaries(why)
	if type(mercenaries) ~= "table" then
		return
	end
	if type(mercenaries.SetState) == "function" then
		ML.Try("mercenaries dismiss", function() mercenaries:SetState("dismiss") end)
	else
		ML.Try("mercenaries dismiss", function() System.ExecuteCommand("merc_dismiss") end)
	end
	ML.Log("Mercenaries: the company is paid off,", why)
end

-- The items the player carries now, by the digits of their ids.
local function carried()
	local digits = {}
	for _, id in pairs(ML.Try("switch inventory", function() return player.inventory:GetInventoryTable() end) or {}) do
		local key = ML.WorkBook.Digits(id)
		if key then
			digits[key] = true
		end
	end
	return digits
end

local function wait(isOver, waited, done, failed)
	if isOver() then
		done()
	elseif waited >= Switch.WAIT_MS then
		failed()
	else
		Script.SetTimer(Switch.POLL_MS, function() wait(isOver, waited + Switch.POLL_MS, done, failed) end)
	end
end

-- Henry plays when the token Skald gives him at the end of the switch is in the player's inventory.
function Switch.ToHenry(done, failed)
	ML.Life.SendToken(Switch.TO_HENRY_TOKEN)
	wait(function() return ML.TakeToken(Switch.HENRY_DONE_TOKEN) end, 0, done, failed)
end

-- Lua cannot read Henry's inventory once the new character plays, so the switch is over when none of the items the
-- player carried are there any more.
function Switch.ToLife(done, failed)
	local before = carried()
	ML.Life.SendToken(Switch.TO_LIFE_TOKEN)
	wait(function()
		local now = carried()
		if next(now) == nil then
			return false
		end
		for key in pairs(now) do
			if before[key] then
				return false
			end
		end
		return true
	end, 0, done, failed)
end

-- The warning stays on the black screen for a while; then the screen lifts and the game saves.
function Switch.Finish(text, after)
	ML.Screen.SetText(text)
	Script.SetTimer(Switch.ADVICE_MS, function()
		ML.Screen.Hide()
		Script.SetTimer(Switch.SAVE_DELAY_MS, function()
			ML.Log("switch save returned", ML.Try("switch save", function() return Game.SaveGameViaResting() end))
			if after then
				after()
			end
		end)
	end)
end

-- Who keeps playing when the switch fails takes back the stash they put away.
local function failedSwitch(who)
	Switch.running = false
	ML.Try("switch stash", ML.Stash.Arrive, who)
	ML.Screen.Hide()
	Switch.Notice(Switch.FAILED_TEXT)
	ML.Log("ERROR switch: it did not end, the same character plays")
end

-- Henry plays, and the new life waits: Mutt comes back, and the frameworks know there is no woman in use.
local function toHenry()
	ML.Log("switch to Henry")
	Switch.running = true
	ML.Screen.Show(Switch.HENRY_SCREEN_TEXT)
	Script.SetTimer(Switch.SCREEN_MS, function()
		-- Each one has a stash of their own: the new character takes theirs, and Henry puts his back.
		Switch.DismissMercenaries("the switch to Henry")
		-- The rented bed waits for the new character; Henry has the game's bed back meanwhile.
		ML.Try("switch rent", ML.Rent.Suspend)
		ML.Try("switch stash", ML.Stash.Leave, ML.Stash.LIFE)
		Switch.ToHenry(function()
			ML.Store.Set(Switch.HENRY_KEY, 1)
			Switch.running = false
			ML.Try("switch stash", ML.Stash.Arrive, ML.Stash.HENRY)
			-- His beds and homes, back on the compass.
			ML.Try("switch beds", ML.BedMarker.ShowGameBeds)
			ML.Uninstall.Quiet()
			ML.Try("switch dog", ML.Life.ReturnDog)
			ML.Try("switch woman", function() FemaleCore.UseNewCharacter(0) end)
			ML.Log("Henry plays, the new life waits")
			Switch.Finish(Switch.ADVICE_TEXT)
		end, function() failedSwitch(ML.Stash.LIFE) end)
	end)
end

-- The new character plays again. SwitchPlayer does not show the look turned on before it, so the next tick tells the
-- frameworks who plays and they rebuild it, under the black screen.
local function toLife()
	ML.Log("switch to the new character")
	Switch.running = true
	ML.Screen.Show(Switch.LIFE_SCREEN_TEXT)
	Script.SetTimer(Switch.SCREEN_MS, function()
		Switch.DismissMercenaries("the switch to the new character")
		ML.Try("switch stash", ML.Stash.Leave, ML.Stash.HENRY)
		Switch.ToLife(function()
			ML.Store.Set(Switch.HENRY_KEY, 0)
			Switch.running = false
			ML.Try("switch stash", ML.Stash.Arrive, ML.Stash.LIFE)
			ML.Try("switch beds", ML.BedMarker.HideGameBeds)
			ML.Look.shownGen = nil
			ML.Log("the new character plays")
			Switch.Finish(Switch.ADVICE_TEXT)
		end, function() failedSwitch(ML.Stash.HENRY) end)
	end)
end

function Switch.Run(line)
	if Switch.running or ML.Uninstall.running then
		return
	end
	if ML.Uninstall.IsDone() then
		ML.Log("the new life is over in this save, after ml_uninstall: there is nobody to switch to")
		return
	end
	if ML.Store.Get("state") ~= ML.Life.STATE_STARTED then
		ML.Log("there is no new life in this save yet")
		return
	end
	if string.match(line or "", "^%s*(%S*)") ~= Switch.CONFIRM then
		ML.Log("ml_switch moves the game between Henry and the new character, and saves. Use it with care: switching can "
			.. "break your KCD2 Life save, for instance after the new character took one of Henry's quests. To do it, type: "
			.. "ml_switch " .. Switch.CONFIRM)
		return
	end
	if Switch.HenryPlays() then
		toLife()
	else
		toHenry()
	end
end

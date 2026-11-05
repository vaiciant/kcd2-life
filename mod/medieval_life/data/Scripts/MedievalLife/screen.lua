-- =============================================================================
-- Black screen with centered text, through the HUD (Libs/UI/hud.gfx). While it is up,
-- the player cannot move and the world clock runs at one second per second, because
-- Calendar.SetWorldTimePaused fails in the retail game.
-- =============================================================================
local ML = MedievalLife

ML.Screen = {}
local Screen = ML.Screen

Screen.FADE_IN = 1
Screen.FADE_OUT = 2
Screen.TEXT_LAYOUT = 3
Screen.TEXT_FADE_MS = 1000
Screen.TIME_RATIO = 1
Screen.LOCK_TICK_MS = 100

local function hud(name, ...)
	local args = ML.Pack(...)
	ML.Try("hud " .. name, function() UIAction.CallFunction("hud", -1, name, unpack(args, 1, args.n)) end)
end

function Screen.LockInput(locked)
	ML.Try("input lock", function() ActionMapManager.EnableActionMap("player", not locked) end)
end

-- The engine enables the map again, for example when a dialog or the console closes, so it is locked in a loop.
local function lockTick()
	if Screen.active then
		Screen.LockInput(true)
		Script.SetTimer(Screen.LOCK_TICK_MS, lockTick)
	end
end

function Screen.Show(text)
	Screen.active = true
	lockTick()
	ML.Try("screen time", function()
		Screen.timeRatio = Screen.timeRatio or Calendar.GetWorldTimeRatio()
		Calendar.SetWorldTimeRatio(Screen.TIME_RATIO)
	end)
	hud("SetFaderState", Screen.FADE_IN, "")
	hud("SetNarrativeSubtitles", text, Screen.TEXT_LAYOUT, Screen.TEXT_FADE_MS)
end

-- For text that changes while the screen is up, with no fade.
function Screen.SetText(text)
	hud("SetNarrativeSubtitles", text, Screen.TEXT_LAYOUT, 0)
end

function Screen.Hide()
	hud("HideNarrativeSubtitles", Screen.TEXT_FADE_MS)
	hud("SetFaderState", Screen.FADE_OUT, "")
	Screen.active = false
	Screen.LockInput(false)
	ML.Try("screen time", function()
		Calendar.SetWorldTimeRatio(Screen.timeRatio)
		Screen.timeRatio = nil
	end)
end

-- =============================================================================
-- Settings in Mod Configuration Menu, which is optional: without it the defaults apply.
-- Each time it opens, the menu asks for the settings through one listener, and it tells
-- each change to another. It keeps no values, so they go in the store, and each save has
-- its own. SetValue only works while the listener builds the settings.
-- =============================================================================
local ML = MedievalLife

ML.Settings = {}
local Settings = ML.Settings

Settings.MOD_ID = "medieval_life"
Settings.MONTH_DAYS = "month_days"
-- In the order of the menu, which counts from 0.
Settings.MONTH_CHOICES = { 7, 14, ML.Days.REAL }

local registered

local function monthChoice()
	for index, days in ipairs(Settings.MONTH_CHOICES) do
		if days == ML.Days.MonthDays() then
			return index - 1
		end
	end
	return 0
end

local function build()
	ML.Log("settings built")
	MCM.AddMod(Settings.MOD_ID, "@ui_ml_settings")
	MCM.AddCategory(Settings.MOD_ID, "@ui_ml_settings_calendar", "@ui_ml_settings_calendar_tip")
	MCM.AddDropdown(Settings.MOD_ID, Settings.MONTH_DAYS, "@ui_ml_settings_month_days", "@ui_ml_settings_month_days_tip",
		"7|14|@ui_ml_settings_month_real", 0)
	MCM.SetValue(Settings.MOD_ID, Settings.MONTH_DAYS, monthChoice())
end

local function changed(id, value)
	local days = Settings.MONTH_CHOICES[(tonumber(value) or -1) + 1]
	ML.Log("setting", id, value, "month days", days)
	if id == Settings.MONTH_DAYS and days and player then
		ML.Days.SetMonthDays(days)
	end
end

function Settings.Register()
	if registered or not MCM then
		return
	end
	registered = true
	MCM.RegisterBuildSettingsListener(function() ML.Try("settings build", build) end)
	MCM.RegisterValueChangeListener(Settings.MOD_ID, function(id, value)
		ML.Try("settings change", function() changed(id, value) end)
	end)
	ML.Log("settings registered")
end

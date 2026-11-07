-- =============================================================================
-- Settings in Mod Configuration Menu, which is optional: without it the defaults apply.
-- Each time it opens, the menu asks for the settings through one listener, and it tells
-- each change to another. It keeps no values, so they go in the store, and each save has
-- its own. SetValue only works while the listener builds the settings.
-- The work and the errands have settings of their own: what they pay and teach,
-- what work costs, and how hard the errands are.
-- =============================================================================
local ML = MedievalLife

ML.Settings = {}
local Settings = ML.Settings

Settings.MOD_ID = "medieval_life"
Settings.MONTH_DAYS = "month_days"
-- In the order of the menu, which counts from 0.
Settings.MONTH_CHOICES = { 7, 14, ML.Days.REAL }
Settings.KEY = "settings"
-- 1 while the pay of work is not the usual one: the dialog of the steady job then says its terms with ml_work_wage.
Settings.WORK_PAY_VARIABLE = "ml_work_pay_custom"
Settings.WORK_WAGE_VARIABLE = "ml_work_wage"
-- And the same for the errands: the offers say no amount (ml_order_dialog.xml).
Settings.ORDER_PAY_VARIABLE = "ml_order_pay_custom"

-- The sliders, by category, in the order of the menu. Each value is a whole number: a percent, hours, days or points.
-- The texts are ui_ml_settings_<id> and ui_ml_settings_<id>_tip. A percent is 100 by default; the others take their
-- default from orders.toml (rule), which is loaded after this file.
Settings.CATEGORIES = {
	{
		id = "work",
		{ id = "work_pay", min = 25, max = 300, step = 25, default = 100, suffix = "%" },
		{ id = "work_xp", min = 25, max = 300, step = 25, default = 100, suffix = "%" },
		{ id = "work_cost", min = 0, max = 200, step = 25, default = 100, suffix = "%" },
	},
	{
		id = "orders",
		{ id = "order_pay", min = 25, max = 300, step = 25, default = 100, suffix = "%" },
		{ id = "order_deadline", min = 12, max = 72, step = 6, rule = "deadline_hours", suffix = " h" },
		{ id = "order_days", min = 2, max = 7, step = 1, rule = "days_between", suffix = "" },
		{ id = "order_trust", min = 0, max = 200, step = 25, default = 100, suffix = "%" },
		{ id = "order_reputation", min = 0, max = 150, step = 25, default = 100, suffix = "%" },
		{ id = "order_fail_points", min = 0, max = 20, step = 1, rule = "fail_points", suffix = "" },
		{ id = "order_guard", min = 0, max = 10, step = 1, rule = "crime_fails", suffix = "" },
	},
}

local byId = {}
for _, category in ipairs(Settings.CATEGORIES) do
	for _, setting in ipairs(category) do
		byId[setting.id] = setting
	end
end

local registered

local function monthChoice()
	for index, days in ipairs(Settings.MONTH_CHOICES) do
		if days == ML.Days.MonthDays() then
			return index - 1
		end
	end
	return 0
end

local function default(setting)
	return setting.rule and ML.ORDER_RULES[setting.rule] or setting.default
end

-- The value of a setting in this save, or its default. Without a player there is no save to read.
function Settings.Get(id)
	local setting = byId[id]
	local value = player and ML.Store.Get(Settings.KEY, {})[id]
	return type(value) == "number" and value or default(setting)
end

-- A percent setting as a factor: 150 is 1.5.
function Settings.Factor(id)
	return Settings.Get(id) / 100
end

-- Whether a setting is not at its default.
function Settings.Changed(id)
	return Settings.Get(id) ~= default(byId[id])
end

local function build()
	ML.Log("settings built")
	MCM.AddMod(Settings.MOD_ID, "@ui_ml_settings")
	MCM.AddCategory(Settings.MOD_ID, "@ui_ml_settings_calendar", "@ui_ml_settings_calendar_tip")
	MCM.AddDropdown(Settings.MOD_ID, Settings.MONTH_DAYS, "@ui_ml_settings_month_days", "@ui_ml_settings_month_days_tip",
		"7|14|@ui_ml_settings_month_real", 0)
	MCM.SetValue(Settings.MOD_ID, Settings.MONTH_DAYS, monthChoice())
	for _, category in ipairs(Settings.CATEGORIES) do
		MCM.AddCategory(Settings.MOD_ID, "@ui_ml_settings_" .. category.id, "@ui_ml_settings_" .. category.id .. "_tip")
		for _, setting in ipairs(category) do
			local text = "@ui_ml_settings_" .. setting.id
			MCM.AddSlider(Settings.MOD_ID, setting.id, text, text .. "_tip", setting.min, setting.max, setting.step, default(setting), setting.suffix)
			MCM.SetValue(Settings.MOD_ID, setting.id, Settings.Get(setting.id))
		end
	end
end

-- A value from the menu, inside the range and on a step of the slider.
local function fit(setting, value)
	local steps = math.floor((math.min(math.max(value, setting.min), setting.max) - setting.min) / setting.step + 0.5)
	return setting.min + steps * setting.step
end

local function changed(id, value)
	if id == Settings.MONTH_DAYS then
		local days = Settings.MONTH_CHOICES[(tonumber(value) or -1) + 1]
		ML.Log("setting", id, value, "month days", days)
		if days and player then
			ML.Days.SetMonthDays(days)
		end
		return
	end
	local setting, number = byId[id], tonumber(value)
	if not setting or not number or not player then
		ML.Log("setting ignored", id, value)
		return
	end
	local values = ML.Store.Get(Settings.KEY, {})
	values[id] = fit(setting, number)
	ML.Store.Set(Settings.KEY, values)
	ML.Log("setting", id, value, "->", values[id])
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

-- For ml_settings: every setting with its value in this save. ml_settings <id> <value> changes one, as the menu does.
function Settings.Report(line)
	local id, value = string.match(line or "", "^%s*(%S+)%s+(%S+)")
	if id then
		changed(id, value)
	end
	for _, category in ipairs(Settings.CATEGORIES) do
		for _, setting in ipairs(category) do
			ML.Log("setting", setting.id, "=", Settings.Get(setting.id), "default", default(setting))
		end
	end
	ML.Log("setting", Settings.MONTH_DAYS, "=", ML.Days.MonthDays())
end

-- The dialogs read it with gvar. A region change loses it, so it is set on every tick.
ML.TickHandlers[#ML.TickHandlers + 1] = function()
	Variables.SetGlobal(Settings.WORK_PAY_VARIABLE, Settings.Changed("work_pay") and 1 or 0)
	Variables.SetGlobal(Settings.ORDER_PAY_VARIABLE, Settings.Changed("order_pay") and 1 or 0)
	-- The wage of the steady job, in hundredths: its terms say it from one text per wage.
	Variables.SetGlobal(Settings.WORK_WAGE_VARIABLE, ML.Jobs.Rate(ML.JOB_RULES.steady_wage))
end

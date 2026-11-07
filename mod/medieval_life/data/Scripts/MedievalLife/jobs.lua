-- =============================================================================
-- Paid work: the option in the dialog of each employer (ml_work_dialog.xml). The data
-- is in mod/medieval_life/jobs.toml. Lua runs the clock of the vanilla wait: the engine
-- does no waiting here, because its forced wait needs -devmode. So Lua moves the hour,
-- applies the cost and paints Libs/UI/SkipTime.gfx on each step. Type 9 of AddDialog is a
-- forced wait that keeps its message. SetTime goes in hours of the day, and SetInterval
-- in the hours left. The money, the experience and the entry in the book of trades
-- arrive when the clock closes, so their notices show, along with a line that sums up
-- the work.
-- =============================================================================
local ML = MedievalLife

ML.Jobs = {}
local Jobs = ML.Jobs

Jobs.HOURS_VARIABLE = "ml_work_hours"
-- 1 when the nearest employer is a site that Henry's story has in the world: the dialog offers work only then.
Jobs.SITE_OPEN_VARIABLE = "ml_site_open"
-- The dialog is closing when it calls Start.
Jobs.START_DELAY_MS = 1000
-- Who gives the work is the employer nearest to the player.
Jobs.TALK_RANGE = 8
Jobs.CLOCK_TYPE = 9
Jobs.CLOCK_TICK_MS = 100
Jobs.CLOCK_HOUR_MS = 1500
Jobs.CLOCK_START_MS = 800
Jobs.CLOCK_END_MS = 300
Jobs.SUMMARY_SECONDS = 6
Jobs.OVERSLEEP_BUFF = "a5e4791a-f5a6-403e-9161-5b8a22966751"
-- Hunger and tiredness per hour: twice what the game takes on its own.
Jobs.COST_PER_HOUR = 4.2

local function clock(name, ...)
	local args = ML.Pack(...)
	ML.Try("clock " .. name, function() UIAction.CallFunction("SkipTime", 0, name, unpack(args, 1, args.n)) end)
end

local function paint(hoursLeft)
	clock("SetTime", Calendar.GetWorldHourOfDay())
	clock("SetInterval", hoursLeft)
	ML.Try("clock stats", function()
		local soul = player.soul
		clock("SetStats", soul:GetState("health"), soul:GetState("exhaust"), soul:GetState("hunger"), 0, false, false, false, false, false)
	end)
end

-- The setting work_cost scales it: 50 is what the game takes, 0 nothing.
local function applyCost(hours)
	ML.Try("work cost", function()
		local soul, cost = player.soul, hours * Jobs.COST_PER_HOUR * ML.Settings.Factor("work_cost")
		soul:SetState("hunger", math.max(0, soul:GetState("hunger") - cost))
		soul:SetState("exhaust", math.max(0, soul:GetState("exhaust") - cost))
	end)
end

local function addExperience(name, isStat, amount)
	ML.Try("work xp", function()
		if isStat then
			player.soul:AddStatXP(name, amount)
		else
			player.soul:AddSkillXP(name, amount)
		end
	end)
end

-- Food to take away, to eat when the player wants to.
local function giveMeal(meal)
	for _, item in ipairs(meal) do
		ML.Try("work meal", function()
			player.inventory:CreateItem(item[1], item[2], 1)
			Game.ShowItemsTransfer(item[1], 1)
		end)
	end
end

-- With the pay or the experience changed in the settings, the written lines do not fit: the summary is put together
-- here, with the names of the skills as the game writes them. The amounts go with a point.
Jobs.CUSTOM_SUMMARY = "@ml_work_summary_custom %d h: +%g g. %s +%d XP, %s +%d XP."

local function summary(site, hours, steady, amount, xpMain, xpSecondary)
	if ML.Settings.Changed("work_pay") or ML.Settings.Changed("work_xp") then
		return string.format(Jobs.CUSTOM_SUMMARY, hours, amount / 10, site.main_text, xpMain, site.secondary_text, xpSecondary)
	end
	-- Lua cannot read translated text, so there is one written line for each length of work.
	-- With an economy mod, the line that says its pay.
	return (steady and site.steady_summary or site.summary) .. hours .. (ML.Economy.active and "_economy" or "")
end

local function pay(site, hours, steady)
	local rules = ML.JOB_RULES
	-- The settings scale the pay and the experience. Money goes in whole tenths of a groschen.
	local amount = math.floor(ML.Economy.Money(hours * (steady and rules.steady_wage or rules.wage) * ML.Settings.Factor("work_pay")) + 0.5)
	local xp = ML.Settings.Factor("work_xp")
	local xpMain, xpSecondary = math.floor(hours * rules.xp_main * xp + 0.5), math.floor(hours * rules.xp_secondary * xp + 0.5)
	ML.Try("work pay", function()
		player.inventory:CreateItem(ML.Life.COIN_ITEM, 1, amount)
		Game.ShowItemsTransfer(ML.Life.COIN_ITEM, amount)
	end)
	addExperience(site.main, site.main_is_stat, xpMain)
	addExperience(site.secondary, site.secondary_is_stat, xpSecondary)
	ML.WorkBook.Record(site.key, hours, steady)
	-- With The Nutrition Mod, the hours of work use up food and drink too.
	ML.Try("work nutrition", ML.Nutrition.Pass, hours)
	ML.Try("work trust", ML.Orders.AddWork, site.key, hours, steady)
	ML.Reputation.Work(site, hours)
	-- The clock moves the calendar by hand, so the game does not count those hours as awake,
	-- and it would go on saying that the character has slept too much.
	ML.Try("work oversleep", function() player.soul:RemoveAllBuffsByGuid(Jobs.OVERSLEEP_BUFF) end)
	ML.Try("work summary", function() Game.SendInfoText(summary(site, hours, steady, amount, xpMain, xpSecondary), false, nil, Jobs.SUMMARY_SECONDS) end)
	if steady then
		giveMeal(rules.steady_meal)
	elseif hours >= rules.casual_meal_min_hours then
		giveMeal(rules.casual_meal)
	end
	ML.Log("work paid", site.key, "hours=", hours, "money=", player.inventory:GetMoney())
end

local function runClock(site, hours, steady)
	local steps = math.ceil(hours * Jobs.CLOCK_HOUR_MS / Jobs.CLOCK_TICK_MS)
	local stepHours = hours / steps
	local done, finished = 0, false
	local function finish()
		if finished then
			return
		end
		finished = true
		ML.Screen.LockInput(false)
		clock("RemoveDialog")
		ML.Try("clock hide", function() UIAction.HideElement("SkipTime", 0) end)
		ML.Try("recalculate", function() XGenAIModule.SendMessageToEntity(player.this.id, "timekeeper:recalculate", "") end)
		pay(site, hours, steady)
	end
	local function tick()
		if finished then
			return
		end
		done = done + 1
		ML.Screen.LockInput(true)
		ML.Try("clock time", function() Calendar.SetWorldTime(Calendar.GetWorldTime() + stepHours * 3600) end)
		applyCost(stepHours)
		paint(hours - done * stepHours)
		if done < steps then
			Script.SetTimer(Jobs.CLOCK_TICK_MS, tick)
			return
		end
		clock("FadeOutDialog")
		Script.SetTimer(Jobs.CLOCK_END_MS, finish)
	end
	ML.Try("clock show", function() UIAction.ShowElement("SkipTime", 0) end)
	clock("AddDialog", Jobs.CLOCK_TYPE, site.text, "wait", "", 0, 0)
	paint(hours)
	clock("StartAction")
	Script.SetTimer(Jobs.CLOCK_START_MS, tick)
	-- If something cuts the chain of timers, the player must not stay locked.
	Script.SetTimer(Jobs.CLOCK_START_MS + steps * Jobs.CLOCK_TICK_MS * 2 + 5000, finish)
end

function Jobs.NearestSite()
	local position, best, bestDistance = player:GetWorldPos(), nil, Jobs.TALK_RANGE
	for _, site in ipairs(ML.JOB_SITES) do
		for _, name in ipairs(ML.Story.Open(site.requires) and site.npcs or {}) do
			local entity = System.GetEntityByName(name)
			if entity then
				local other = entity:GetWorldPos()
				local distance = math.sqrt((other.x - position.x) ^ 2 + (other.y - position.y) ^ 2)
				if distance < bestDistance then
					best, bestDistance = site, distance
				end
			end
		end
	end
	return best
end

function Jobs.Start(hours)
	local site = ML.Try("work site", Jobs.NearestSite)
	if not site then
		ML.Log("ERROR work: no employer nearby")
		return
	end
	ML.Log("work starts", site.key, "hours=", hours)
	ML.Screen.LockInput(true)
	Script.SetTimer(Jobs.START_DELAY_MS, function() runClock(site, hours) end)
end

function Jobs.StartShift(site, hours)
	ML.Log("shift starts", site.key, "hours=", hours)
	ML.Screen.LockInput(true)
	Script.SetTimer(Jobs.START_DELAY_MS, function() runClock(site, hours, true) end)
end

-- The working day of a site: its own hours, when its NPC keeps other hours in the game, or the mod's.
function Jobs.Day(site)
	local rules = ML.JOB_RULES
	return site and site.first_hour or rules.first_hour, site and site.last_hour or rules.last_hour
end

-- What the employer says when there is no work now, as a notice: "Work here: 11:00 - 18:00".
Jobs.DAY_TEXT = "@ml_work_hours_here %d:00 - %d:00"
Jobs.DAY_SECONDS = 8

function Jobs.ShowHours()
	local first, last = Jobs.Day(ML.Try("job site", Jobs.NearestSite))
	ML.Try("work hours", function() Game.SendInfoText(string.format(Jobs.DAY_TEXT, first, last), false, nil, Jobs.DAY_SECONDS) end)
end

-- The dialog reads it with gvar: the hours left in the working day of the nearest site, or 0 if they are too few.
local function publishHours()
	local rules, site = ML.JOB_RULES, ML.Try("job site", Jobs.NearestSite)
	local first, last = Jobs.Day(site)
	local hour = math.floor(Calendar.GetWorldHourOfDay())
	local hours = hour >= first and last - hour or 0
	Variables.SetGlobal(Jobs.HOURS_VARIABLE, hours >= rules.min_hours and hours or 0)
	Variables.SetGlobal(Jobs.SITE_OPEN_VARIABLE, site and 1 or 0)
end

ML.TickHandlers[#ML.TickHandlers + 1] = publishHours

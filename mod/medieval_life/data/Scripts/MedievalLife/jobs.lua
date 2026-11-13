-- =============================================================================
-- Paid work: the option in the dialog of each employer (ml_work_dialog.xml). The data
-- is in mod/medieval_life/jobs.toml. Lua runs the clock of the vanilla wait: the engine
-- does no waiting here, because its forced wait needs -devmode. So Lua moves the hour,
-- applies the cost and paints Libs/UI/SkipTime.gfx on each step. Type 9 of AddDialog is a
-- forced wait that keeps its message. SetTime goes in hours of the day, and SetInterval
-- in the hours left. The money, the experience and the entry in the book of trades
-- arrive when the clock closes, so their notices show, along with a line that sums up
-- the work.
-- The window is only painted: StartAction and FadeOutDialog are not called. StartAction is its confirm button:
-- it sent the engine onConfirm, the start of the fade and onStatsSimulation on every frame, and FadeOutDialog the end
-- of the fade, for a wait the engine had not opened. After a work, the game crashed as the book was opened, every time. With the window open the game draws no other interface under it, so no black either:
-- the fade of the HUD and a black element of the mod did not show.
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
-- Hunger per hour: twice what the game takes on its own. Tiredness: one and a half. A shift of 10 hours cost 42
-- and 12 hours in the bed of the steady job gave back 22; that bed is a good one now (employee_bed.lua), and a shift and
-- 10 hours of sleep come out about even.
Jobs.HUNGER_PER_HOUR = 4.2
Jobs.EXHAUST_PER_HOUR = 3.1

local function clock(name, ...)
	local args = ML.Pack(...)
	ML.Try("clock " .. name, function() UIAction.CallFunction("SkipTime", 0, name, unpack(args, 1, args.n)) end)
end

local function stats()
	ML.Try("clock stats", function()
		local soul = player.soul
		clock("SetStats", soul:GetState("health"), soul:GetState("exhaust"), soul:GetState("hunger"), 0, false, false, false, false, false)
	end)
end

-- With no StartAction, SetInterval of the window asks the engine to simulate the stats of a wait (SetInterval in
-- SkipTime.gfx calls onStatsSimulation while the window is not going), and the engine paints its own a moment later:
-- food and energy went up on the clock. Put in again at once, they flickered. With the interval only once, the
-- wheel turned and the hand stood still: SetInterval is what places the hand, the gold arc and the number of
-- hours. Once an hour of the game worked, but went by jumps. So the wheel turns on every step, with SetTime,
-- which asks the engine nothing, and the interval goes in every INTERVAL_TICKS steps, a third of an hour, about half a
-- second: the hand slides there on its own. The stats of the character go in on every step, and again after the
-- engine's answer to each interval.
Jobs.STATS_AGAIN_MS = { 1, 40, 120 }
Jobs.INTERVAL_TICKS = 5

local function paint(hoursLeft, withInterval)
	clock("SetTime", Calendar.GetWorldHourOfDay())
	if withInterval then
		clock("SetInterval", hoursLeft)
	end
	stats()
	if withInterval then
		for _, ms in ipairs(Jobs.STATS_AGAIN_MS) do
			Script.SetTimer(ms, stats)
		end
	end
end

-- The setting work_cost scales it: 50 is what the game takes, 0 nothing.
local function applyCost(hours)
	ML.Try("work cost", function()
		local soul, factor = player.soul, hours * ML.Settings.Factor("work_cost")
		soul:SetState("hunger", math.max(0, soul:GetState("hunger") - Jobs.HUNGER_PER_HOUR * factor))
		soul:SetState("exhaust", math.max(0, soul:GetState("exhaust") - Jobs.EXHAUST_PER_HOUR * factor))
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
-- Each food with how many of it. One at a time, as the game makes several (player.lua), and one notice each.
local function giveMeal(meal)
	for _, item in ipairs(meal) do
		ML.Try("work meal", function()
			local count = item[3] or 1
			for _ = 1, count do
				player.inventory:CreateItem(item[1], item[2], 1)
			end
			Game.ShowItemsTransfer(item[1], count)
		end)
	end
end

-- With the pay or the experience changed in the settings, the written lines do not fit: the summary is put together
-- here, with the names of the skills as the game writes them. The amounts go with a point.
-- SendInfoText shows each word of the line on its own: a key with @ is translated and a whole number stays, but any
-- other word, as "h:", "+1.8" or "XP,", is dropped. So everything but the hours is a key, and each amount has a
-- key of its own, written by generate_jobs.py. The line reads as the written ones:
-- "Worked 2 h at 0.9 g/h: +1.8 g. Speech +12 XP, Craftsmanship +4 XP."
Jobs.CUSTOM_SUMMARY = "@ml_work_summary_custom %d @ml_work_rate_%d @ml_work_pay_%d %s @ml_work_xp_%d %s @ml_work_xp_last_%d"
-- Past the amounts with a key, which the settings do not reach: the line without the pay.
Jobs.CUSTOM_SUMMARY_SHORT = "@ml_work_summary_custom %d @ml_work_summary_custom_hours %d @ml_work_summary_custom_xp_in %s "
	.. "@ml_work_summary_custom_and %d @ml_work_summary_custom_xp_in %s"

-- The wage per hour with the pay of the settings and the economy mod, in hundredths of a groschen: from a wage of the
-- rules, in tenths. generate_jobs.py works it out the same way for the texts (steady_rates).
function Jobs.Rate(tenths)
	local rate = tenths * 10 * ML.Settings.Factor("work_pay")
	if ML.Economy.active then
		rate = rate * ML.ECONOMY.price_factor
	end
	return math.floor(rate + 0.5)
end

local function summary(site, hours, steady, amount, xpMain, xpSecondary)
	if ML.Settings.Changed("work_pay") or ML.Settings.Changed("work_xp") then
		local rules = ML.JOB_RULES
		local rate = Jobs.Rate(steady and rules.steady_wage or rules.wage)
		if amount <= rules.summary_pay_max and rate <= rules.summary_rate_max and math.max(xpMain, xpSecondary) <= rules.summary_xp_max then
			return string.format(Jobs.CUSTOM_SUMMARY, hours, rate, amount, site.main_text, xpMain, site.secondary_text, xpSecondary)
		end
		return string.format(Jobs.CUSTOM_SUMMARY_SHORT, hours, xpMain, site.main_text, xpSecondary, site.secondary_text)
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

local function runClock(site, hours, steady, onDone)
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
		-- The clock is over: the black screen goes.
		if onDone then
			ML.Try("clock done", onDone)
		end
	end
	local function tick()
		if finished then
			return
		end
		done = done + 1
		ML.Screen.LockInput(true)
		ML.Try("clock time", function() Calendar.SetWorldTime(Calendar.GetWorldTime() + stepHours * 3600) end)
		applyCost(stepHours)
		paint(hours - done * stepHours, done % Jobs.INTERVAL_TICKS == 0 or done == steps)
		if done < steps then
			Script.SetTimer(Jobs.CLOCK_TICK_MS, tick)
			return
		end
		Script.SetTimer(Jobs.CLOCK_END_MS, finish)
	end
	ML.Try("clock show", function() UIAction.ShowElement("SkipTime", 0) end)
	clock("AddDialog", Jobs.CLOCK_TYPE, site.text, "wait", "", 0, 0)
	paint(hours, true)
	Script.SetTimer(Jobs.CLOCK_START_MS, tick)
	-- If something cuts the chain of timers, the player must not stay locked.
	Script.SetTimer(Jobs.CLOCK_START_MS + steps * Jobs.CLOCK_TICK_MS * 2 + 5000, finish)
end

-- The black screen of the mod first, with the text of the work, as the one of the name: it keeps the player still from
-- the moment they agree. The clock opens a moment later, as it was, and the screen goes when the clock is over,
-- or by itself a little after the clock's own way out. The clock is set on a timer of its own before the screen, so
-- nothing of the screen can keep it from starting.
Jobs.SCREEN_LEAD_MS = 1500
Jobs.SCREEN_SPARE_MS = 3000

local function startOnScreen(site, hours, steady)
	local token = {}
	Jobs.screen = token
	local function done()
		if Jobs.screen == token then
			Jobs.screen = nil
			ML.Screen.Hide()
		end
	end
	local steps = math.ceil(hours * Jobs.CLOCK_HOUR_MS / Jobs.CLOCK_TICK_MS)
	local opens = Jobs.START_DELAY_MS + Jobs.SCREEN_LEAD_MS
	Script.SetTimer(opens, function() runClock(site, hours, steady, done) end)
	Script.SetTimer(opens + Jobs.CLOCK_START_MS + steps * Jobs.CLOCK_TICK_MS * 2 + 5000 + Jobs.SCREEN_SPARE_MS, function()
		if Jobs.screen == token then
			ML.Log("work screen: gone by its limit")
			done()
		end
	end)
	ML.Try("work screen", ML.Screen.Show, site.text)
end

-- Whether a site still has someone there: one of its NPC alive, as the game asks, entity.actor:IsDead(). The game
-- takes a body away after a while, so in the site's own region an NPC it does not find is gone too. Out of that region
-- nothing is known, and the site counts as there. region is ML.Region(), given by a caller that asks for many sites.
function Jobs.Staffed(site, region)
	region = region or ML.Region()
	local here = (site.region or "trosky") == region
	for _, name in ipairs(site.npcs or {}) do
		local entity = System.GetEntityByName(name)
		if entity then
			if not ML.Try("npc dead", function() return entity.actor and entity.actor:IsDead() end) then
				return true
			end
		elseif not here then
			return true
		end
	end
	return false
end

-- Sure that a site lost its person: one of its NPC found dead, and none alive. An errand already taken is called
-- off only then: a body the game took away, or an NPC not there yet right after a load, must not call it off.
function Jobs.Dead(site)
	local dead = false
	for _, name in ipairs(site.npcs or {}) do
		local entity = System.GetEntityByName(name)
		if entity then
			if not ML.Try("npc dead", function() return entity.actor and entity.actor:IsDead() end) then
				return false
			end
			dead = true
		end
	end
	return dead
end

-- Whether a site gives work and errands now: the story has it in the world, and someone is there.
function Jobs.Open(site, region)
	return ML.Story.Open(site.requires) and Jobs.Staffed(site, region)
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
	startOnScreen(site, hours)
end

function Jobs.StartShift(site, hours)
	ML.Log("shift starts", site.key, "hours=", hours)
	ML.Screen.LockInput(true)
	startOnScreen(site, hours, true)
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

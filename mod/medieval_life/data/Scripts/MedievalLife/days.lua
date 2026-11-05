-- =============================================================================
-- Days and date of the new life. The game has no months or years: Calendar only counts
-- days. So the date is ours: a life starts on the first of June of 1403, the month of the
-- letters and registers of Kuttenberg, and a month lasts 7 or 14 days of the game, or as
-- long as in the real calendar. The steady job goes on counting days of the game.
--
-- =============================================================================
local ML = MedievalLife

ML.Days = {}
local Days = ML.Days

Days.LIFE_DAY_KEY = "life_start_day"
Days.MONTH_DAYS_KEY = "month_days"
-- The count of the date: the first day of a month, and how many months there were by then.
-- Each change of the length of a month starts a new count, so the date does not jump.
Days.COUNT_DAY_KEY = "date_count_day"
Days.COUNT_MONTHS_KEY = "date_count_months"
Days.FIRST_MONTHS = 1403 * 12 + 5
-- As long as the week of the steady job: six days of work and one off.
Days.MONTH_DAYS = 7
-- Instead of a number of days, the months of the calendar.
Days.REAL = 0
Days.REAL_LENGTHS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
Days.NOTICE_SECONDS = 6
Days.REFUSED_TEXT = "@ml_month_days_refused"
-- The HUD comes back a moment after a wait or a sleep.
Days.SKIP_WAIT_TICKS = 3

local seenGen, seenDay, refused
local waitTicks = 0

function Days.Start()
	local today = Calendar.GetWorldDay()
	ML.Store.Set(Days.LIFE_DAY_KEY, today)
	ML.Store.Set(Days.COUNT_DAY_KEY, today)
	ML.Store.Set(Days.COUNT_MONTHS_KEY, Days.FIRST_MONTHS)
end

-- The world day the life started.
function Days.LifeStart()
	return ML.Store.Get(Days.LIFE_DAY_KEY, Calendar.GetWorldDay())
end

-- The day the life starts is day 1, and each midnight adds one.
function Days.Current()
	local today = Calendar.GetWorldDay()
	return today - ML.Store.Get(Days.LIFE_DAY_KEY, today) + 1
end

-- There is no store in the main menu, where the settings can open too.
function Days.MonthDays()
	return player and ML.Store.Get(Days.MONTH_DAYS_KEY, Days.MONTH_DAYS) or Days.MONTH_DAYS
end

-- Bohemia used the Julian calendar: every fourth year is a leap year.
local function monthLength(mode, months)
	if mode ~= Days.REAL then
		return mode
	end
	local month, year = months % 12 + 1, math.floor(months / 12)
	return Days.REAL_LENGTHS[month] + ((month == 2 and year % 4 == 0) and 1 or 0)
end

-- ahead: days after today, for a date to come.
local function count(mode, ahead)
	local today = Calendar.GetWorldDay() + (ahead or 0)
	local passed = today - ML.Store.Get(Days.COUNT_DAY_KEY, today)
	local months = ML.Store.Get(Days.COUNT_MONTHS_KEY, Days.FIRST_MONTHS)
	while passed >= monthLength(mode, months) do
		passed = passed - monthLength(mode, months)
		months = months + 1
	end
	return passed + 1, months
end

-- The day of the month, the month from 1 to 12, and the year: today, or that many days ahead.
function Days.Date(ahead)
	local day, months = count(Days.MonthDays(), ahead)
	return day, months % 12 + 1, math.floor(months / 12)
end

-- A month can only get shorter if today still fits in it.
function Days.SetMonthDays(mode)
	local day, months = count(Days.MonthDays())
	if day > monthLength(mode, months) then
		refused = true
		return false
	end
	ML.Store.Set(Days.COUNT_MONTHS_KEY, months)
	ML.Store.Set(Days.COUNT_DAY_KEY, Calendar.GetWorldDay() - day + 1)
	ML.Store.Set(Days.MONTH_DAYS_KEY, mode)
	return true
end

-- The game looks up each word on its own, so a key can go between two numbers.
function Days.Show()
	local day, month, year = Days.Date()
	ML.Try("date notice", function() Game.SendInfoText(day .. " @ml_month_" .. month .. " " .. year, false, nil, Days.NOTICE_SECONDS) end)
end

-- The date shows when a day starts, however it got there: midnight, a wait, a sleep or a command.
function Days.Update()
	if not ML.Life.IsStarted() then
		return
	end
	if refused then
		refused = false
		ML.Try("date refused", function() Game.SendInfoText(Days.REFUSED_TEXT, false, nil, Days.NOTICE_SECONDS) end)
	end
	local today = Calendar.GetWorldDay()
	if seenGen ~= ML.gen then
		seenGen, seenDay, waitTicks = ML.gen, today, 0
	elseif ML.Life.sleepStart then
		waitTicks = Days.SKIP_WAIT_TICKS
	elseif waitTicks > 0 then
		waitTicks = waitTicks - 1
	elseif today ~= seenDay then
		seenDay = today
		Days.Show()
	end
end

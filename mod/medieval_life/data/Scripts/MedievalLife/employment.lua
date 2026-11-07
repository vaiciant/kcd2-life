-- =============================================================================
-- The steady job, at the sites of jobs.toml with steady = true. Hiring and quitting come
-- from the dialog, which also tells Skald for the journal (ml_employment.xml). The shift
-- is the most that fits in the day, at least steady_min_hours, and the dialog says how
-- many. Working days and days off go in a cycle from the day of hiring. A day without a
-- shift, arriving drunk or arriving late two working days in a row is a fault. Enough
-- faults or leaving the region is a dismissal. Around the bed the employee may be anywhere, private or not.
-- =============================================================================
local ML = MedievalLife

ML.Employment = {}
local Employment = ML.Employment

Employment.OFFER_VARIABLE = "ml_job_offer"
Employment.STATE_VARIABLE = "ml_shift_state"
Employment.HOURS_VARIABLE = "ml_shift_hours"
Employment.LATE_VARIABLE = "ml_shift_late"
Employment.START_NOW_VARIABLE = "ml_job_start_now"
Employment.DRUNK_VARIABLE = "ml_drunk"
Employment.NAKED_VARIABLE = "ml_naked"
Employment.DISTRUST_VARIABLE = "ml_distrust"
-- How late the shift is. The first day is a warning and the second one a fault, which starts over.
Employment.LATE_NONE = 0
Employment.LATE_WARNING = 1
Employment.LATE_FAULT = 2
-- What the employer answers to asking for the job, and for the shift. The dialog reads the number.
Employment.OFFER_NONE = 0
Employment.OFFER_OPEN = 1
Employment.OFFER_WAIT = 2
Employment.OFFER_NO_BOOK = 3
Employment.OFFER_HAS_JOB = 4
Employment.OFFER_DRUNK = 5
Employment.OFFER_TOO_LATE = 6
Employment.OFFER_NAKED = 7
Employment.OFFER_DISTRUST = 8
-- Owing that business for an order: no work of any kind until it is paid.
Employment.OFFER_OWED = 9
Employment.SHIFT_NONE = 0
Employment.SHIFT_READY = 1
Employment.SHIFT_DAY_OFF = 2
Employment.SHIFT_TOO_LATE = 3
Employment.SHIFT_DRUNK = 4
Employment.SHIFT_NO_BOOK = 5
Employment.SHIFT_DONE = 6
Employment.SHIFT_TOO_EARLY = 7
Employment.SHIFT_STILL_DRUNK = 8
Employment.SHIFT_NAKED = 9
Employment.SHIFT_STILL_NAKED = 10
Employment.DRUNK_LEVEL = 0.32
Employment.NOTICE_SECONDS = 6
-- Tells the journal about a dismissal. Skald may only see a token after a load, so it goes twice.
Employment.FIRED_TOKEN = "2ae07c17-6972-5c2d-ad61-1ac3f42c532c"
-- An origin that starts with a job has no dialog to tell the journal.
Employment.HIRED_TOKEN = "38bfcd15-b814-5c40-ab90-08a03f54eef4"
-- Tell Skald that the employee went in or out of the workplace.
Employment.AREA_IN_TOKEN = "3cf1f02c-f2c8-51bf-8f86-5c0465e5158a"
Employment.AREA_OUT_TOKEN = "2e283b32-7623-52bd-93c0-5817c1223150"
Employment.QUEST_TRIES = 2

local function notice(text)
	ML.Try("job notice", function() Game.SendInfoText(text, false, nil, Employment.NOTICE_SECONDS) end)
end

local function today()
	return Calendar.GetWorldDay()
end

local function isWorkday(day)
	local rules = ML.JOB_RULES
	return (day - ML.Store.Get("job_start_day")) % (rules.steady_work_days + rules.steady_days_off) < rules.steady_work_days
end

function Employment.Site()
	local key = ML.Store.Get("job_site", "")
	for _, site in ipairs(ML.JOB_SITES) do
		if site.key == key then
			return site
		end
	end
end

local function activeFaults()
	local rules, faults, active = ML.JOB_RULES, ML.Store.Get("job_faults", {}), {}
	for _, day in ipairs(faults) do
		if today() - day < rules.steady_fault_days then
			active[#active + 1] = day
		end
	end
	return active
end

-- The wait to ask again belongs to that employer: the others do not know about it.
local function finish(rehireDays)
	local rehire = ML.Store.Get("job_rehire", {})
	rehire[ML.Store.Get("job_site", "")] = today() + rehireDays
	ML.Store.Set("job_rehire", rehire)
	ML.Store.Set("job_site", "")
	ML.Store.Set("job_faults", {})
	ML.Try("job bed", ML.EmployeeBed.Remove)
end

function Employment.Quit()
	ML.Log("job quit")
	finish(ML.JOB_RULES.steady_rehire_quit_days)
	notice("@ml_steady_quit")
end

function Employment.Fire(text)
	ML.Log("job fired", text)
	finish(ML.JOB_RULES.steady_rehire_fired_days)
	ML.Store.Set("job_quest_tries", Employment.QUEST_TRIES)
	Employment.questGen = nil
	notice(text)
end

-- For ml_uninstall: the job ends with no notice, and the journal closes its quest as Done, as with a dismissal.
function Employment.Leave()
	if not Employment.Site() then
		return
	end
	ML.Log("job left for uninstall")
	finish(ML.JOB_RULES.steady_rehire_quit_days)
	ML.Life.SendToken(Employment.FIRED_TOKEN)
end

function Employment.AddFault(day)
	if not Employment.Site() then
		return
	end
	local faults = activeFaults()
	faults[#faults + 1] = day or today()
	ML.Store.Set("job_faults", faults)
	ML.Log("job fault", #faults, "of", ML.JOB_RULES.steady_faults)
	if #faults >= ML.JOB_RULES.steady_faults then
		Employment.Fire("@ml_steady_fired")
	else
		notice("@ml_steady_fault_" .. #faults)
	end
end

local function assign(site)
	ML.Log("job hired", site.key)
	ML.Store.Set("job_site", site.key)
	ML.Store.Set("job_start_day", today())
	ML.Store.Set("job_faults", {})
	ML.Store.Set("job_checked_day", today())
	Employment.bedGen = nil
end

function Employment.Hire()
	local site = ML.Try("job site", ML.Jobs.NearestSite)
	if not site or not site.steady then
		ML.Log("ERROR job: no steady employer nearby")
		return
	end
	assign(site)
end

-- The first shift waits for the employee to show up: only the dialog starts one.
function Employment.StartWith(key)
	for _, site in ipairs(ML.JOB_SITES) do
		if site.key == key then
			assign(site)
			ML.Life.SendToken(Employment.HIRED_TOKEN)
			notice("@ml_steady_origin")
		end
	end
end

local function previousWorkday()
	local day = today() - 1
	while not isWorkday(day) do
		day = day - 1
	end
	return day
end

-- The day of hiring does not count, and neither does a day with a fault for arriving drunk or naked.
local function lateness()
	local rules = ML.JOB_RULES
	if (Calendar.GetWorldHourOfDay() - rules.first_hour) * 60 <= rules.steady_late_minutes then
		return Employment.LATE_NONE
	elseif ML.Store.Get("job_start_day") == today() or ML.Store.Get("job_drunk_day") == today() then
		return Employment.LATE_NONE
	elseif ML.Store.Get("job_late_day") == previousWorkday() then
		return Employment.LATE_FAULT
	end
	return Employment.LATE_WARNING
end

local function shiftHours()
	local rules = ML.JOB_RULES
	return math.min(rules.last_hour - math.floor(Calendar.GetWorldHourOfDay()), rules.last_hour - rules.first_hour)
end

local function isDrunk()
	return (ML.Try("job drunk", function() return player.soul:GetDerivedStat("dru") end) or 0) >= Employment.DRUNK_LEVEL
end

local function isNaked()
	return ML.Female.IsNaked()
end

local function shiftState()
	local rules = ML.JOB_RULES
	if not isWorkday(today()) then
		return Employment.SHIFT_DAY_OFF
	elseif ML.Store.Get("job_worked_day") == today() then
		return Employment.SHIFT_DONE
	elseif Calendar.GetWorldHourOfDay() < rules.first_hour then
		return Employment.SHIFT_TOO_EARLY
	elseif shiftHours() < rules.steady_min_hours then
		return Employment.SHIFT_TOO_LATE
	elseif not ML.WorkBook.Has() then
		return Employment.SHIFT_NO_BOOK
	elseif isNaked() then
		return ML.Store.Get("job_drunk_day") == today() and Employment.SHIFT_STILL_NAKED or Employment.SHIFT_NAKED
	elseif isDrunk() then
		return ML.Store.Get("job_drunk_day") == today() and Employment.SHIFT_STILL_DRUNK or Employment.SHIFT_DRUNK
	end
	return Employment.SHIFT_READY
end

-- It is one fault, and the shift stays open: sober, dressed and in time, the day can still
-- be worked, without another fault for being late. Otherwise the absence is a second one.
function Employment.RefuseUnfit()
	ML.Store.Set("job_drunk_day", today())
	Employment.AddFault()
end

function Employment.StartShift()
	local hours, late = shiftHours(), lateness()
	ML.Store.Set("job_worked_day", today())
	ML.Store.Set("job_late_day", late == Employment.LATE_WARNING and today() or 0)
	if late == Employment.LATE_FAULT then
		Employment.AddFault()
	end
	-- That fault may have been the last one.
	local site = Employment.Site()
	if site then
		ML.Jobs.StartShift(site, hours)
	end
end

-- Only the dialog comes here: a job that starts any other way waits for the employee to show up.
function Employment.HireAndStart()
	Employment.Hire()
	Employment.StartShift()
end

-- A working day is over when no shift can start. It is checked on every day that went by.
local function checkAbsences()
	local rules, checked = ML.JOB_RULES, ML.Store.Get("job_checked_day")
	local closed = shiftHours() < rules.steady_min_hours and today() or today() - 1
	for day = checked + 1, closed do
		if Employment.Site() and isWorkday(day) and ML.Store.Get("job_worked_day") ~= day then
			Employment.AddFault(day)
		end
	end
	if closed > checked then
		ML.Store.Set("job_checked_day", closed)
	end
end

local function placeBed(site)
	if Employment.bedGen == ML.gen or not site.bed then
		return
	end
	Employment.bedGen = ML.gen
	ML.Try("job bed", ML.EmployeeBed.Place, { x = site.bed[1], y = site.bed[2], z = site.bed[3] }, site.bed[4])
end

local function isNear(site)
	local position, rules = player:GetWorldPos(), ML.JOB_RULES
	local x, y = ML.EmployeeBed.Center()
	local dx, dy = (x or site.bed[1]) - position.x, (y or site.bed[2]) - position.y
	return dx * dx + dy * dy <= rules.steady_area * rules.steady_area
end

-- Skald keeps the state, so it is told again after every load. The same state covers a rented bed while it is the
-- character's (rent.lua): nobody reacts to trespassing around it either.
local function updateArea(site)
	local nearJob = site and site.bed and Employment.region == "trosky" and isNear(site) or false
	local nearRent = ML.Try("rent bubble", ML.Rent.InBubble) or false
	local inside = nearJob or nearRent
	if inside ~= (Employment.inArea or false) or Employment.areaGen ~= ML.gen then
		Employment.inArea, Employment.areaGen = inside, ML.gen
		ML.Life.SendToken(inside and Employment.AREA_IN_TOKEN or Employment.AREA_OUT_TOKEN)
		ML.Log("no trespass area", inside, "job bed", nearJob, "rented bed", nearRent)
	end
end

local function closeQuest()
	local tries = ML.Store.Get("job_quest_tries")
	if tries > 0 and Employment.questGen ~= ML.gen and Employment.region == "trosky" then
		Employment.questGen = ML.gen
		ML.Store.Set("job_quest_tries", tries - 1)
		ML.Life.SendToken(Employment.FIRED_TOKEN)
	end
end

local function publish()
	local offer, state, hours, late = Employment.OFFER_NONE, Employment.SHIFT_NONE, 0, Employment.LATE_NONE
	local started, nearest, drunk, naked = ML.Life.IsStarted(), ML.Try("job site", ML.Jobs.NearestSite), isDrunk(), isNaked()
	if started and nearest and nearest.steady then
		local site = Employment.Site()
		if site == nearest then
			state, hours, late = shiftState(), shiftHours(), lateness()
		elseif site then
			offer = Employment.OFFER_HAS_JOB
		elseif today() < (ML.Store.Get("job_rehire", {})[nearest.key] or 0) then
			offer = Employment.OFFER_WAIT
		elseif ML.Orders.Owed(nearest) then
			offer = Employment.OFFER_OWED
		elseif not ML.Reputation.Accepts(nearest, ML.JOB_RULES.steady_min_reputation) then
			offer = Employment.OFFER_DISTRUST
		elseif not ML.WorkBook.Has() then
			offer = Employment.OFFER_NO_BOOK
		elseif naked then
			offer = Employment.OFFER_NAKED
		elseif drunk then
			offer = Employment.OFFER_DRUNK
		elseif Calendar.GetWorldHourOfDay() >= ML.JOB_RULES.steady_hire_last_hour then
			offer = Employment.OFFER_TOO_LATE
		else
			offer, hours = Employment.OFFER_OPEN, shiftHours()
		end
	end
	Variables.SetGlobal(Employment.OFFER_VARIABLE, offer)
	Variables.SetGlobal(Employment.STATE_VARIABLE, state)
	Variables.SetGlobal(Employment.HOURS_VARIABLE, hours)
	Variables.SetGlobal(Employment.LATE_VARIABLE, late)
	Variables.SetGlobal(Employment.START_NOW_VARIABLE, Calendar.GetWorldHourOfDay() >= ML.JOB_RULES.first_hour and 1 or 0)
	-- A casual job takes it the same way, and only the words change.
	Variables.SetGlobal(Employment.DRUNK_VARIABLE, (drunk or naked) and 1 or 0)
	Variables.SetGlobal(Employment.NAKED_VARIABLE, naked and 1 or 0)
	local distrust = started and nearest and not ML.Reputation.Accepts(nearest, ML.JOB_RULES.casual_min_reputation)
	Variables.SetGlobal(Employment.DISTRUST_VARIABLE, distrust and 1 or 0)
end

local function update()
	if Employment.regionGen ~= ML.gen then
		Employment.regionGen, Employment.region = ML.gen, ML.Region()
	end
	local site = ML.Life.IsStarted() and Employment.Site()
	if site and Employment.region == "kuttenberg" then
		Employment.Fire("@ml_steady_fired_region")
	elseif site then
		checkAbsences()
		placeBed(site)
	end
	updateArea(ML.Life.IsStarted() and Employment.Site())
	closeQuest()
	publish()
end

function Employment.Status()
	ML.Log("job site=", ML.Store.Get("job_site", ""), "faults=", #activeFaults(), "day=", today(), "workday=", isWorkday(today()), "hour=", Calendar.GetWorldHourOfDay(),
		"shift hours=", shiftHours(), "rehire=", ML.Store.Get("job_rehire", {}), "worked day=", ML.Store.Get("job_worked_day"), "drunk day=", ML.Store.Get("job_drunk_day"), "naked=", ML.Store.Get("naked"), "late day=", ML.Store.Get("job_late_day"), "in area=", Employment.inArea)
end

ML.TickHandlers[#ML.TickHandlers + 1] = update

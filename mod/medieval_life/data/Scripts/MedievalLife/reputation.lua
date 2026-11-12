-- =============================================================================
-- Reputation of the new character. It belongs to the factions, not to the soul, so a new
-- life would inherit that of Henry. Each faction of the people goes back to the value of a
-- new game: 50 in the ones checked. A faction takes the name of a row of reputation_change,
-- so a value is reached in rows, and no NPC is needed.
--
-- rpg_param__medieval_life.xml makes the game spread each change to other factions at once,
-- so GetReputation is the panel. But a change also moves the faction above, the ones near and
-- the ones below, so the reset goes over all of them a few times, fixing half of what is off
-- each time. It stops the game for moments, so it runs under the black screen.
-- =============================================================================
local ML = MedievalLife

ML.Reputation = {}
local Reputation = ML.Reputation

-- What the game gives the factions of the people.
Reputation.BASE = 0.5
-- ml_rep_up_300 is 0.3, ml_rep_up_050 is 0.05 and ml_rep_up_007 is 0.007.
Reputation.PLACES = { { thousandths = 100, format = "%d00" }, { thousandths = 10, format = "0%d0" }, { thousandths = 1, format = "00%d" } }
-- The panel shows 50 while a faction is within half a point.
Reputation.CLOSE = 0.004
Reputation.RELAX = 0.5
Reputation.SMALL = 0.002
Reputation.SWEEPS = 16
-- The game spreads the changes of a sweep before the next one.
Reputation.SWEEP_MS = 200
-- The factions of the map that is not loaded are at 0, so each map waits for the character.
Reputation.DONE_KEY = "reputation_reset"
Reputation.UNKNOWN_REGION = "unknown"
-- Shows once if a change reaches the faction above and the one below within the same call.
Reputation.PROBE = "trosecko_settlements_troskovice_commonFolk"
-- Each hour of work is 0.1 points with the setting work_reputation at 100%, up to 80.
Reputation.WORK_PER_HOUR = 0.001
Reputation.WORK_CAP = 0.8

local seenGen
local busy = false

-- Seconds of the processor, to see in the log how long the black screen lasts, if Lua has them.
local function clock()
	return os and os.clock and os.clock() or 0
end

-- What the player sees: the panel rounds to whole points.
local function points(value)
	return math.floor(value * 100 + 0.5)
end

-- A faction with a base of 0 is not one of the people.
local function people(id)
	local faction = RPG.GetFactionById(id)
	return faction and faction:GetBaseReputation() ~= 0 and faction or nil
end

-- Any change in three rows at most.
local function moveBy(faction, delta)
	local left = math.min(999, math.floor(math.abs(delta) * 1000 + 0.5))
	local prefix = delta > 0 and "ml_rep_up_" or "ml_rep_down_"
	for _, place in ipairs(Reputation.PLACES) do
		local digit = math.floor(left / place.thousandths)
		left = left - digit * place.thousandths
		if digit > 0 then
			faction:AddReputation(prefix .. string.format(place.format, digit))
		end
	end
end

local function valueOf(id)
	local faction = RPG.GetFactionById(id)
	return faction and faction:GetReputation()
end

-- The faction above and the first one below, before and after a change.
local function probe(id, faction, delta)
	local child
	for _, other in ipairs(ML.FACTIONS) do
		if ML.FACTION_PARENTS[other] == id then
			child = other
			break
		end
	end
	local parent = ML.FACTION_PARENTS[id]
	local parentBefore, childBefore = valueOf(parent), child and valueOf(child)
	moveBy(faction, delta)
	ML.Log("reputation probe moved", delta, "above", parentBefore, "->", valueOf(parent), "below", childBefore, "->", child and valueOf(child))
end

-- Half of what each faction is off, or all of it when it is little. Returns the largest
-- distance it found and how many it moved.
local function sweep(order, first)
	local worst, moved = 0, 0
	for i = 1, #order do
		local id = order[i]
		ML.Try("reputation sweep", function()
			local faction = people(id)
			if not faction then
				return
			end
			local off = faction:GetBaseReputation() - faction:GetReputation()
			worst = math.max(worst, math.abs(off))
			if math.abs(off) <= Reputation.CLOSE then
				return
			end
			local delta = math.abs(off) * Reputation.RELAX < Reputation.SMALL and off or off * Reputation.RELAX
			if first and id == Reputation.PROBE then
				probe(id, faction, delta)
			else
				moveBy(faction, delta)
			end
			moved = moved + 1
		end)
	end
	return worst, moved
end

-- Parents first on one sweep, children first on the next. The screen stays black until it
-- ends; when the screen was already black, it is left for whoever showed it.
function Reputation.Reset(region, onDone)
	if busy then
		if onDone then
			onDone()
		end
		return
	end
	busy = true
	local gen, ownScreen = ML.gen, not ML.Screen.active
	if ownScreen then
		ML.Screen.Show("")
	end
	local down, up = ML.FACTIONS, {}
	for i = #down, 1, -1 do
		up[#up + 1] = down[i]
	end
	local count, started = 0, clock()
	local function finish(worst)
		ML.Log("reputation reset sweeps", count, "worst", worst, "seconds", clock() - started)
		if region then
			local done = ML.Store.Get(Reputation.DONE_KEY, {})
			done[region] = true
			ML.Store.Set(Reputation.DONE_KEY, done)
		end
		busy = false
		if ownScreen then
			ML.Screen.Hide()
		end
		if onDone then
			onDone()
		end
	end
	local function nextSweep()
		if gen ~= ML.gen then
			busy = false
			if ownScreen then
				ML.Screen.Hide()
			end
			return
		end
		count = count + 1
		local worst, moved = sweep(count % 2 == 1 and down or up, count == 1)
		ML.Log("reputation sweep", count, "worst", worst, "moved", moved)
		if moved == 0 or count >= Reputation.SWEEPS then
			finish(worst)
		else
			Script.SetTimer(Reputation.SWEEP_MS, nextSweep)
		end
	end
	ML.Log("reputation reset starts", region)
	nextSweep()
end

-- Once per map in each life, the first time the character is there. onDone runs either way.
function Reputation.Update(onDone)
	if seenGen == ML.gen or not ML.Life.IsStarted() then
		if onDone then
			onDone()
		end
		return
	end
	seenGen = ML.gen
	local region, done = ML.Region(), ML.Store.Get(Reputation.DONE_KEY, {})
	if region ~= Reputation.UNKNOWN_REGION and not done[region] then
		Reputation.Reset(region, onDone)
	elseif onDone then
		onDone()
	end
end

ML.TickHandlers[#ML.TickHandlers + 1] = function() Reputation.Update() end

-- The row of the panel that shows whoever gives the work: what the player sees is what counts.
local function siteFaction(site)
	for _, name in ipairs(site.npcs) do
		local entity = System.GetEntityByName(name)
		if entity then
			local id = entity.soul:GetFactionID()
			return RPG.GetFactionById(ML.FACTION_ROWS[id] or id)
		end
	end
end

-- Points of the panel, up or down, on the row of whoever gives the work.
function Reputation.AddPoints(site, points)
	local faction = site and ML.Try("reputation points", siteFaction, site)
	if faction then
		ML.Try("reputation points", moveBy, faction, points / 100)
	end
end

function Reputation.Work(site, hours)
	local faction = ML.Try("reputation work", siteFaction, site)
	if not faction then
		return
	end
	ML.Try("reputation work", function()
		local gain = hours * Reputation.WORK_PER_HOUR * ML.Settings.Factor("work_reputation")
		gain = math.min(gain, Reputation.WORK_CAP - faction:GetReputation())
		-- The rows go in thousandths, a tenth of a point: less than half of one is nothing.
		if gain >= 0.0005 then
			moveBy(faction, gain)
		end
	end)
end

-- The points of the panel with whoever gives the work, for the log.
function Reputation.Points(site)
	local faction = ML.Try("reputation points", siteFaction, site)
	local value = faction and ML.Try("reputation points", function() return faction:GetReputation() end)
	return value and points(value)
end

-- A minimum in the points of the panel, from jobs.toml.
function Reputation.Accepts(site, minimum)
	local faction = ML.Try("reputation hire", siteFaction, site)
	local value = faction and ML.Try("reputation hire", function() return faction:GetReputation() end)
	return not value or points(value) >= minimum
end

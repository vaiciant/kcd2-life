-- =============================================================================
-- Fast travel: the map only shows the points this character has been to.
-- The game cannot change a single point: it sets a whole type at once, that state
-- comes back on loading, and it hides the shops of the town too. So the game keeps
-- them all, the mod remembers the visits, and each time the map opens it takes off
-- the markers of the points still unknown. Without the mod, nothing has changed.
-- =============================================================================
local ML = MedievalLife

ML.FastTravel = {}
local FastTravel = ML.FastTravel

-- Each point is one bit in a stored number, in the order of ML.FAST_TRAVEL_POINTS.
FastTravel.TOKENS = 3
FastTravel.BITS_PER_TOKEN = 14
-- The map fills in after it opens, so the filter runs again a little later.
FastTravel.FILTER_DELAYS_MS = { 100, 500, 1500 }
FastTravel.NOTICE = "@ml_fast_travel_known"

local function knownAmounts()
	local amounts = {}
	for token = 1, FastTravel.TOKENS do
		amounts[token] = ML.Store.Get("known_" .. token)
	end
	return amounts
end

local function slot(index)
	local position = index - 1
	return math.floor(position / FastTravel.BITS_PER_TOKEN) + 1, 2 ^ (position % FastTravel.BITS_PER_TOKEN)
end

local function isKnown(amounts, index)
	local token, bit = slot(index)
	return math.floor(amounts[token] / bit) % 2 == 1
end

function FastTravel.KnownCount()
	local amounts, count = knownAmounts(), 0
	for index in ipairs(ML.FAST_TRAVEL_POINTS) do
		if isKnown(amounts, index) then
			count = count + 1
		end
	end
	return count
end

function FastTravel.Update()
	if not ML.Life.IsStarted() then
		return
	end
	-- Both regions share coordinates, so only the points of this one count.
	if FastTravel.regionGen ~= ML.gen then
		FastTravel.regionGen, FastTravel.region = ML.gen, ML.Region()
	end
	local amounts = knownAmounts()
	local position = player:GetWorldPos()
	for index, point in ipairs(ML.FAST_TRAVEL_POINTS) do
		if point.region == FastTravel.region and not isKnown(amounts, index) then
			local dx, dy = point.x - position.x, point.y - position.y
			if dx * dx + dy * dy <= point.range * point.range then
				local token, bit = slot(index)
				amounts[token] = amounts[token] + bit
				ML.Store.Set("known_" .. token, amounts[token])
				ML.Log("fast travel known", point.name)
				Game.SendInfoText(FastTravel.NOTICE, false)
			end
		end
	end
end

-- RemovePoiMarkers takes the ids in the array. An id with no marker does nothing. It also takes
-- the marks the character has not found (map_marks.lua).
function FastTravel.Filter()
	if not ML.Life.IsStarted() then
		return
	end
	local amounts, hidden = knownAmounts(), {}
	for index, point in ipairs(ML.FAST_TRAVEL_POINTS) do
		if not isKnown(amounts, index) then
			hidden[#hidden + 1] = point.id
		end
	end
	ML.MapMarks.AppendHidden(hidden)
	-- The marks of the game for beds and homes, also those Henry rented: the new character owns none of the game's, and
	-- the mod marks the bed of the job and the rented one.
	for _, bed in ipairs(ML.MAP_BEDS[ML.Region()] or {}) do
		hidden[#hidden + 1] = bed[1]
	end
	if #hidden > 0 then
		UIAction.SetArray("ApseMap", -1, "PoiMarkers", hidden)
		UIAction.CallFunction("ApseMap", -1, "RemovePoiMarkers")
	end
	ML.BedMarker.ShowOnMap()
end

function ML:OnMapShown()
	ML.Log("map shown, known points", FastTravel.KnownCount())
	ML.Try("map filter", FastTravel.Filter)
	for _, delay in ipairs(FastTravel.FILTER_DELAYS_MS) do
		Script.SetTimer(delay, function() ML.Try("map filter", FastTravel.Filter) end)
	end
end

function ML:OnMapUpdating()
	ML.Try("map filter", FastTravel.Filter)
end

-- Called on every load, so it drops the listeners first or they would fire twice.
function FastTravel.Listen()
	ML.Try("map listeners", function()
		UIAction.UnregisterElementListener(ML, "OnMapShown")
		UIAction.UnregisterElementListener(ML, "OnMapUpdating")
		UIAction.RegisterElementListener(ML, "ApseMap", -1, "OnShow", "OnMapShown")
		UIAction.RegisterElementListener(ML, "ApseMap", -1, "OnUpdatingChanged", "OnMapUpdating")
	end)
end

ML.TickHandlers[#ML.TickHandlers + 1] = FastTravel.Update

-- =============================================================================
-- The bed of the employee and the bed rented for the night, on the map and the compass. There is no system for this:
-- the marks go straight into the movies. The map paints itself after it opens, so the mark goes in with the filter of
-- fast_travel.lua, which comes several times. The compass has to be drawn a few times per second. Both only show on the
-- map of their region: the two regions share coordinates.
-- The marks of the game for the beds of the player go, also on the compass: for the new character, they are Henry's,
-- and the rented bed has the mark of the mod, in colour. The map takes them off by their id
-- (fast_travel.lua), and the compass by their discovery, with Skald.
-- =============================================================================
local ML = MedievalLife

ML.BedMarker = {}
local BedMarker = ML.BedMarker

BedMarker.KEY = "ML_EMPLOYEE_BED"
BedMarker.MAP_TEXT = "ml_bed_marker"
BedMarker.RENT_TEXT = "ml_rent_marker"
-- The icons of the map of the game, Libs/UI/Textures/Icons/Map/<name>_icon.dds: the bed of straw and the wooden bed of
-- the player. In the state known (1) they show as not discovered, white: the bed of the job. Discovered (2) shows them
-- in colour: the rented bed.
BedMarker.ICON = "bed"
BedMarker.RENT_ICON = "bedplayer"
BedMarker.STATE_KNOWN = 1
BedMarker.STATE_DISCOVERED = 2
BedMarker.COMPASS_MS = 250
-- Like the places of the game, it only shows on the compass when it is near.
BedMarker.MAX_DISTANCE = 50
BedMarker.NEAR_DISTANCE = 3
BedMarker.LAYER_DISTANCE = 25
BedMarker.FAR_DISTANCE = 75
-- Measured on the compass.
BedMarker.BEARING_OFFSET = 90

-- Where the mark goes, its text on the map, its icon and its state. The bed rented tonight goes first: one mark at a
-- time.
local function bed()
	local rented = ML.Rent.Place()
	if rented then
		return rented, BedMarker.RENT_TEXT, BedMarker.RENT_ICON, BedMarker.STATE_DISCOVERED
	end
	local site = ML.Life.IsStarted() and ML.Employment.Site()
	if site and site.bed and ML.Employment.region == "trosky" then
		local x, y = ML.EmployeeBed.Center()
		return x and { x, y } or site.bed, BedMarker.MAP_TEXT, BedMarker.ICON, BedMarker.STATE_KNOWN
	end
end

local function hide()
	if BedMarker.shown then
		BedMarker.shown = false
		UIAction.CallFunction("hud", -1, "RemoveCompassMarker", BedMarker.KEY)
	end
end

local function drawCompass()
	local target, _, icon, state = bed()
	if not target then
		hide()
		return
	end
	local position = player:GetWorldPos()
	local dx, dy = target[1] - position.x, target[2] - position.y
	local distance = math.sqrt(dx * dx + dy * dy)
	if distance > BedMarker.MAX_DISTANCE then
		hide()
		return
	end
	local bearing = (math.deg(math.atan2(-dx, -dy)) + BedMarker.BEARING_OFFSET) % 360
	-- From the bed of the job to the rented one, or back: the mark goes again with its icon.
	if BedMarker.shown and BedMarker.icon ~= icon then
		hide()
	end
	if not BedMarker.shown then
		BedMarker.icon = icon
		BedMarker.shown = true
		ML.Log("bed compass", icon, distance, bearing)
		UIAction.CallFunction("hud", -1, "AddCompassMarker", BedMarker.KEY, icon, state, -1, -1, distance, bearing, false, false,
			BedMarker.NEAR_DISTANCE, BedMarker.LAYER_DISTANCE, BedMarker.FAR_DISTANCE)
	end
	UIAction.SetArray("hud", -1, "CompassMarkers", { 1, BedMarker.KEY, -1, distance, bearing, 0, false, false })
	UIAction.CallFunction("hud", -1, "UpdateCompass", 0)
end

-- The compass of the game shows the beds and homes of the player nearby: for the new character, those are Henry's, his
-- own and the rented ones. The compass names its marks by numbers of its own, so the mod cannot take them off it, as it
-- does on the map. Their discovery decides whether they show: Skald makes them unknown with a token in the
-- inventory of the new character (ml_map_beds.xml), on every load and when the life begins. Walking up to one may
-- discover it again until the next load. When Henry plays again, another token discovers them for him.
function BedMarker.HideGameBeds()
	ML.Life.SendToken(ML.MAP_BEDS_TOKENS.hide)
	ML.Log("game beds off the compass")
end

function BedMarker.ShowGameBeds()
	ML.Life.SendToken(ML.MAP_BEDS_TOKENS.show)
	ML.Log("game beds back on the compass for Henry")
end

-- One chain per generation, like the tick: the one from an earlier load stops on its own.
function BedMarker.Start()
	local gen = ML.gen
	BedMarker.shown = false
	local bedsHidden = false
	local function step()
		if gen == ML.gen then
			ML.Try("bed compass", drawCompass)
			if not bedsHidden and ML.Life.IsStarted() then
				bedsHidden = true
				ML.Try("game beds compass", BedMarker.HideGameBeds)
			end
			Script.SetTimer(BedMarker.COMPASS_MS, step)
		end
	end
	Script.SetTimer(BedMarker.COMPASS_MS, step)
end

-- The first value of the array is how many marks follow. Removing first keeps it to one.
function BedMarker.ShowOnMap()
	-- The map keeps a mark until it is taken off: once the rental or the job ends, it must go.
	local target, text, icon, state = bed()
	UIAction.SetArray("ApseMap", -1, "PoiMarkers", { BedMarker.KEY })
	UIAction.CallFunction("ApseMap", -1, "RemovePoiMarkers")
	if target then
		UIAction.SetArray("ApseMap", -1, "PoiMarkers", { 1, BedMarker.KEY, text, icon, state, false, 0, target[1], target[2] })
		UIAction.CallFunction("ApseMap", -1, "AddPoiMarkers")
		ML.Log("bed map", icon, target[1], target[2])
	end
end

-- Test shortcut, from ml_rent: what the compass holds now.
function BedMarker.Dump()
	local markers = ML.Try("compass array", function() return UIAction.GetArray("hud", -1, "CompassMarkers") end)
	local parts = {}
	for _, value in ipairs(type(markers) == "table" and markers or {}) do
		parts[#parts + 1] = tostring(value)
	end
	ML.Log("compass markers:", type(markers), table.concat(parts, " "))
	ML.Log("compass global:", tostring(ML.Try("compass global", function() return UIAction.GetVariable("hud", -1, "g_CompassMarkersA") end)))
end

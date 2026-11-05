-- =============================================================================
-- Map marks: the points of interest, camps and hunting spots of the new character.
-- Their types are hidden when the life starts, but they come back on every load, so
-- the mod remembers the visits and the map takes off the rest. There are too many for
-- tokens, so each region keeps them in a saved entity, out of any inventory. Nests do
-- not come back, so they are left to the game.
-- =============================================================================
local ML = MedievalLife

ML.MapMarks = {}
local MapMarks = ML.MapMarks

MapMarks.STORE_NAME = "ml_map_marks"
MapMarks.STORE_POSITION = { x = 0, y = 0, z = -100 }

local function store()
	return System.GetEntityByName(MapMarks.STORE_NAME) or System.SpawnEntity({
		class = "BasicEntity",
		name = MapMarks.STORE_NAME,
		position = MapMarks.STORE_POSITION,
		properties = { bSaved_by_game = 1, bSerialize = 1, Physics = { bPhysicalize = false, bRigidBody = false } },
	})
end

-- Loads what this save remembers of this region: one character per mark, in the order of the list.
local function loadRegion()
	if MapMarks.gen == ML.gen then
		return
	end
	MapMarks.gen = ML.gen
	MapMarks.marks = {}
	local region = ML.Region()
	for _, mark in ipairs(ML.MAP_MARKS) do
		if mark.region == region then
			MapMarks.marks[#MapMarks.marks + 1] = mark
		end
	end
	local health = store().health
	local known = type(health) == "table" and health.known or ""
	for index, mark in ipairs(MapMarks.marks) do
		mark.known = string.sub(known, index, index) == "1"
	end
end

local function save()
	local flags = {}
	for index, mark in ipairs(MapMarks.marks) do
		flags[index] = mark.known and "1" or "0"
	end
	store().health = { known = table.concat(flags) }
end

function MapMarks.KnownCount()
	loadRegion()
	local count = 0
	for _, mark in ipairs(MapMarks.marks) do
		if mark.known then
			count = count + 1
		end
	end
	return count
end

function MapMarks.Update()
	if not ML.Life.IsStarted() then
		return
	end
	loadRegion()
	local position = player:GetWorldPos()
	local changed = false
	for _, mark in ipairs(MapMarks.marks) do
		if not mark.known then
			local dx, dy = mark.x - position.x, mark.y - position.y
			if dx * dx + dy * dy <= mark.range * mark.range then
				mark.known = true
				changed = true
			end
		end
	end
	if changed then
		save()
	end
end

function MapMarks.AppendHidden(hidden)
	loadRegion()
	for _, mark in ipairs(MapMarks.marks) do
		if not mark.known then
			hidden[#hidden + 1] = mark.id
		end
	end
end

ML.TickHandlers[#ML.TickHandlers + 1] = MapMarks.Update

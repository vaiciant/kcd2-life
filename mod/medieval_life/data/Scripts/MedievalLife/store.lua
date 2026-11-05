-- =============================================================================
-- Persistence: a table of values, out of any inventory, so that nothing shows in it. A
-- saved entity holds it, but each region has its own entity and memory is the only
-- thing that crosses: it is right after a crossing and stale after a load. The amount of
-- the real keyring says which one to trust. It is in the inventory, so it crosses and it
-- is saved, it goes up with each write, and the entity keeps the amount of its last
-- write. If they match, the entity is current. Each character has their own keyring.
-- =============================================================================
local ML = MedievalLife

ML.Store = {}
local Store = ML.Store

Store.ENTITY_NAME = "ml_store"
Store.ENTITY_POSITION = { x = 0, y = 0, z = -100 }
Store.COUNTER_ITEM = "b54eaa25-f0e9-425b-8b29-1fb14a71de56"

local function entity()
	return System.GetEntityByName(Store.ENTITY_NAME) or System.SpawnEntity({
		class = "BasicEntity",
		name = Store.ENTITY_NAME,
		position = Store.ENTITY_POSITION,
		properties = { bSaved_by_game = 1, bSerialize = 1, Physics = { bPhysicalize = false, bRigidBody = false } },
	})
end

local function counter()
	return ML.Try("store counter", function() return player.inventory:GetCountOfClass(Store.COUNTER_ITEM) end) or 0
end

local function keep(version)
	Store.version = version
	entity().health = { version = version, values = Store.values }
end

local function sync()
	if Store.gen == ML.gen then
		return
	end
	Store.gen = ML.gen
	local version = counter()
	local saved = entity().health
	local hasSaved = type(saved) == "table" and type(saved.values) == "table"
	if hasSaved and saved.version == version then
		Store.values = saved.values
	elseif Store.version ~= version then
		-- A character with nothing written, or a save from just after a crossing.
		if hasSaved then
			ML.Log("store: older values", saved.version, "counter=", version)
		end
		Store.values = hasSaved and saved.values or {}
	end
	keep(version)
end

function Store.Get(key, default)
	sync()
	local value = Store.values[key]
	if value == nil then
		return default or 0
	end
	return value
end

function Store.Set(key, value)
	sync()
	if type(value) ~= "table" and Store.values[key] == value then
		return
	end
	Store.values[key] = value
	ML.Try("store counter", function() player.inventory:CreateItem(Store.COUNTER_ITEM, 1, 1) end)
	keep(counter())
end

-- =============================================================================
-- Host of the new life: an NPC at the wall, left of the Troskowitz tavern entrance.
-- He only stands there by day, for Henry, in Trosky. He never goes in the save, so
-- removing the mod leaves nothing behind.
-- =============================================================================
local ML = MedievalLife

ML.Host = {}
local Host = ML.Host

Host.SOUL = "37657ce6-03ca-5eac-9a17-5af46d318f1a"
Host.NAME = "ml_host"
Host.POSITION = { x = 2339.49, y = 2058.86, z = 109.90 }
-- The yaw he spawns with. The pose turns him while it starts, by an amount that changes with how he appeared.
Host.YAW = 2.75
-- So he is set straight once he leans. This is the yaw of someone standing with their back to the wall.
Host.LEAN_YAW = 3.0453
Host.FIRST_HOUR = 8
Host.LAST_HOUR = 20

local regionGen
local inTrosky

-- The region only changes with a load.
local function isInTrosky()
	if regionGen ~= ML.gen then
		regionGen = ML.gen
		inTrosky = ML.Region() == "trosky"
	end
	return inTrosky
end

local function spawn()
	ML.Try("host spawn", function()
		System.SpawnEntity({ class = "NPC", name = Host.NAME, position = Host.POSITION,
			properties = { guidSharedSoulId = Host.SOUL, bSaved_by_game = false, bSerialize = false } })
		local entity = System.GetEntityByName(Host.NAME)
		entity:SetFlags(ENTITY_FLAG_NO_SAVE, 0)
		entity:SetAngles({ 0, 0, Host.YAW })
		ML.Log("host spawned no save=", entity:HasFlags(ENTITY_FLAG_NO_SAVE))
	end)
end

local function remove(entity)
	ML.Try("host remove", function() System.RemoveEntity(entity.id) end)
	ML.Log("host removed")
end

function Host.FaceOut(entity)
	ML.Try("host face", function()
		ML.Log("host leaning yaw was", entity:GetAngles().z)
		entity:SetAngles({ 0, 0, Host.LEAN_YAW })
	end)
end

function Host.Update()
	local hour = Calendar.GetWorldHourOfDay()
	local wanted = hour >= Host.FIRST_HOUR and hour < Host.LAST_HOUR and ML.Store.Get("state") == 0 and isInTrosky() and ML.Life.FrameworksReady()
	local entity = System.GetEntityByName(Host.NAME)
	if wanted and not entity then
		spawn()
	elseif entity and not wanted then
		remove(entity)
	end
end

ML.TickHandlers[#ML.TickHandlers + 1] = Host.Update

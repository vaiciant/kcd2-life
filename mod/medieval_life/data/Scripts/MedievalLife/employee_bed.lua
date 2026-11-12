-- =============================================================================
-- The bed of an employee. It is made of two vanilla classes, because an entity of a class
-- of the mod would break the saves once the mod is removed. The BasicEntity has the model
-- and the properties of a bed, and the BedTrigger gives the prompt and the lying stance.
-- Neither is saved.
-- =============================================================================
local ML = MedievalLife

ML.EmployeeBed = {}
local EmployeeBed = ML.EmployeeBed

EmployeeBed.MODEL = "objects/manmade/common_furniture/beds/low/bed_shabby_a.cgf"
EmployeeBed.NAME = "ml_employee_bed"
EmployeeBed.TRIGGER_NAME = "ml_employee_bed_trigger"
EmployeeBed.TRIGGER_HEIGHT = 0.4
EmployeeBed.TRIGGER_SCALE = { 0.7, 0.7, 0.7 }

function EmployeeBed.Remove()
	for _, name in ipairs({ EmployeeBed.TRIGGER_NAME, EmployeeBed.NAME }) do
		local entity = System.GetEntityByName(name)
		if entity then
			System.RemoveEntity(entity.id)
		end
	end
end

-- The middle of the model: the position of the entity is at one end of it.
function EmployeeBed.Center()
	local entity = System.GetEntityByName(EmployeeBed.NAME)
	if entity then
		local low, high = entity:GetWorldBBox()
		return (low.x + high.x) / 2, (low.y + high.y) / 2
	end
end

function EmployeeBed.Place(position, yaw)
	EmployeeBed.Remove()
	local bed = System.SpawnEntity({
		class = "BasicEntity",
		name = EmployeeBed.NAME,
		position = position,
		properties = {
			object_Model = EmployeeBed.MODEL,
			bSaved_by_game = false,
			bSerialize = false,
			guidSmartObjectType = "425d4fdf-8dcd-4a2b-fdc5-cbb1b5d25b89",
			soclass_SmartObjectHelpers = "Bed_1Place_Low",
			sWH_AI_EntityCategory = "Bed",
			sSittingTagGlobal = "sittingNoTable",
			fUsabilityDistance = 1.25,
			bInteractiveCollisionClass = true,
			Script = { esBedTypes = "GroundBed" },
			-- A good bed, 0.8 in rpg/sleeping_spot_type: with "low", 0.4, 12 hours gave back 22 of tiredness and a shift
			-- of 10 hours took 42.
			Bed = { esSleepQuality = "high", esReadingQuality = "bed_ground" },
		},
	})
	bed:SetAngles({ 0, 0, yaw })
	local trigger = System.SpawnEntity({
		class = "BedTrigger",
		name = EmployeeBed.TRIGGER_NAME,
		position = { x = position.x, y = position.y, z = position.z + EmployeeBed.TRIGGER_HEIGHT },
		scale = EmployeeBed.TRIGGER_SCALE,
		properties = {
			InteractorPriorityOverride = 1,
			bSaved_by_game = false,
			bSerialize = false,
			Click = {
				bIsActive = true,
				UseMessage = "@ui_hud_sleep_and_save",
				bAllowNoOwner = 0,
				bCheckOwner = 0,
				esActionType = "Stance",
				sAction = "lying",
			},
		},
	})
	trigger:CreateLink("", bed.id)
	bed:CreateLink("mTrigger", trigger.id)
	ML.Log(string.format("employee bed at x=%.2f y=%.2f z=%.2f yaw=%.4f", position.x, position.y, position.z, yaw))
end

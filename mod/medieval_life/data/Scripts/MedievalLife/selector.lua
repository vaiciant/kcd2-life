-- =============================================================================
-- Selector: the new life is chosen from the normal view of the player, looking at a
-- model on the Troskowitz pillory. A mod cannot aim a dialog camera, and spawned NPCs
-- cannot join a dialog. So the offer closes, the player moves to the stage under the
-- black screen, and Skald opens a forced monolog (ml_selector.xml).
-- =============================================================================
local ML = MedievalLife

ML.Selector = {}
local Selector = ML.Selector

Selector.TOKEN = "6523ce70-91d2-5586-bfb3-a771fd6e0159"
Selector.LOOK_VARIABLE = "ml_selector_look"
-- The dialog offers the next face of each people, so the player chooses instead of drawing at random. The variable
-- of each people says how many other faces "Next" can show, and hides the option when there are none.
Selector.ETHNICITIES = { "czech", "hungarian", "romani" }
Selector.NEXT_VARIABLE = "ml_selector_next_"
Selector.STAGE = { x = 2338.40, y = 2044.50, z = 109.17 }
Selector.HIDDEN = { x = 2338.40, y = 2044.50, z = 89.17 }
Selector.EYE = { x = 2336.12, y = 2044.23, z = 108.03 }
Selector.VIEW = { x = 0.98, y = 0.09 }
Selector.PITCH = 0.18
Selector.FADE_MS = 2000
Selector.TICK_MS = 100
Selector.DIALOG_WAIT_MS = 5000
Selector.STORY_TEXT = "@ml_stage_story"

local models = {}
local current
-- The last face shown of each people and gender, so Next goes on from it and never brings it back at once.
local lastOf = {}
local chosenName
local chosenOrigin
local returnPoint
local dialogOpen
local dialogWait

local function clearModels()
	for _, model in pairs(models) do
		ML.Try("model remove", function() System.RemoveEntity(model.id) end)
	end
	models = {}
end

-- With every face of the game, only the one on stage is spawned.
local function spawnModel(look)
	local name = "ml_model_" .. look.id
	ML.Try("model spawn", function()
		System.SpawnEntity({ class = look.class, name = name, position = Selector.HIDDEN,
			properties = { guidSharedSoulId = look.soul } })
		local entity = System.GetEntityByName(name)
		entity:Hide(1)
		models[look.id] = entity
	end)
end

-- An entity faces +Y: this turn leaves the model facing the view.
local function placeModel(model)
	model:SetWorldPos(Selector.STAGE)
	model:SetAngles({ 0, 0, math.atan2(Selector.VIEW.x, -Selector.VIEW.y) })
end

-- SetAngles turns the body. Only PlayerSetViewAngles tilts the view.
local function aim()
	local yaw = math.atan2(-Selector.VIEW.x, Selector.VIEW.y)
	ML.Try("selector aim", function()
		player:SetAngles({ 0, 0, yaw })
		player.actor:PlayerSetViewAngles({ x = Selector.PITCH, y = 0, z = yaw })
	end)
end

-- The player stays still and the model stays in place. The lock also blocks the pause menu, so if the
-- monolog closes some other way, or never opens, the selector cancels itself.
local function tick()
	if not Selector.active then
		return
	end
	ML.Screen.LockInput(true)
	local model = models[current or 0]
	if model then
		ML.Try("model pin", function() placeModel(model) end)
	end
	if ML.Try("selector dialog", function() return player.human:IsInDialog() end) then
		if not dialogOpen then
			dialogOpen = true
			aim()
		end
		dialogWait = Selector.DIALOG_WAIT_MS
	else
		dialogWait = dialogWait - Selector.TICK_MS
		if dialogWait <= 0 then
			ML.Log("selector dialog gone")
			Selector.Leave()
			return
		end
	end
	Script.SetTimer(Selector.TICK_MS, tick)
end

-- Only faces of common people, never a named character's, and only young ones for now. A choice of age would let the old
-- ones in.
local function eligible(look)
	return look.villager and look.age == "young"
	-- return look.villager and (look.age == "young" or Selector.withOld)
end

-- The ids of the faces on offer, in menu order.
local function faces(gender, ethnicity)
	local list = {}
	for _, look in ipairs(ML.Female.ListLooks(gender)) do
		if eligible(look) and (ethnicity == nil or look.ethnicity == ethnicity) then
			list[#list + 1] = look.id
		end
	end
	return list
end

local function publishNext()
	local look = ML.Female.GetLook(current)
	for _, ethnicity in ipairs(Selector.ETHNICITIES) do
		local count = look and #faces(look.gender, ethnicity) or 0
		if look and look.ethnicity == ethnicity then
			count = count - 1
		end
		Variables.SetGlobal(Selector.NEXT_VARIABLE .. ethnicity, count)
	end
end

local function close()
	Selector.active = false
	ML.Screen.LockInput(false)
	clearModels()
	ML.Try("selector token", function() player.inventory:DeleteItemOfClass(Selector.TOKEN, 1) end)
end

-- The player leaves the offer and arrives at the stage. The token makes Skald open the monolog.
function Selector.Enter()
	ML.Log("selector enter")
	ML.Try("selector return point", function()
		local position = player:GetWorldPos()
		returnPoint = { position = { x = position.x, y = position.y, z = position.z }, yaw = player:GetAngles().z }
	end)
	ML.Screen.Show(Selector.STORY_TEXT)
	clearModels()
	current = nil
	lastOf = {}
	chosenName = nil
	chosenOrigin = ML.Origins.DEFAULT
	Script.SetTimer(Selector.FADE_MS, function()
		ML.Try("selector move", function() player:SetWorldPos(Selector.EYE) end)
		aim()
		ML.Screen.Hide()
		Selector.active = true
		dialogOpen = false
		dialogWait = Selector.DIALOG_WAIT_MS
		tick()
		ML.Try("selector token", function() player.inventory:CreateItem(Selector.TOKEN, 1, 1) end)
	end)
end

-- 0 hides them all.
function Selector.Show(index)
	current = index
	Variables.SetGlobal(Selector.LOOK_VARIABLE, index)
	local look = ML.Female.GetLook(index)
	if look and look.ethnicity then
		lastOf[look.gender .. look.ethnicity] = index
	end
	publishNext()
	-- Only the face on stage exists: the others go away, and come back when shown.
	for i, model in pairs(models) do
		if i ~= index then
			ML.Try("model remove", function() System.RemoveEntity(model.id) end)
			models[i] = nil
		end
	end
	if look and not models[index] then
		spawnModel(look)
	end
	local model = models[index]
	if model then
		ML.Try("model move", function()
			placeModel(model)
			model:Hide(0)
			ML.Origins.Dress(model, chosenOrigin, look.gender == ML.Female.WOMAN)
		end)
	end
end

function Selector.First(gender)
	Selector.Show(faces(gender)[1] or 0)
end

-- The face after the last one shown of that people, so going to another people and back goes on instead of starting over.
-- The people is its place in ETHNICITIES: the dialog passes only numbers.
function Selector.Next(gender, index)
	local ethnicity = Selector.ETHNICITIES[index]
	local list = faces(gender, ethnicity)
	if #list == 0 or not ethnicity then
		return
	end
	local at = 0
	for i, id in ipairs(list) do
		if id == lastOf[gender .. ethnicity] then
			at = i
		end
	end
	Selector.Show(list[at % #list + 1])
end

-- The names of the name screen depend on the people of the model.
function Selector.Ethnicity()
	local model = ML.Female.GetLook(current)
	return model and model.ethnicity or "czech"
end

-- The model wears what the origin gives.
function Selector.SetOrigin(index)
	chosenOrigin = index
	Selector.Show(current)
end

function Selector.SetName(letters)
	chosenName = letters
end

function Selector.Confirm()
	ML.Log("selector confirm look=", current, "origin=", chosenOrigin, "name=", chosenName)
	local look = current
	ML.Store.Set("ethnicity", Selector.Ethnicity())
	close()
	ML.Life.Begin(look, chosenName, chosenOrigin)
end

-- Cancels everything: the player goes back under the black screen to where they came from.
function Selector.Leave()
	ML.Log("selector leave")
	close()
	ML.Screen.Show("")
	Script.SetTimer(Selector.FADE_MS, function()
		ML.Try("selector return", function()
			player:SetWorldPos(returnPoint.position)
			player:SetAngles({ 0, 0, returnPoint.yaw })
			player.actor:PlayerSetViewAngles({ x = 0, y = 0, z = returnPoint.yaw })
		end)
		ML.Screen.Hide()
	end)
end

-- =============================================================================
-- Test shortcuts of playable women, to remove before publishing.
-- Women's clothes on the new character, men's clothes to try on, and the items of the game.
-- =============================================================================
local ML = MedievalLife

ML.WomanTest = {}
local WomanTest = ML.WomanTest

-- ml_ff_SimpleDress05_m05_C, ml_ff_Shoes02_m01_B and ml_ff_Bonnet01_m01_B.
WomanTest.CLOTHES = {
	"4ea03281-7209-58b2-8e2e-c2b4601c54c5",
	"ab871c1c-98cc-5e45-ab07-f517c3e5e843",
	"5696a428-d062-5d94-a4dd-a00f7c4600a7",
}
-- One piece of each type of men's clothing and armor of the game, some more for helmets: ml_w_gear.
WomanTest.GEAR = {
	-- Caps, hoods and collars.
	"16977d23-7510-48e6-82e6-a9fda39e52ff", -- Cap16_m05_E
	"e101baf7-21c3-4f60-99bc-2de89bbb1678", -- Cap27_m05_D
	"fa422bab-781a-4f44-9d23-23a17531eb4e", -- Cap25_m05_C
	"083f9cc6-fd41-4c5d-9f3a-cc63d7a1bc1b", -- Cap06_m01_D
	"e5e650f0-dc71-48ff-afaa-b61c7770284e", -- Hood01_m04_D
	"27fa0d92-44a7-4d13-a065-68f8b15232b3", -- Hood11_m05_C
	"2650ef4f-c709-44fe-aa11-371086f940ce", -- CollarPadded01_m01_C1
	"2ebcd914-64dc-499f-80c0-b606636e12f9", -- CollarChain01_m04_C1
	-- Coifs: helmets need one of the padded or mail ones.
	"1b4b6487-72cc-409e-9296-692b53e0429e", -- CoifCap01_m01_C
	"942a42a0-5c46-4c46-983a-71d86adb43c4", -- CoifSmall01_m01_C2
	"5e71ed75-4c1e-4149-acb1-3cb4355d9188", -- CoifLarge02_m08_C3
	"86cf52c6-4329-4e07-b316-facdb667a386", -- CoifMail01_m03_C2
	-- Open helmets.
	"3b0a1c2e-c631-47d6-b5f4-ac798318e86d", -- SkullCap01_m01_D1
	"81bfb39f-d6da-4299-9776-98a93360dcff", -- KettleHat02_m02_D2
	"3437c616-a14c-4ba2-a382-f4898765eeff", -- KettleHat04_m01_B4
	"fb7ebf36-7aea-410d-800e-2482193d0982", -- BascinetOpen02_m02_C1
	"3b42d9a1-186b-4e40-b5c9-d5c20b566a76", -- BascinetOpen09_m02_B1
	-- Closed helmets.
	"d8c9ae5a-ac99-479b-9529-277814dd629f", -- BascinetVisor02_m03_D3
	"b0b3babe-9c0a-4cb4-9f50-f4447a835ffa", -- BascinetVisor01_m01_C3
	"7407d0ea-c069-4b07-8f4d-63e123e3c0ef", -- BascinetVisor05_m01_C4
	-- Meshes with no morphs of their own, which get a new block: the rest of those go the same way.
	"328f9996-a384-452e-a5a5-57c9c108a996", -- Cap11_m05_D
	"701e2d4b-e7bd-406c-b24b-297688ad969e", -- BascinetAlberich_m01
	"4bda7856-ec3a-41f2-a4b3-337c5c3b8b97", -- HoodAlbik_m01
	-- Tunics, aprons and robes.
	"3a5203e8-8204-4b49-bf4b-f226382e7488", -- TunicShort03_m05_D
	"8e5cbba2-340d-4ba5-a2f7-e18254fb173b", -- TunicShort08_m04_C
	"777154c4-0a50-4d59-bbbb-323bbceefc3e", -- TunicLong01_m01_C
	"043136b0-da77-4ef5-b9bb-970c8daeb58f", -- TunicLong03_m01_D
	"e9415ffd-f446-4b16-af3b-8e679784f6e3", -- Habit01_m02_C
	-- Padded: mail and plate need one of these.
	"db5c885c-d40f-4712-994b-69ae4da2690c", -- Caftan01_m02_D1
	"00b7ed62-a7bd-4269-acfa-8d852366579b", -- GambesonShort01_m04_D2
	"01fd6791-d9dc-46d3-8331-1ac65ee61dd5", -- GambesonLong01_m06_C3
	"eda316a4-59d9-49ae-b67b-f6837789bd0c", -- TorsoPainter_m01
	-- Coats.
	"d538e764-90f1-49e5-85bf-16e7717e7723", -- Coat07_m01_B
	"5c0210fe-af18-49cd-b7b7-cfff7e1472f4", -- Waffenrock02_m04_D
	-- Mail and plate.
	"0364c89d-ac13-44ef-94d5-22b4047e7a26", -- MailShort01_m03_C4
	"2c501caf-4279-4bdf-82ea-9ba4bfaa4677", -- MailLong01_m03_C5
	"43f25763-bdbd-4e22-a946-722e2fd156c4", -- Brigandine01_m01_D3
	"85bf9cdb-d3ad-4ff3-b77e-a01319ed87d3", -- Cuirass01_m01_C2
	"d41a661e-e894-41eb-8379-b03fd75567b3", -- Cuirass08_m08_C4
	-- Arms and hands.
	"6e49be7e-8972-4a8f-bd3b-011ffa55a198", -- BrigandineArm01_m02_D1
	"0bd0ee54-f7c8-4808-b620-da6d059640fe", -- ArmPlate03_m02_D1
	"344b633a-b7a0-44ef-8a11-9d1288f9a0ca", -- ArmPlate02_m03_C3
	"0a218fa9-58c7-4696-b5a3-7954e639dd9e", -- HandWrap01_m04_E
	"2db34fd5-db13-44ce-843d-a794a8077f7e", -- Gloves01_m05_C1
	"916a6a5e-a1c1-4db7-b573-909c139a1b52", -- Gauntlets01_m02_C3
	-- Legs: leg armor needs padded hose.
	"3f1553ae-e22d-4472-93e4-caaf782a166e", -- HoseLoose01_m04_C
	"5cb3676d-3bf5-4b1a-ae3c-16b0c970a736", -- HoseSeparate01_m04_D
	"f3aa4492-06fb-4ce3-9e41-784cbac8801f", -- HoseJoined01_m01_C
	"6ca69142-da64-4abc-b989-682fc91b83c7", -- LegsPadded01_m10_C3
	"8472dd03-91d6-4496-a92e-e6e9baaa46ba", -- LegsBrigandine01_m04_D2
	"3d5708c2-65a2-433e-9792-03c3cbb5c14d", -- LegsPlate04_m05_D1
	"dd0c4b0d-c890-4d72-8761-aab1781d9276", -- LegsPlate01_m02_C3
	-- Feet.
	"765d83b6-e6c8-4caf-8fb4-cdae43c41985", -- Shoes04_m01_E
	"847e9aa2-8c3a-4a4f-a38e-dab873310062", -- BootsAnkle01_m02_C
	"3c488ae2-0031-48f9-92e3-3bbe612e161a", -- BootsKnee03_m03_C
	"1113ab25-a055-478e-b0c9-42b5d0cb2c6d", -- Spurs01_m01_C
}
function WomanTest.Dress()
	for _, class in ipairs(WomanTest.CLOTHES) do
		ML.Try("woman dress", function()
			if not player.inventory:FindItem(class) then
				player.inventory:CreateItem(class, 1, 1)
			end
			player.actor:EquipInventoryItem(player.inventory:FindItem(class))
		end)
	end
	ML.Log("woman dress done")
end

function WomanTest.Gear()
	local given = 0
	for _, class in ipairs(WomanTest.GEAR) do
		ML.Try("woman gear", function()
			if not player.inventory:FindItem(class) then
				player.inventory:CreateItem(class, 1, 1)
				given = given + 1
			end
		end)
	end
	ML.Log("woman gear given", given, "of", #WomanTest.GEAR)
end

function WomanTest.Shop()
	for _, class in ipairs(ML.WOMAN_CLOTHES_SAMPLE) do
		ML.Try("woman shop", function() player.inventory:CreateItem(class, 1, 1) end)
	end
	ML.Log("woman shop given", #ML.WOMAN_CLOTHES_SAMPLE)
end

-- Henry's double in the cutscenes of the engine. A double is an AnimChar that takes its
-- look from the soul in Properties.Body.guidBodyPresetId. 202 doubles name the player's soul; 27 name a soul of their
-- own that the game's Storm rules give Henry's head: wet, injured, whipped, naked, dreaming. These commands put doubles
-- in front of the player to see whether one with the player's soul shows her, and how a double can change its soul
-- while the game runs.
WomanTest.ACTOR_NAME = "ml_actor_test_"
WomanTest.ACTOR_DISTANCE = 2.5
WomanTest.ACTOR_SPACING = 1.0
WomanTest.ACTOR_ROW = 4
WomanTest.PLAYER_SOUL = "4c2dcffb-dea1-6263-72d7-b39f4db2d8b5"
WomanTest.ACTOR_SOULS = {
	player = WomanTest.PLAYER_SOUL,
	injured = "734090a0-9276-4783-9d31-d6a66c69673b", -- prepadeni_jindrichInjured: the fall
	wet = "2a15d6ae-46cf-4172-825e-ab4cd504dcc0", -- prepadeni_jindrichWet: the lake
	dream = "4407e676-8058-4f2b-ad2f-8228f9c1989f", -- kkut_henry: the dream with Martin
}
-- Every soul of Henry's own in the doubles of the game 1.5.6, the ones ml_w_actor_hook changes.
WomanTest.HENRY_SOULS = {
	["734090a0-9276-4783-9d31-d6a66c69673b"] = "prepadeni_jindrichInjured",
	["2a15d6ae-46cf-4172-825e-ab4cd504dcc0"] = "prepadeni_jindrichWet",
	["4407e676-8058-4f2b-ad2f-8228f9c1989f"] = "kkut_henry",
	["e0831215-924c-43b2-8bd9-8c26a5b15b81"] = "cutscene_henry_injured_arm",
	["d47c88db-0a13-4140-870f-b06824b5e3a7"] = "cutscene_henry_whipped_mild",
	["e41ba721-1f76-4182-afbb-46b207b0850c"] = "cutscene_henry_whipped_severe",
	["ff8cd1f5-5470-40d9-b9bb-5262ce4738ad"] = "cutscene_really_naked_henry",
}
WomanTest.actors = {}

local function firstWord(line)
	return (tostring(line or ""):gsub('"', ""):match("%S+"))
end

local function soulOf(word)
	return WomanTest.ACTOR_SOULS[word or "player"] or word
end

local function lastActor()
	local actor = WomanTest.actors[#WomanTest.actors]
	if not actor then
		ML.Log("actor: no test double, ml_w_actor first")
	end
	return actor
end

local function copyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and copyTable(value) or value
	end
	return copy
end

-- The properties of a double as the class has them, in case a spawn takes the table as it comes.
local function actorProperties(soul)
	local properties = AnimChar and AnimChar.Properties and copyTable(AnimChar.Properties) or {
		object_Model = "Objects/Characters/humans/male/skeleton/male.cdf",
		esClothingConfig = "male2",
		characterDetail = 0,
		guidBeardHairOverrideId = "0",
		Body = { guidClothingPresetId = "0", guidWeaponPresetId = "0", fDirtOverride = -1, fBloodOverride = -1,
			fScratchesOverride = -1, bIsMortal = false, guidSubstituteBodyPresetId = "0", bVisorClosed = false },
	}
	properties.bSaved_by_game = false
	properties.bSerialize = false
	properties.bClothingRemoveHelmet = false
	properties.Body.guidBodyPresetId = soul
	return properties
end

local function describe(actor)
	local body = actor.Properties and actor.Properties.Body or {}
	local soul = body.guidBodyPresetId
	local known = WomanTest.HENRY_SOULS[soul] or (soul == WomanTest.PLAYER_SOUL and "player") or "?"
	return string.format("%s soul %s (%s)", tostring(actor:GetName()), tostring(soul), known)
end

-- ml_w_actor [player|injured|wet|dream|<soul id>]: a double in front, facing the player, next to the ones before.
function WomanTest.Actor(line)
	local word = firstWord(line) or "player"
	ML.Try("actor", function()
		local index = #WomanTest.actors + 1
		local position, yaw = player:GetWorldPos(), player:GetWorldAngles().z
		local side = ((index - 1) % WomanTest.ACTOR_ROW - (WomanTest.ACTOR_ROW - 1) / 2) * WomanTest.ACTOR_SPACING
		local actor = System.SpawnEntity({
			class = "AnimChar",
			name = WomanTest.ACTOR_NAME .. index,
			position = {
				x = position.x - math.sin(yaw) * WomanTest.ACTOR_DISTANCE + math.cos(yaw) * side,
				y = position.y + math.cos(yaw) * WomanTest.ACTOR_DISTANCE + math.sin(yaw) * side,
				z = position.z,
			},
			properties = actorProperties(soulOf(word)),
		})
		actor:SetAngles({ 0, 0, yaw + math.pi })
		WomanTest.actors[index] = actor
		ML.Log("actor", index, word, describe(actor))
	end)
end

-- ml_w_actor_set <soul>: the last double gets another soul in its properties, and its script resets.
function WomanTest.ActorSet(line)
	local actor = lastActor()
	if not actor then
		return
	end
	local word = firstWord(line) or "player"
	ML.Try("actor set", function() actor.Properties.Body.guidBodyPresetId = soulOf(word) end)
	ML.Try("actor reset", function() actor:OnReset() end)
	ML.Log("actor set", word, describe(actor))
end

-- ml_w_actor_copy [reverse]: the engine's EntityModule.AnimCharCopyVisual, which no script of the game calls. With no
-- arguments first, so the log says what it asks for, then with the double and the player, or the other way round.
function WomanTest.ActorCopy(line)
	local actor = lastActor()
	if not actor then
		return
	end
	local copy = EntityModule and EntityModule.AnimCharCopyVisual
	ML.Log("actor copy: AnimCharCopyVisual is", type(copy))
	if type(copy) ~= "function" then
		return
	end
	local ok, result = pcall(copy)
	ML.Log("actor copy with no arguments:", ok, tostring(result))
	local first, second = actor.id, player.id
	if firstWord(line) == "reverse" then
		first, second = second, first
	end
	ok, result = pcall(copy, first, second)
	ML.Log("actor copy", first == actor.id and "(double, player)" or "(player, double)", ok, tostring(result))
end

-- ml_w_actor_hook: from now on until the game closes, a double that spawns with a soul of Henry's own spawns with the
-- player's soul. The log names each one, so a cutscene that spawns its doubles shows them.
function WomanTest.ActorHook()
	if WomanTest.hooked then
		ML.Log("actor hook is on already")
		return
	end
	if not (AnimChar and AnimChar.OnSpawn) then
		ML.Log("actor hook: the class AnimChar is not loaded yet, ml_w_actor first")
		return
	end
	local original = AnimChar.OnSpawn
	AnimChar.OnSpawn = function(self, ...)
		local body = self.Properties and self.Properties.Body
		local soul = body and body.guidBodyPresetId
		if WomanTest.HENRY_SOULS[soul] then
			body.guidBodyPresetId = WomanTest.PLAYER_SOUL
			ML.Log("actor hook:", tostring(self:GetName()), WomanTest.HENRY_SOULS[soul], "-> player")
		end
		return original(self, ...)
	end
	WomanTest.hooked = true
	ML.Log("actor hook on")
end

-- ml_w_actor_find: the doubles of Henry that exist now, out of the cutscenes too, with their souls.
function WomanTest.ActorFind()
	ML.Try("actor find", function()
		local total, henry = 0, 0
		for _, entity in pairs(System.GetEntitiesByClass("AnimChar") or {}) do
			total = total + 1
			local name = string.lower(tostring(entity:GetName()))
			if string.find(name, "henry", 1, true) or string.find(name, "jindr", 1, true) then
				henry = henry + 1
				local hidden = ML.Try("actor hidden", function() return entity:IsHidden() end)
				ML.Log("actor find:", describe(entity), "hidden", tostring(hidden))
			end
		end
		ML.Log("actor find:", total, "AnimChar,", henry, "of Henry")
	end)
end

function WomanTest.ActorRemove()
	for _, actor in ipairs(WomanTest.actors) do
		ML.Try("actor remove", function() System.RemoveEntity(actor.id) end)
	end
	ML.Log("actor remove:", #WomanTest.actors)
	WomanTest.actors = {}
end

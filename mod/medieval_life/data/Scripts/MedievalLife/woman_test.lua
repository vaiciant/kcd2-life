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

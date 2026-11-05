-- =============================================================================
-- Origins of the new character: clothes, weapon, money, experience and a few things
-- to carry. The data is in mod/medieval_life/origins.toml, and this is only the logic.
-- The selector dresses the model with them, and the new character gets the same when
-- the life starts. Women use their own clothes on the model, and the character stays
-- male underneath.
-- =============================================================================
local ML = MedievalLife

ML.Origins = {}
local Origins = ML.Origins

Origins.LIST = ML.ORIGINS
Origins.DEFAULT = ML.ORIGIN_DEFAULT
Origins.CLEAN_MS = 500

function Origins.Dress(entity, index, female)
	local origin = Origins.LIST[index]
	ML.Try("origin dress", function()
		entity.actor:EquipClothingPreset(female and origin.clothes_female or origin.clothes)
		if origin.weapon then
			entity.actor:EquipWeaponPreset(origin.weapon)
		end
	end)
end

-- generic_naked. The preset of men would reach the rule of clothes before its pieces can go.
Origins.NAKED = "00000000-0000-0000-0000-000000000006"

local function itemIds()
	local ids = {}
	for _, id in pairs(player.inventory:GetInventoryTable() or {}) do
		ids[tostring(id)] = id
	end
	return ids
end

local function create(class, health, kept)
	local before = itemIds()
	player.inventory:CreateItem(class, health, 1)
	for key, id in pairs(itemIds()) do
		if not before[key] then
			kept[key] = true
			return id
		end
	end
end

-- DeleteItem without the count deletes nothing.
local function clean(classes, kept)
	for key, id in pairs(itemIds()) do
		local item = ItemManager.GetItem(id)
		if item and classes[item.class] and not kept[key] then
			player.inventory:DeleteItem(id, -1)
			if itemIds()[key] then
				player.inventory:RemoveItem(id, -1)
			end
			ML.Log("origin clean", item.class, "gone=", itemIds()[key] == nil)
		end
	end
end

-- If Skald did not answer, the weapon still goes to the pack.
local function checkWeapons(origin)
	for _, class in ipairs(origin.weapons) do
		if player.inventory:GetCountOfClass(class) == 0 then
			ML.Log("origin weapon: not given by Skald", class)
			player.inventory:CreateItem(class, origin.weapon_health, 1)
		end
	end
end

-- A woman wears the copy of each item of her preset, which a soul of a man can put on.
-- What the presets put on the player does not come back after restarting the game, and
-- what CreateItem makes does. The clothes preset is still what takes off the clothes of
-- the soul, so each piece is changed for a real copy, and the old one can only go once
-- it is off. EquipInventoryItem only hangs a weapon on the model, so Skald gives it and
-- puts it in its slot, from the token that Life.Begin sends.
function Origins.Wear(index)
	local origin = Origins.LIST[index]
	local woman = ML.Female.IsWomanActive()
	local classes, kept = {}, {}
	for _, piece in ipairs(woman and origin.wear_female or origin.wear) do
		local class, health = piece[1], piece[2]
		classes[class] = true
		local copy = woman and ML.Female.CopyOf(class) or class
		ML.Try("origin wear", function() player.actor:EquipInventoryItem(create(copy, health, kept)) end)
	end
	Script.SetTimer(Origins.CLEAN_MS, function() ML.Try("origin clean", clean, classes, kept) end)
	if origin.wield_token then
		ML.Try("origin weapon", checkWeapons, origin)
	end
end

-- What the new character gets. Skald does not take part: all of it goes on the inventory and the soul of the new character.
function Origins.Apply(index)
	local origin = Origins.LIST[index]
	local preset = ML.Female.IsWomanActive() and Origins.NAKED or origin.clothes
	ML.Try("origin clothes", function() player.actor:EquipClothingPreset(preset) end)
	ML.Store.Set("origin", index)
	-- With an economy mod, its share in whole groschen.
	ML.Try("origin money", function() player.inventory:CreateItem(ML.Life.COIN_ITEM, 1, ML.Economy.WholeGroschen(origin.money)) end)
	for _, item in ipairs(origin.items) do
		ML.Try("origin item", function() player.inventory:CreateItem(item[1], 1, item[2]) end)
	end
	for skill, xp in pairs(origin.xp) do
		ML.Try("origin xp", function() player.soul:AddSkillXP(skill, xp) end)
	end
	ML.Log("origin applied", index)
end

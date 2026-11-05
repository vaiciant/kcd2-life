-- =============================================================================
-- The new character of KCD2 Life: start it, read its state, and the looks of both
-- frameworks in one catalog, men first. The looks themselves belong to KCD2 Female
-- Framework and KCD2 Male Framework, and KCD2 Life only calls them. FemaleCore is the framework's: this is ML.Female, inside KCD2 Life.
-- =============================================================================
local ML = MedievalLife

ML.Female = {}

ML.Female.MAN = ML.Look.MAN
ML.Female.WOMAN = ML.Look.WOMAN

local SWITCH_TOKEN = "43723559-8b7d-5cae-8c55-d57645f282f6"
local SWITCH_DELAY_MS = 1500
local TOKEN_MS = 1000
local SCREEN_MS = 8000
local LOOK_SHOW_MS = 9500

-- Skald reacts when it arrives.
local function sendToken(guid)
	ML.Try("spawn token", function() player.inventory:CreateItem(guid, 1, 1) end)
	Script.SetTimer(TOKEN_MS, function()
		ML.Try("spawn token", function() player.inventory:DeleteItemOfClass(guid, 1) end)
	end)
end

-- State

function ML.Female.IsWomanActive()
	return ML.Store.Get("woman") == 1
end

function ML.Female.IsSpawned()
	return ML.Life.IsStarted()
end

function ML.Female.IsNaked()
	for class, value in pairs(ML.Look.NAKED_TOKENS) do
		if ML.TakeToken(class) then
			ML.Store.Set("naked", value)
		end
	end
	return ML.Store.Get("naked") == 1
end

-- Looks

-- Each look of a framework, with its gender and the class of its model.
local function tagged(look, gender)
	if look then
		look.gender = gender
		look.class = gender == ML.Female.WOMAN and "NPC_Female" or "NPC"
	end
	return look
end

function ML.Female.GetLook(id)
	return tagged(MaleCore.GetLook(id), ML.Female.MAN) or tagged(FemaleCore.GetLook(id), ML.Female.WOMAN)
end

-- In menu order: men, then women, each by id.
function ML.Female.ListLooks(gender)
	local list = {}
	for _, kind in ipairs({ { ML.Female.MAN, MaleCore }, { ML.Female.WOMAN, FemaleCore } }) do
		if gender == nil or gender == kind[1] then
			for _, look in ipairs(kind[2].ListLooks()) do
				list[#list + 1] = tagged(look, kind[1])
			end
		end
	end
	return list
end

function ML.Female.RefreshModel()
	ML.Look.Refresh()
end

function ML.Female.RandomName(gender, ethnicity)
	return ML.Names.Random(gender, ethnicity)
end

-- Starting a character. The caller covers the screen and has no dialog open: SwitchPlayer with one open
-- locks the new character. The callbacks get the context back untouched, and a load cancels them.
function ML.Female.RequestSpawn(request)
	local look = ML.Female.GetLook(request.look)
	ML.Store.Set("woman", look and look.gender == ML.Female.WOMAN and 1 or 0)
	ML.Store.Set("look", look and look.id or 0)
	local function call(callback)
		if callback then
			ML.Try("spawn callback", callback, request.context)
		end
	end
	local hasLook = ML.Look.Choose(request.look)
	-- The first haircut at a barber is free, to choose the hair: the barber of the framework of a woman or of a man. The token must reach Henry, before the switch.
	if look and look.gender == ML.Female.WOMAN then
		ML.Try("free haircut", FemaleCore.GiveFreeHaircut)
	elseif look and MaleCore and MaleCore.GiveFreeHaircut then
		ML.Try("free haircut", MaleCore.GiveFreeHaircut)
	end
	Script.SetTimer(SWITCH_DELAY_MS, function() sendToken(SWITCH_TOKEN) end)
	if hasLook then
		Script.SetTimer(LOOK_SHOW_MS, function()
			call(request.onSwitched)
			ML.Look.Rebuild(request.look, function() call(request.onReady) end)
		end)
	else
		Script.SetTimer(SCREEN_MS, function()
			call(request.onSwitched)
			call(request.onReady)
		end)
	end
end

-- Clothing

-- The copy of a woman's item that she can wear, from KCD2 Female Framework.
function ML.Female.CopyOf(class)
	return FemaleCore.CopyOf(class)
end

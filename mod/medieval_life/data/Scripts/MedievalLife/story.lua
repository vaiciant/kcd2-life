-- =============================================================================
-- Where Henry's story is, read from the world it leaves. No call tells which quest is
-- active, so Skald watches the layer profiles that the quests load and unload, and gives
-- a token each time (ml_story.xml). The work sites of Trosky castle and of Semine are
-- offered only while the story has them in the world (jobs.toml, requires). ml_status
-- shows what arrived, and whether the game finds some NPC of the castle and of Semine by
-- name.
-- =============================================================================
local ML = MedievalLife

ML.Story = {}
local Story = ML.Story

-- Each one: the token of loaded and of unloaded.
Story.PROFILES = {
	castle_settled = { on = "8c887bbd-870a-5113-9f0a-b6ef8a3c58a0", off = "49a8fc34-e196-5913-b3cd-6a3e0b148799" }, -- the people of Trosky castle are there, trosky_settlingDefault
	castle_gates = { on = "7655ca2f-6b8d-541b-a17a-b2468711c80c", off = "5f116898-f496-5bfd-9e44-ce1704c09ba2" }, -- the gates of Trosky castle are open, trosky_fullyOpened
	castle_army = { on = "62f1ac17-28ae-5b7a-8aea-7a6b61e0f34c", off = "eb4d1aba-83b3-5a94-9425-80ec724a3cd9" }, -- the army camp of M09 is at the castle, trosky_armyCamp
	bergow = { on = "4ebe5c90-e5ea-5a16-b3a7-8fe55b0ba70d", off = "17ca62a7-f80e-5c82-9d5e-8c2df9960f34" }, -- Otto von Bergow is at the castle, ttro_bergov
	semine_people = { on = "369e0e9d-e150-5781-9059-4827a293ed37", off = "9bcb028b-623c-5e4c-b84e-33410fa23d47" }, -- the people of Semine's manor are there, trosecko_otherSemins
	semine_burned = { on = "00f2e77f-7bf7-54ff-b9e2-a0eee6a41ddd", off = "6655f0d9-a97b-53f9-9fd9-89d56d588742" }, -- Semine burned in M08, semin_burned
	semine_wedding = { on = "d5ab21a9-3ff5-5ce7-8f3c-786c1e534e06", off = "6b9a74e4-5a4d-5358-b320-3681f55e9285" }, -- the wedding of M05 is on in Semine, semin_duringQuestSvatba
}
-- NPC of the castle and of Semine that the story brings and takes away.
Story.NPCS = { "ttro_bergov", "ttro_tomas", "ttro_kovar", "ttro_closedCastle_trosky_1", "tsem_seminsr", "tsem_man_16", "tsem_man_17" }

-- 1 loaded, 0 unloaded, nil while no token came. Each load sends them all again, so memory is enough.
Story.state = {}

local function loaded(key)
	return Story.state[key] == 1
end

-- What each requires of jobs.toml asks of the world.
Story.RULES = {
	-- The people of the castle there, its gates open, and no army camp: from M07 to M09, and after M12.
	castle = function() return loaded("castle_settled") and loaded("castle_gates") and not loaded("castle_army") end,
	-- Semine has not burned in M08.
	semine = function() return not loaded("semine_burned") end,
	-- And the people of the manor are there, with no wedding on.
	semine_manor = function() return loaded("semine_people") and not loaded("semine_burned") and not loaded("semine_wedding") end,
}

-- Whether Henry's story has that place in the world. A site without requires always is.
function Story.Open(requires)
	return requires == nil or Story.RULES[requires]()
end

function Story.Update()
	for key, tokens in pairs(Story.PROFILES) do
		if ML.TakeToken(tokens.on) then
			Story.state[key] = 1
			ML.Log("story", key, "loaded")
		end
		if ML.TakeToken(tokens.off) then
			Story.state[key] = 0
			ML.Log("story", key, "unloaded")
		end
	end
end

ML.TickHandlers[#ML.TickHandlers + 1] = Story.Update

function Story.Report()
	local profiles = {}
	for key in pairs(Story.PROFILES) do
		profiles[#profiles + 1] = key .. "=" .. tostring(Story.state[key])
	end
	table.sort(profiles)
	ML.Log("story profiles", table.concat(profiles, " "))
	local npcs = {}
	for _, name in ipairs(Story.NPCS) do
		local entity = ML.Try("story npc", function() return System.GetEntityByName(name) end)
		npcs[#npcs + 1] = name .. "=" .. (entity and "found" or "none")
	end
	ML.Log("story npcs", table.concat(npcs, " "))
end

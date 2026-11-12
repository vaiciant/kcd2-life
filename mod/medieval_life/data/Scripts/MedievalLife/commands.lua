-- =============================================================================
-- Console commands (ml_*).
-- =============================================================================
local ML = MedievalLife

ML.Commands = {}
local Commands = ML.Commands

-- %line arrives wrapped in quotes.
local function stripQuotes(line)
	if type(line) ~= "string" then
		return ""
	end
	return (line:gsub('^%s*"', ""):gsub('"%s*$', ""))
end

function Commands.Status()
	ML.Log("status gen=", ML.gen, "region=", ML.Region(), "state=", ML.Store.Get("state"), "origin=", ML.Store.Get("origin"), "name=", ML.Typing.Load(), "book=", ML.WorkBook.Has(), "jobs=", (ML.WorkBook.BookRecord() or {}).jobs, "known points=", ML.FastTravel.KnownCount(), "known marks=", ML.MapMarks.KnownCount(), "woman in men's clothes=", ML.Store.Get("woman_in_mens_clothes", 0), "day=", ML.Days.Current(), "date=", table.concat({ ML.Days.Date() }, " "), "month days=", ML.Days.MonthDays(), "world day=", Calendar.GetWorldDay(), "world time=", Calendar.GetWorldTime(), "hour=", Calendar.GetWorldHourOfDay(), "economy=", ML.Economy.active and ML.ECONOMY.name or "game")
	ML.Story.Report()
end

-- Test shortcut, to remove before publishing: the experience each level asks for, to set the origins.
Commands.CURVE_LEVELS = 10

function Commands.Curve()
	ML.Try("xp curve", function()
		local skills, stats = {}, {}
		for level = 1, Commands.CURVE_LEVELS do
			skills[level] = player.soul:GetNextLevelSkillXP("survival", level)
			stats[level] = player.soul:GetNextLevelStatXP("strength", level)
		end
		ML.Log("xp skill", table.concat(skills, " "))
		ML.Log("xp stat", table.concat(stats, " "))
	end)
end

function Commands.Pos()
	ML.Try("pos", function()
		local p = player:GetWorldPos()
		ML.Log(string.format("pos x=%.2f y=%.2f z=%.2f yaw=%.4f", p.x, p.y, p.z, player:GetWorldAngles().z))
	end)
end

-- For videos and pictures: the character's animation stops, body and face, and ml_freeze again lets it go on.
-- Layer -1 is the whole character in CryEngine; each layer is set too, in case that is not so here. A load starts with
-- the animation going.
Commands.FREEZE_LAYERS = 16
local frozenGen = nil

local function animationSpeed(speed)
	ML.Try("freeze character", function() player:SetAnimationSpeed(0, -1, speed) end)
	for layer = 0, Commands.FREEZE_LAYERS - 1 do
		ML.Try("freeze layer", function() player:SetAnimationSpeed(0, layer, speed) end)
	end
	ML.Try("freeze face", function() player:EnableProceduralFacialAnimation(speed > 0) end)
end

function Commands.Freeze()
	local frozen = frozenGen == ML.gen
	animationSpeed(frozen and 1 or 0)
	frozenGen = (not frozen) and ML.gen or nil
	ML.Log(frozen and "freeze: the character moves again" or "freeze: the character stands still, ml_freeze lets it move again")
end

-- Every work site, whether Henry's story offers it, and where its first NPC is, if it is in this region.
function Commands.Sites()
	for _, site in ipairs(ML.JOB_SITES) do
		local where = "not in this region"
		for _, name in ipairs(site.npcs) do
			local entity = System.GetEntityByName(name)
			if entity then
				local p = entity:GetWorldPos()
				where = string.format("%s x=%.1f y=%.1f z=%.1f", name, p.x, p.y, p.z)
				break
			end
		end
		ML.Log("site", site.key, ML.Story.Open(site.requires) and "open" or "closed", where)
	end
end

-- Test shortcut, to remove before publishing. Each place is next to a fast travel point.
Commands.PLACES = {
	troskowitz = { region = "trosky", x = 2321.6, y = 2045.6, z = 108 },
	zhelejov = { region = "trosky", x = 1772.5, y = 1967.4, z = 43 },
	pass = { region = "trosky", x = 2644.9, y = 1531.6, z = 88 },
	suchdol = { region = "kuttenberg", x = 698.2, y = 3287.8, z = 142 },
}

-- People move during the day, so these go to where the NPC is now.
Commands.PEOPLE = {
	fiala = "tzel_fiala",
	adam = "kkut_adamsBarber",
	beta = "kkut_betasBarber",
}
for _, site in ipairs(ML.JOB_SITES) do
	Commands.PEOPLE[site.key] = site.npcs[1]
end
Commands.PERSON_OFFSET = 1.5

local function gotoPerson(name)
	local entity = System.GetEntityByName(Commands.PEOPLE[name])
	if not entity then
		ML.Log("ml_goto:", name, "is not in this region")
		return
	end
	local position = entity:GetWorldPos()
	ML.Try("goto", function() player:SetWorldPos({ x = position.x + Commands.PERSON_OFFSET, y = position.y, z = position.z + 1 }) end)
	ML.Log(string.format("went to %s at x=%.1f y=%.1f z=%.1f", name, position.x, position.y, position.z))
end

function Commands.Goto(line)
	local name = stripQuotes(line):gsub("%s", ""):lower()
	if Commands.PEOPLE[name] then
		gotoPerson(name)
		return
	end
	local place = Commands.PLACES[name]
	if not place then
		ML.Log("ml_goto needs a place, a work site of jobs.toml, or: fiala, adam, beta")
		return
	end
	if place.region ~= ML.Region() then
		ML.Log("ml_goto:", name, "is in", place.region)
		return
	end
	ML.Try("goto", function() player:SetWorldPos({ x = place.x, y = place.y, z = place.z }) end)
	ML.Log("went to", name)
end

-- Test shortcuts for S8, to remove before publishing.
Commands.BED_DISTANCE = 1.5
Commands.BREAD = "86e4ff24-88db-4024-abe6-46545fa0fbd1"
Commands.BEER = "52afd6fa-9377-457c-83a2-b5b39321a4dc"
Commands.BEERS = 4
Commands.EAT_CHECK_MS = 3000

function Commands.Needs()
	ML.Try("needs", function()
		local soul = player.soul
		ML.Log("needs hunger=", soul:GetState("hunger"), "tiredness=", soul:GetState("exhaust"), "health=", soul:GetState("health"), "drunk=", soul:GetDerivedStat("dru"))
	end)
end

-- An optional turn in degrees: the bed needs a free side for the player to lie down.
function Commands.Bed(line)
	local turn = math.rad(tonumber(stripQuotes(line)) or 0)
	ML.Try("bed", function()
		local position, yaw = player:GetWorldPos(), player:GetWorldAngles().z
		ML.EmployeeBed.Place({
			x = position.x - math.sin(yaw) * Commands.BED_DISTANCE,
			y = position.y + math.cos(yaw) * Commands.BED_DISTANCE,
			z = position.z,
		}, yaw + turn)
	end)
end

function Commands.BedRemove()
	ML.Try("bed remove", ML.EmployeeBed.Remove)
	ML.Log("employee bed there:", System.GetEntityByName(ML.EmployeeBed.NAME) ~= nil)
end

function Commands.Eat()
	ML.Try("eat", function()
		local before = player.soul:GetState("hunger")
		player.inventory:CreateItem(Commands.BREAD, 1, 1)
		ML.Log("eat returned", player.soul:EatItem(Commands.BREAD), "hunger", before, "->", player.soul:GetState("hunger"))
		Script.SetTimer(Commands.EAT_CHECK_MS, Commands.Needs)
	end)
end

function Commands.Beer()
	ML.Try("beer", function() player.inventory:CreateItem(Commands.BEER, 1, Commands.BEERS) end)
end

-- Test shortcuts for the steady job, to remove before publishing.
function Commands.Time(line)
	local hour = tonumber(stripQuotes(line))
	if not hour then
		ML.Log("ml_time needs an hour, like 8 or 12.5")
		return
	end
	ML.Try("time", function()
		Calendar.SetWorldTime(Calendar.GetWorldTime() + (hour - Calendar.GetWorldHourOfDay()) % 24 * 3600)
		XGenAIModule.SendMessageToEntity(player.this.id, "timekeeper:recalculate", "")
	end)
	ML.Employment.Status()
end

function Commands.Money(line)
	local groschen = tonumber(stripQuotes(line)) or 100
	ML.Try("money", function() player.inventory:CreateItem(ML.Life.COIN_ITEM, 1, groschen * 10) end)
	ML.Log("money", player.inventory:GetMoney())
end

function Commands.Compass(line)
	ML.BedMarker.BEARING_OFFSET = tonumber(stripQuotes(line)) or ML.BedMarker.BEARING_OFFSET
	ML.Log("compass offset", ML.BedMarker.BEARING_OFFSET)
end

function Commands.Settings(line)
	ML.Settings.Report(stripQuotes(line))
end

-- Moves whole days forward. Those days do not count as absences.
function Commands.Days(line)
	local days = tonumber(stripQuotes(line)) or 1
	ML.Try("days", function()
		Calendar.SetWorldTime(Calendar.GetWorldTime() + days * 86400)
		XGenAIModule.SendMessageToEntity(player.this.id, "timekeeper:recalculate", "")
		ML.Store.Set("job_checked_day", Calendar.GetWorldDay())
	end)
	ML.Employment.Status()
end

-- Runs Lua and logs the result. Use single quotes in the code: the console swallows "=".
function Commands.Lua(line)
	if not ML.Try("devmode", function() return System.IsDevModeEnable() end) then
		ML.Log("ml_lua needs -devmode")
		return
	end
	local code = stripQuotes(line)
	local chunk, err = loadstring("return " .. code)
	if not chunk then
		chunk, err = loadstring(code)
	end
	if not chunk then
		ML.Log("ERROR compile", err)
		return
	end
	local result = ML.Pack(pcall(chunk))
	if not result[1] then
		ML.Log("ERROR runtime", result[2])
		return
	end
	local out = {}
	for i = 2, result.n do
		out[#out + 1] = ML.ToStr(result[i])
	end
	ML.Log("=>", #out > 0 and table.concat(out, " | ") or "(no value)")
end

-- Test S4, to remove before publishing.
Commands.REP_RANGE = 8
Commands.NPC_CLASSES = { "NPC", "NPC_Female" }
Commands.REP_LINES = 40
Commands.REP_TOWN = "trosecko_settlements_troskovice"
Commands.REP_NPCS_RANGE = 30
Commands.SCHNAPPS = "d273bcad-6b58-4eae-9d2a-800c40176cfd"
Commands.SCHNAPPS_AMOUNT = 3

local function nearestNpc()
	local position, best, bestDistance = player:GetWorldPos(), nil, nil
	for _, class in ipairs(Commands.NPC_CLASSES) do
		for _, entity in pairs(System.GetEntitiesInSphereByClass(position, Commands.REP_RANGE, class) or {}) do
			local other = entity:GetWorldPos()
			local distance = (other.x - position.x) ^ 2 + (other.y - position.y) ^ 2
			if not bestDistance or distance < bestDistance then
				best, bestDistance = entity, distance
			end
		end
	end
	return best
end

function Commands.Rep()
	local npc = ML.Try("rep npc", nearestNpc)
	if not npc then
		ML.Log("rep: no NPC nearby")
		return
	end
	local factionId = ML.Try("rep faction id", function() return npc.soul:GetFactionID() end)
	local faction = ML.Try("rep faction", function() return RPG.GetFactionById(factionId) end)
	ML.Log("rep npc=", npc:GetName(), "faction=", factionId,
		"relation=", ML.Try("rep relation", function() return npc.soul:GetRelationship(player.soul:GetId(), "Current") end),
		"faction rep=", faction and ML.Try("rep value", function() return faction:GetReputation() end),
		"base=", faction and ML.Try("rep base", function() return faction:GetBaseReputation() end))
end

-- A row of reputation_change and how many times: ml_rep_add ml_rep_up 5
function Commands.RepAdd(line)
	local name, times = string.match(stripQuotes(line) or "", "(%S+)%s*(%d*)")
	local npc = ML.Try("rep npc", nearestNpc)
	if not name or not npc then
		ML.Log("ml_rep_add needs a row and an NPC nearby")
		return
	end
	for _ = 1, tonumber(times) or 1 do
		ML.Try("rep add", function() npc.soul:ModifyPlayerReputation(name, true) end)
	end
	Commands.Rep()
end

-- The factions whose name has that text, with their value and base, and how many have another base.
function Commands.RepTree(line)
	local text = stripQuotes(line or "")
	text = text ~= "" and text or Commands.REP_TOWN
	local shown, other = 0, 0
	for _, id in ipairs(ML.FACTIONS) do
		ML.Try("rep tree", function()
			local faction = RPG.GetFactionById(id)
			local base = faction and faction:GetBaseReputation()
			if faction and base ~= ML.Reputation.BASE then
				other = other + 1
			end
			if faction and shown < Commands.REP_LINES and string.find(id, text, 1, true) and faction:GetReputation() ~= 0 then
				shown = shown + 1
				ML.Log("rep tree", id, faction:GetReputation(), base)
			end
		end)
	end
	ML.Log("rep factions=", #ML.FACTIONS, "with another base=", other)
end

-- The panel of reputation lists places: each row is a faction with a location. This shows what a
-- location has, to find the number of the panel.
function Commands.RepPlaces(line)
	local text = stripQuotes(line or "")
	text = text ~= "" and text or Commands.REP_TOWN
	local shownMeta, shown = false, 0
	local candidates = { "GetReputation", "GetPlayerReputation", "GetName", "GetId", "GetDisplayName", "GetFactionId" }
	for _, id in ipairs(ML.FACTIONS) do
		ML.Try("rep places", function()
			local faction = RPG.GetFactionById(id)
			local locationId = faction and faction:GetLocationId()
			if not locationId or shown >= Commands.REP_LINES or not string.find(id, text, 1, true) then
				return
			end
			shown = shown + 1
			local location = RPG.GetLocationById(locationId)
			if location and not shownMeta then
				shownMeta = true
				local meta = getmetatable(location)
				ML.Log("rep place type=", type(location), ML.ToStr(location))
				ML.Log("rep place meta=", meta and ML.ToStr(meta.__index or meta))
			end
			local values = {}
			for _, name in ipairs(candidates) do
				local ok, value = pcall(function() return location[name](location) end)
				if ok then
					values[#values + 1] = name .. "=" .. tostring(value)
				end
			end
			ML.Log("rep place", id, "faction=", faction:GetReputation(), "location=", tostring(locationId), table.concat(values, " "))
		end)
	end
	ML.Log("rep places shown=", shown, "override=", System.GetCVar("wh_rpg_ReputationOverride"), "enable override=", System.GetCVar("wh_rpg_EnableReputationOverride"), "cache=", System.GetCVar("wh_rpg_LocationReputationCacheExpirationTime"))
end

-- Each row of the panel with that text, with GetReputation and its base.
function Commands.RepPanel(line)
	local text = stripQuotes(line or "")
	text = text ~= "" and text or Commands.REP_TOWN
	for _, id in ipairs(ML.FACTIONS) do
		ML.Try("rep panel", function()
			local faction = RPG.GetFactionById(id)
			if ML.FACTION_ROWS[id] == id and string.find(id, text, 1, true) and faction:GetBaseReputation() ~= 0 then
				ML.Log("rep panel", id, "get=", faction:GetReputation(), "base=", faction:GetBaseReputation())
			end
		end)
	end
end

-- A faction and every one above it, with GetReputation and base: ml_rep_chain <faction>
function Commands.RepChain(line)
	local id = stripQuotes(line or "")
	id = id ~= "" and id or Commands.REP_TOWN .. "_commonFolk_tavern"
	while id do
		local current = id
		ML.Try("rep chain", function()
			local faction = RPG.GetFactionById(current)
			ML.Log("rep chain", current, "get=", faction:GetReputation(), "base=", faction:GetBaseReputation())
		end)
		id = ML.FACTION_PARENTS[id]
	end
end

-- A row of reputation_change on one faction, without NPC: ml_rep_faction <faction> <row> [times]
function Commands.RepFaction(line)
	local id, name, times = string.match(stripQuotes(line), "(%S+)%s+(%S+)%s*(%d*)")
	local faction = id and RPG.GetFactionById(id)
	if not faction then
		ML.Log("ml_rep_faction needs a faction and a row")
		return
	end
	local before, after = faction:GetReputation(), nil
	for _ = 1, tonumber(times) or 1 do
		after = ML.Try("rep faction", function() return faction:AddReputation(name) end)
	end
	ML.Log("rep faction", id, "get=", before, "returned=", after, "get now=", faction:GetReputation())
end

-- Every NPC around, to see how far a change reaches.
function Commands.RepNpcs()
	local position = player:GetWorldPos()
	for _, class in ipairs(Commands.NPC_CLASSES) do
		for _, npc in pairs(System.GetEntitiesInSphereByClass(position, Commands.REP_NPCS_RANGE, class) or {}) do
			ML.Try("rep npcs", function()
				ML.Log("rep near", npc:GetName(), npc.soul:GetFactionID(), npc.soul:GetRelationship(player.soul:GetId(), "Current"))
			end)
		end
	end
end

-- Test shortcut, to remove before publishing: drinking it saves, and the game cannot save by hand here.
function Commands.Schnapps(line)
	local amount = tonumber(stripQuotes(line)) or Commands.SCHNAPPS_AMOUNT
	ML.Try("schnapps", function() player.inventory:CreateItem(Commands.SCHNAPPS, 1, amount) end)
end

-- Test F6: the console wraps %line in quotes.
function Commands.OrderForce(line)
	ML.Orders.Force(stripQuotes(line))
end

function Commands.OrderTrust(line)
	ML.Orders.SetTrust(stripQuotes(line))
end

function Commands.CrimeTest(line)
	ML.Orders.CrimeTest(stripQuotes(line))
end

function Commands.CrimeForget(line)
	ML.Orders.CrimeForget(stripQuotes(line))
end

local function register(name, body, help)
	ML.Try("command " .. name, function() System.AddCCommand(name, body, help) end)
end

-- Players see only these. The rest test the systems of the mod: developer mode registers them, for the rest of the
-- session, with ml_developer or when the game runs with -devmode.
register("ml_status", "MedievalLife.Commands.Status()", "Shows the state of the mod")
register("ml_developer", "MedievalLife.Commands.Developer()", "Turns developer mode on until the game closes: the test commands of the mod")
register("ml_switch", "MedievalLife.Switch.Run(%line)", "Switches between Henry and the new character, and saves. Use it with care: it can break a save of KCD2 Life. Type ml_switch yes")
register("ml_uninstall", "MedievalLife.Uninstall.Run(%line)", "Before removing the mods: closes the quests, the job and the errands of the mod, switches back to Henry with Mutt, and saves. Type ml_uninstall yes")

Commands.DEVELOPER = {
	{ "ml_pos", "MedievalLife.Commands.Pos()", "Shows the player position and yaw" },
	{ "ml_freeze", "MedievalLife.Commands.Freeze()", "For videos and pictures: the character's animation stops, and ml_freeze again lets it go on" },
	{ "ml_rent", "MedievalLife.Rent.Report()", "Test shortcut: the bed rented for the night, and whether the owner nearby rents one" },
	{ "ml_rent_bed", "MedievalLife.Rent.BedMode(%line)", "Test shortcut: how a rented high bed is built, stance, game or basic, and the bed again with it" },
	{ "ml_stash", "MedievalLife.Stash.Report()", "Test shortcut: the master chest of this region, whose things it holds and what each character carries for it" },
	{ "ml_tutorials", "MedievalLife.Tutorial.Reset()", "Test shortcut: the tutorials of the new life show again, one after another" },
	{ "ml_sites", "MedievalLife.Commands.Sites()", "Every work site: whether the story offers it, and where its NPC is in this region" },
	{ "ml_xp", "MedievalLife.Commands.Curve()", "Test shortcut: experience per level of a skill and a stat" },
	{ "ml_goto", "MedievalLife.Commands.Goto(%line)", "Test shortcut: troskowitz, zhelejov, pass, suchdol, fiala, adam, beta or a work site" },
	{ "ml_look_refresh", "MedievalLife.Female.RefreshModel()", "Test shortcut: rebuilds the look of the new character" },
	{ "ml_needs", "MedievalLife.Commands.Needs()", "Test shortcut: hunger, tiredness, health and drunkenness" },
	{ "ml_bed", "MedievalLife.Commands.Bed(%line)", "Test shortcut: puts the bed of an employee in front of the player" },
	{ "ml_bed_remove", "MedievalLife.Commands.BedRemove()", "Test shortcut: takes the bed away" },
	{ "ml_eat", "MedievalLife.Commands.Eat()", "Test shortcut: eats a bread from a script" },
	{ "ml_beer", "MedievalLife.Commands.Beer()", "Test shortcut: gives 4 beers" },
	{ "ml_job", "MedievalLife.Employment.Status()", "Test shortcut: state of the steady job" },
	{ "ml_job_fault", "MedievalLife.Employment.AddFault()", "Test shortcut: adds a fault to the steady job" },
	{ "ml_time", "MedievalLife.Commands.Time(%line)", "Test shortcut: moves the clock forward to that hour" },
	{ "ml_w_dress", "MedievalLife.WomanTest.Dress()", "Test M1: puts women's clothes on the character" },
	{ "ml_w_gear", "MedievalLife.WomanTest.Gear()", "Test M4: gives men's clothing and armor of every type, with open and closed helmets" },
	{ "ml_w_shop", "MedievalLife.WomanTest.Shop()", "Test: gives one women's item of the game per mesh, as if bought" },
	{ "ml_w_actor", "MedievalLife.WomanTest.Actor(%line)", "Test 210: puts a cutscene double in front, with the look of a soul: player, injured, wet, dream or an id" },
	{ "ml_w_actor_set", "MedievalLife.WomanTest.ActorSet(%line)", "Test 210: the last double gets another soul, like ml_w_actor_set player, and resets" },
	{ "ml_w_actor_copy", "MedievalLife.WomanTest.ActorCopy(%line)", "Test 210: the engine copies the player's look onto the last double; ml_w_actor_copy reverse, the other way round" },
	{ "ml_w_actor_hook", "MedievalLife.WomanTest.ActorHook()", "Test 210: until the game closes, a double with a soul of Henry's own spawns with the player's soul" },
	{ "ml_w_actor_find", "MedievalLife.WomanTest.ActorFind()", "Test 210: the doubles of Henry that exist now, and their souls" },
	{ "ml_w_actor_remove", "MedievalLife.WomanTest.ActorRemove()", "Test 210: takes the test doubles away" },
	{ "ml_money", "MedievalLife.Commands.Money(%line)", "Test shortcut: gives that many groschen" },
	{ "ml_rep", "MedievalLife.Commands.Rep()", "Test S4: reputation with the nearest NPC" },
	{ "ml_rep_add", "MedievalLife.Commands.RepAdd(%line)", "Test S4: applies a row of reputation_change, like ml_rep_add ml_rep_up_010 5" },
	{ "ml_rep_tree", "MedievalLife.Commands.RepTree(%line)", "Test S4: reputation of the factions with that text in their name" },
	{ "ml_rep_reset", "MedievalLife.Reputation.Reset()", "Test S4: sets every faction of the people back to its base" },
	{ "ml_rep_npcs", "MedievalLife.Commands.RepNpcs()", "Test S4: relation of every NPC around" },
	{ "ml_rep_places", "MedievalLife.Commands.RepPlaces(%line)", "Test S4: reputation of the places of the panel" },
	{ "ml_rep_panel", "MedievalLife.Commands.RepPanel(%line)", "Test S4: GetReputation and the panel of the rows with that text" },
	{ "ml_rep_chain", "MedievalLife.Commands.RepChain(%line)", "Test S4: a faction and every one above it" },
	{ "ml_rep_faction", "MedievalLife.Commands.RepFaction(%line)", "Test S4: applies a row to a faction, like ml_rep_faction <faction> ml_rep_up_100 1" },
	{ "ml_settings", "MedievalLife.Commands.Settings(%line)", "Test shortcut: the settings of this save, or changes one as the menu does, like ml_settings order_deadline 24" },
	{ "ml_orders", "MedievalLife.Orders.Status()", "Test F6: orders of today, taken orders and debts" },
	{ "ml_order_force", "MedievalLife.Commands.OrderForce(%line)", "Test F6: that business gives its order today, like ml_order_force apothecary, or apothecary fetch, or apothecary buy" },
	{ "ml_order_expire", "MedievalLife.Orders.Expire()", "Test F6: the taken orders run out at the next tick" },
	{ "ml_crime_test", "MedievalLife.Commands.CrimeTest(%line)", "Test SC2: the authorities of the town nearby hear that the character stole a slip from Betty, or 300 IOUs with note, like ml_crime_test or ml_crime_test note" },
	{ "ml_crime_forget", "MedievalLife.Commands.CrimeForget(%line)", "Test SC2: the authorities of the town nearby, or one by name, forget their crimes, like ml_crime_forget or ml_crime_forget ttkc_man_2" },
	{ "ml_order_trust", "MedievalLife.Commands.OrderTrust(%line)", "Test F6: what a business has seen, like ml_order_trust apothecary 5, or apothecary 10 5 1 with pickups and orders run out, or apothecary 0 0 0 50 20 with steady and casual hours" },
	{ "ml_schnapps", "MedievalLife.Commands.Schnapps(%line)", "Test shortcut: gives Saviour Schnapps, 3 by default" },
	{ "ml_compass", "MedievalLife.Commands.Compass(%line)", "Test shortcut: turns the mark of the bed on the compass" },
	{ "ml_days", "MedievalLife.Commands.Days(%line)", "Test shortcut: moves that many days forward, without absences" },
	{ "ml_lua", "MedievalLife.Commands.Lua(%line)", "Runs Lua, with -devmode only. Use single quotes inside" },
}

function Commands.Developer()
	if Commands.developer then
		ML.Log("developer mode is on already")
		return
	end
	Commands.developer = true
	for _, command in ipairs(Commands.DEVELOPER) do
		register(command[1], command[2], command[3])
	end
	ML.Log("developer mode on:", #Commands.DEVELOPER, "test commands until the game closes")
end

if ML.Try("devmode", function() return System.IsDevModeEnable() end) then
	Commands.Developer()
end

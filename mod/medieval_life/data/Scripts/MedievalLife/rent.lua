-- =============================================================================
-- A bed for the night. The game rents beds in seven places of the Trosky region, but its rental gives the bed to
-- Henry: the new character pays and is thrown out of it. So the owners there, who are employers of the mod, rent their
-- own: the dialog of work has the option (ml_casual_dialog.xml). The bed is the one of the game, where it is: the mod
-- hides its prompt and puts in its place a bed of its own that nobody claims, as the bed of the steady job, unseen, on the
-- same mattress. Its place, its prompt and the door of the room come from the level (tools/generate_jobs.py). It is the
-- character's until rent_until_hour of the next morning, or for a week, rent_week_days nights for the price of
-- rent_week_paid_nights. A notice says until when, and another when it is over. Like the bed of the job,
-- nothing of it goes in the save but the rental, in the Store.
-- =============================================================================
local ML = MedievalLife

ML.Rent = {}
local Rent = ML.Rent

Rent.KEY = "rent"
Rent.PRICE_VARIABLE = "ml_rent_price"
Rent.STATE_VARIABLE = "ml_rent_state"
Rent.WEEK_PRICE_VARIABLE = "ml_rent_week_price"
Rent.WEEK_STATE_VARIABLE = "ml_rent_week_state"
Rent.UNTIL_TEXT = "@ml_rent_until"
Rent.OVER_TEXT = "@ml_rent_over"
Rent.NOTICE_SECONDS = 8
-- ml_rent_state: the bed can be paid, the money is short, or the bed here is already the character's.
Rent.STATE_PAY = 1
Rent.STATE_SHORT = 2
Rent.STATE_HAVE = 3
Rent.OBJECT_NAME = "ml_rent_bed"
Rent.TRIGGER_NAME = "ml_rent_bed_trigger"
Rent.HOUR_SECONDS = 3600
-- Before this hour, a bed taken at night is until the morning of the same day.
Rent.NIGHT_ENDS = 6

-- The generation the bed was put in place for: the entities are not saved, so every load puts them again.
local placedGen
-- The generation the doors of the rooms were checked for.
local doorsGen

local function coins()
	return ML.Try("rent coins", function() return player.inventory:GetCountOfClass(ML.Life.COIN_ITEM) end) or 0
end

local function siteByKey(key)
	for _, site in ipairs(ML.JOB_SITES) do
		if site.key == key then
			return site
		end
	end
end

-- In tenths of a groschen: the price of the game, or that of the economy mod, in whole groschen. A week costs
-- rent_week_paid_nights nights.
local function price(site, days)
	local nights = days == ML.JOB_RULES.rent_week_days and ML.JOB_RULES.rent_week_paid_nights or 1
	-- With an economy mod, a place may have a price of its own: the room at Zhelejov.
	if ML.Economy.active and site.rent.price_economy then
		return site.rent.price_economy * nights
	end
	return ML.Economy.WholeGroschen(site.rent.price * nights)
end

local function notice(text)
	ML.Try("rent notice", function() Game.SendInfoText(text, false, nil, Rent.NOTICE_SECONDS) end)
end

local function active()
	local rental = ML.Store.Get(Rent.KEY)
	return type(rental) == "table" and rental.site and rental or nil
end

-- Every bed of the mod there is, even if one was left behind.
local function remove()
	for _, name in ipairs({ Rent.TRIGGER_NAME, Rent.OBJECT_NAME }) do
		local entity = System.GetEntityByName(name)
		local left = 10
		while entity and left > 0 do
			System.RemoveEntity(entity.id)
			left = left - 1
			entity = System.GetEntityByName(name)
		end
	end
end

-- The prompt of the game's bed: hidden while the bed of the mod is there, back afterwards. The door of the room, if
-- it has one, is open while the bed is the character's.
local function showGame(site, show)
	local prompt = System.GetEntityByName(site.rent.trigger.name)
	if prompt then
		ML.Try("rent prompt", function() prompt:Hide(show and 0 or 1) end)
	end
	local door = site.rent.door and System.GetEntityByName(site.rent.door)
	if door then
		ML.Try("rent door", function()
			if show then
				door:Lock()
			else
				door:Unlock()
			end
		end)
	end
end

-- The doors of the rooms are locked in the level (Zhelejov), and the save keeps them as the mod left them. A door left
-- open by a rental that ended without the mod, as with an earlier version or a new life, is locked again, once per load
-- while the new character plays, unless its room is rented. Returns whether every door was there.
local function lockDoors(rental)
	local all = true
	for _, site in ipairs(ML.JOB_SITES) do
		local door = site.rent and site.rent.door and System.GetEntityByName(site.rent.door)
		if site.rent and site.rent.door and not door then
			all = false
		elseif door and not (rental and rental.site == site.key) and not door:IsLocked() then
			door:Lock()
			ML.Log("rent door locked at", site.key)
		end
	end
	return all
end

-- One way to use the bed, for the click or the hold of its prompt. No owner is checked: the bed is the character's.
-- The game still shows UseNotOwnerMessage when the bed has an owner who is not the player, as the bed of the game in
-- Zhelejov, owned by the inn; its default, ui_hud_use_item_not_owner, says "Steal food". So it says the same.
local function action(stance, message)
	return {
		bIsActive = true,
		UseMessage = message,
		UseNotOwnerMessage = message,
		bAllowNoOwner = 0,
		bCheckOwner = 0,
		esActionType = "Stance",
		sAction = stance,
	}
end

-- The smart object of a high bed. Its prompt showed and could be used, but nothing happened, with a BasicEntity
-- as the low beds have (ml_rent: enabled, not blocked, can sleep). Three ways, with ml_rent_bed: game, the bed of the
-- game itself, whose owner the prompt of the mod does not check, which works; stance, its own StanceSmartObject,
-- the class of the bed of the game, with its properties; basic, the BasicEntity of the low beds, which does nothing.
Rent.HIGH_BED_MODES = { stance = true, game = true, basic = true }
Rent.highBedMode = "game"

-- The smart object of the bed of the mod, built like the bed of the steady job (employee_bed.lua), with what the bed of
-- the game has. Returns it and whether it is the mod's own.
local function smartObject(object, high)
	local mode = high and Rent.highBedMode or "basic"
	if mode == "game" then
		local bed = object.name and System.GetEntityByName(object.name)
		if bed then
			return bed, false
		end
		ML.Log("rent: no bed of the game named", object.name, "- the mod's own")
		mode = "stance"
	end
	local properties = {
		bSaved_by_game = false,
		bSerialize = false,
		guidSmartObjectType = object.type,
		soclass_SmartObjectHelpers = object.helpers,
		sWH_AI_EntityCategory = "Bed",
		Script = { esBedTypes = object.bed },
		Bed = { esSleepQuality = object.sleep, esReadingQuality = object.reading },
	}
	if mode == "basic" then
		properties.object_Model = ML.EmployeeBed.MODEL
		properties.sSittingTagGlobal = "sittingNoTable"
		properties.fUsabilityDistance = 1.25
		properties.bInteractiveCollisionClass = true
		-- As the smart object of the game, which has no model: the mattress of the game is the body. A body of its own,
		-- even unseen, got in the way under the high bed of Zhelejov.
		properties.Physics = { bPhysicalize = false, bRigidBody = false }
	end
	local bed = System.SpawnEntity({
		class = mode == "basic" and "BasicEntity" or "StanceSmartObject",
		name = Rent.OBJECT_NAME,
		position = { x = object.x, y = object.y, z = object.z },
		properties = properties,
	})
	bed:SetAngles({ 0, 0, object.yaw })
	if mode == "basic" then
		-- The mattress of the game is already there.
		ML.Try("rent model", function() bed:DrawSlot(0, 0) end)
	end
	return bed, true
end

-- Its prompt is used as the game's: a low bed lies on a click, and a high bed (trigger.sit) sits on a click and lies on
-- a hold. Its smart object has no way to lie down from standing.
local function place(site)
	remove()
	local object, trigger = site.rent.object, site.rent.trigger
	local bed, own = smartObject(object, trigger.sit)
	local sleep = action("lying", "@ui_hud_sleep_and_save")
	local prompt = System.SpawnEntity({
		class = "BedTrigger",
		name = Rent.TRIGGER_NAME,
		position = { x = trigger.x, y = trigger.y, z = trigger.z },
		scale = { trigger.scale, trigger.scale, trigger.scale },
		properties = {
			InteractorPriorityOverride = 1,
			bSaved_by_game = false,
			bSerialize = false,
			Click = trigger.sit and action("sitting", "@ui_use_sit") or sleep,
			Hold = trigger.sit and sleep or nil,
		},
	})
	prompt:SetAngles({ 0, 0, trigger.yaw })
	prompt:CreateLink("", bed.id)
	-- The bed of the game keeps its own links.
	if own then
		bed:CreateLink("mTrigger", prompt.id)
	end
	showGame(site, false)
	placedGen = ML.gen
	ML.Log("rent bed in place at", site.key, "high", trigger.sit == true, "mode", trigger.sit and Rent.highBedMode or "basic",
		"class", bed.class)
end

-- For ml_rent_bed: how a high bed is built, stance, game or basic, and the bed of a rental again with it.
function Rent.BedMode(line)
	local mode = string.match(line or "", "(%a+)")
	if mode and Rent.HIGH_BED_MODES[mode] then
		Rent.highBedMode = mode
		if active() then
			place(siteByKey(active().site))
		end
	end
	ML.Log("rent high bed mode", Rent.highBedMode, "(stance, game or basic)")
end

-- Within rent_area metres of the bed of a site.
local function near(site)
	local position, area = player:GetWorldPos(), ML.JOB_RULES.rent_area
	local dx, dy = site.rent.object.x - position.x, site.rent.object.y - position.y
	return dx * dx + dy * dy <= area * area
end

-- The rental ends: the bed of the mod goes, and the game's comes back.
local function finish(rental, why)
	remove()
	local site = siteByKey(rental.site)
	if site and site.rent then
		showGame(site, true)
	end
	ML.Store.Set(Rent.KEY, nil)
	placedGen = nil
	ML.Log("rent ends at", rental.site, why)
end

-- Every tick: what the dialog nearby shows, and the bed of a rental in place, or gone once its time is over. Not while
-- sleeping: the morning may come in the middle of the night's sleep.
function Rent.Update()
	local site = ML.Life.IsStarted() and ML.Region() == "trosky" and ML.Try("rent site", ML.Jobs.NearestSite)
	local rental = active()
	local state, weekState, week = 0, 0, ML.JOB_RULES.rent_week_days
	if site and site.rent then
		if rental and rental.site == site.key then
			state = Rent.STATE_HAVE
		else
			state = coins() >= price(site) and Rent.STATE_PAY or Rent.STATE_SHORT
			weekState = coins() >= price(site, week) and Rent.STATE_PAY or Rent.STATE_SHORT
		end
	end
	Variables.SetGlobal(Rent.PRICE_VARIABLE, site and site.rent and price(site) / 10 or 0)
	Variables.SetGlobal(Rent.STATE_VARIABLE, state)
	Variables.SetGlobal(Rent.WEEK_PRICE_VARIABLE, site and site.rent and price(site, week) / 10 or 0)
	Variables.SetGlobal(Rent.WEEK_STATE_VARIABLE, weekState)
	if doorsGen ~= ML.gen and ML.Life.IsStarted() and ML.Region() == "trosky" and ML.Try("rent doors", lockDoors, rental) then
		doorsGen = ML.gen
	end
	if not rental or not ML.Life.IsStarted() or ML.Region() ~= "trosky" or ML.Life.sleepStart then
		return
	end
	if Calendar.GetWorldTime() >= rental.until_time then
		finish(rental, "in the morning")
		notice(Rent.OVER_TEXT)
	elseif placedGen ~= ML.gen then
		local rented = siteByKey(rental.site)
		if rented and rented.rent then
			place(rented)
		end
	end
end

ML.TickHandlers[#ML.TickHandlers + 1] = Rent.Update

-- From the dialog: pays the owner nearby and the bed is the character's until the morning, or for a week with
-- rent_week_days. One rental at a time: a new one ends the one before.
function Rent.Take(days)
	days = days or 1
	local site = ML.Try("rent site", ML.Jobs.NearestSite)
	if not site or not site.rent then
		ML.Log("ERROR rent: nobody rents a bed here")
		return
	end
	local cost = price(site, days)
	if coins() < cost then
		ML.Log("ERROR rent: the money is short", cost)
		return
	end
	local before = active()
	if before then
		finish(before, "for a new one")
	end
	ML.Try("rent pay", function()
		player.inventory:DeleteItemOfClass(ML.Life.COIN_ITEM, cost)
		Game.ShowItemsTransfer(ML.Life.COIN_ITEM, -cost)
	end)
	local hour = Calendar.GetWorldHourOfDay()
	local morning = ML.JOB_RULES.rent_until_hour
	local hours = (hour < Rent.NIGHT_ENDS and morning - hour or 24 - hour + morning) + (days - 1) * 24
	ML.Store.Set(Rent.KEY, { site = site.key, days = days, until_time = Calendar.GetWorldTime() + hours * Rent.HOUR_SECONDS })
	place(site)
	-- Until when, as the game shows a date: the words are looked up one by one.
	local day, month, year = ML.Days.Date(math.floor((hour + hours) / 24))
	notice(string.format("%s %d:00, %d @ml_month_%d %d", Rent.UNTIL_TEXT, morning, day, month, year))
	ML.Log("rent taken at", site.key, "days=", days, "price=", cost, "hours=", hours)
end

-- Where the bed rented tonight is, for its mark of the mod on the map and the compass (bed_marker.lua), while it
-- lasts.
function Rent.Place()
	local rental = ML.Life.IsStarted() and ML.Region() == "trosky" and active()
	local site = rental and siteByKey(rental.site)
	if site and site.rent and Calendar.GetWorldTime() < rental.until_time then
		return { site.rent.object.x, site.rent.object.y }
	end
end

-- Whether the character is near the rented bed while it is theirs: within rent_area metres, as the bed of the steady
-- job does with steady_area. employment.lua turns off the reactions to trespassing there, with the same Skald state. The bed of the game stays the inn's, so on waking up in Zhelejov the innkeeper threw the character out; Henry's rental is left as it is.
-- It lasts as long as the rental, not up to its hour: the rental waits for the character to wake up, and a bubble that
-- went at 10:00 in the middle of the sleep woke them up. Once the rental ends, nothing is left: the place is as
-- the game has it, and the character may sleep there without leave, as anyone.
function Rent.InBubble()
	if not ML.Life.IsStarted() or ML.Region() ~= "trosky" then
		return false
	end
	local rental = active()
	local site = rental and siteByKey(rental.site)
	return site and site.rent and near(site) or false
end

-- From the dialog: a week, for the price of rent_week_paid_nights nights.
function Rent.TakeWeek()
	Rent.Take(ML.JOB_RULES.rent_week_days)
end

-- Before a switch or ml_uninstall: the bed of the mod goes and the game's comes back. The rental stays in the Store, and
-- the new character finds the bed again on coming back, if it is still night.
function Rent.Suspend()
	local rental = active()
	remove()
	placedGen = nil
	local site = rental and siteByKey(rental.site)
	if site and site.rent then
		showGame(site, true)
	end
end

-- For ml_uninstall: the rental ends.
function Rent.Clear()
	local rental = active()
	if rental then
		finish(rental, "with ml_uninstall")
	end
end

-- Test shortcut: the rental, and the place nearby. And what there is of the bed of the place nearby: the bed of the
-- mod, the prompt of the game hidden or not, and the door locked or not.
-- Whether a bed prompt can be used now, as the game decides it when showing the prompt (BedTrigger.lua): the click and
-- the hold, with the reason when not, whether its smart object is found and taken, and whether the player can sleep.
-- For the high bed of Zhelejov, which shows its prompt and does nothing.
local function reportPrompt(label, prompt)
	if not prompt then
		ML.Log("rent", label, "prompt: none")
		return
	end
	ML.Try("rent prompt check", function()
		local properties = prompt.Properties or {}
		local click, hold = properties.Click or {}, properties.Hold or {}
		local clickOn, clickWhy = prompt:IsEnabled(player)
		local holdOn, holdWhy = prompt:IsEnabledHold(player)
		local link = prompt.GetLinkedSmartObject and prompt:GetLinkedSmartObject()
		local blocked = link and link.smartObject and XGenAIModule.IsStanceBlocked(link.smartObject.__this)
		ML.Log("rent", label, "prompt: click", click.esActionType, click.sAction, clickOn, clickWhy, "hold", hold.bIsActive,
			hold.esActionType, hold.sAction, holdOn, holdWhy, "smart object", link ~= nil, "stance blocked", blocked)
	end)
end

function Rent.Report()
	local rental = active()
	-- The rented place, even upstairs, far from its owner; else the nearest.
	local site = rental and siteByKey(rental.site) or ML.Try("rent site", ML.Jobs.NearestSite)
	ML.Log("rent:", rental and rental.site or "none", "days=", rental and rental.days or 0, "hours left=", rental and (rental.until_time - Calendar.GetWorldTime()) / Rent.HOUR_SECONDS or 0,
		"here=", site and site.rent and site.key or "nobody rents", "price=", site and site.rent and price(site) / 10 or 0)
	if site and site.rent then
		local prompt = System.GetEntityByName(site.rent.trigger.name)
		local door = site.rent.door and System.GetEntityByName(site.rent.door)
		ML.Log("rent bed of the mod:", System.GetEntityByName(Rent.OBJECT_NAME) ~= nil, System.GetEntityByName(Rent.TRIGGER_NAME) ~= nil,
			"game prompt:", prompt ~= nil, prompt and ML.Try("rent hidden", function() return prompt:IsHidden() end),
			"door locked:", door and door.bLocked, "game mark:", site.rent.mark)
		reportPrompt("mod", System.GetEntityByName(Rent.TRIGGER_NAME))
		reportPrompt("game", prompt)
		ML.Try("rent can sleep", function()
			local can, why = player.player.CanSleep()
			ML.Log("rent can sleep", can, why, "bed helpers", site.rent.object.helpers, "sit", site.rent.trigger.sit == true)
		end)
	end
	ML.BedMarker.Dump()
end

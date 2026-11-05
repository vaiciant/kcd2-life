-- =============================================================================
-- A stash of its own for each character. Each region has one master chest for the player, in its level
-- (stash[Chest/playerMasterChest_<guid>]), and every chest of the player opens it: the game's, the tent of Mercenaries
-- and the camp of The KCD2 Camping Mod. So, before a switch, the one who stops playing takes what is in it into their
-- own inventory, and once the other plays, they put back what they took before. A character who is not playing does
-- not move, so nothing is lost: it waits in their inventory. Only the master chest of the region of the switch changes.
-- Items are read with GetInventoryTable and ItemManager.GetItem, and moved by class with MoveItemOfClass, as the game
-- moves them (Utils/ItemUtils.lua).
-- =============================================================================
local ML = MedievalLife

ML.Stash = {}
local Stash = ML.Stash

Stash.NAME_PART = "playermasterchest"
Stash.KEY = "stash"
-- Whose things a master chest holds when the mod has not moved them yet: Henry's, as in the game.
Stash.HENRY = "henry"
Stash.LIFE = "life"

local function masterChest()
	for _, entity in pairs(ML.Try("stash list", function() return System.GetEntitiesByClass("Stash") end) or {}) do
		local name = ML.Try("stash name", function() return entity:GetName() end)
		if type(name) == "string" and string.find(string.lower(name), Stash.NAME_PART, 1, true) and entity.inventory then
			return entity, name
		end
	end
end

-- What an inventory holds, by class: { [class] = amount }.
local function contents(inventory)
	local found = {}
	for _, handle in pairs(ML.Try("stash table", function() return inventory:GetInventoryTable() end) or {}) do
		local item = ML.Try("stash item", function() return ItemManager.GetItem(handle) end)
		if type(item) == "table" and item.class then
			found[item.class] = (found[item.class] or 0) + (item.amount or 1)
		end
	end
	return found
end

-- Moves what the list says, and returns what moved and what did not.
local function move(from, to, list)
	local moved, left = {}, {}
	local target = ML.Try("stash target", function() return to:GetId() end)
	for class, amount in pairs(list) do
		local n = target and ML.Try("stash move", function() return from:MoveItemOfClass(target, class, amount, true) end) or 0
		if n > 0 then
			moved[class] = n
		end
		if n < amount then
			left[class] = amount - n
		end
	end
	return moved, left
end

local function count(list)
	local total = 0
	for _, amount in pairs(list or {}) do
		total = total + amount
	end
	return total
end

local function entryOf(name)
	local all = ML.Store.Get(Stash.KEY, {})
	return all, all[name] or { owner = Stash.HENRY }
end

-- Before a switch, with the one who stops playing as the player: they take what is in the master chest.
function Stash.Leave(who)
	local chest, name = masterChest()
	if not chest then
		ML.Log("stash: no master chest in this region")
		return
	end
	local all, entry = entryOf(name)
	if entry.owner ~= who then
		ML.Log("stash:", name, "holds the things of", entry.owner or "nobody", "- left as it is")
		return
	end
	local moved, left = move(chest.inventory, player.inventory, contents(chest.inventory))
	local parked = entry[who] or {}
	for class, amount in pairs(moved) do
		parked[class] = (parked[class] or 0) + amount
	end
	entry[who], entry.owner = parked, nil
	all[name] = entry
	ML.Store.Set(Stash.KEY, all)
	ML.Log("stash:", who, "takes", count(moved), "items from", name, "left in it", count(left))
end

-- Once the other one plays: they put back what they took before. A chest whose things nobody took stays as it is.
function Stash.Arrive(who)
	local chest, name = masterChest()
	if not chest then
		ML.Log("stash: no master chest in this region")
		return
	end
	local all, entry = entryOf(name)
	if entry.owner and entry.owner ~= who then
		ML.Log("stash:", name, "still holds the things of", entry.owner, "- left as it is")
		return
	end
	local moved, left = move(player.inventory, chest.inventory, entry[who] or {})
	entry[who] = next(left) and left or nil
	entry.owner = who
	all[name] = entry
	ML.Store.Set(Stash.KEY, all)
	ML.Log("stash:", who, "puts back", count(moved), "items in", name, "still carried", count(left))
end

-- Test shortcut: the master chest of this region, whose things it holds and what each one carries for it.
function Stash.Report()
	local chest, name = masterChest()
	if not chest then
		ML.Log("stash: no master chest in this region")
		return
	end
	local _, entry = entryOf(name)
	ML.Log("stash:", name, "owner=", entry.owner or "nobody", "items in it=", count(contents(chest.inventory)),
		"carried by Henry=", count(entry[Stash.HENRY]), "carried by the new character=", count(entry[Stash.LIFE]))
end

-- =============================================================================
-- Core: logging, protected calls, tick and region.
-- The retail game hides Lua errors, so every engine call goes through ML.Try.
-- Console and kcd.log output starts with "[ML]".
-- =============================================================================
local ML = MedievalLife

ML.TICK_MS = 1000
ML.TICK_LOG_EVERY = 60
ML.TickHandlers = {}
ML.gen = ML.gen or 0

function ML.Pack(...)
	return { n = select("#", ...), ... }
end

function ML.ToStr(value, depth)
	depth = depth or 0
	if type(value) ~= "table" then
		return tostring(value)
	end
	if depth > 1 then
		return "{...}"
	end
	local parts = {}
	for k, v in pairs(value) do
		parts[#parts + 1] = tostring(k) .. "=" .. ML.ToStr(v, depth + 1)
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

-- Skald talks to Lua by leaving tokens. True if there was one.
function ML.TakeToken(class)
	local amount = ML.Try("token", function() return player.inventory:GetCountOfClass(class) end) or 0
	if amount > 0 then
		ML.Try("token", function() player.inventory:DeleteItemOfClass(class, amount) end)
	end
	return amount > 0
end

function ML.Log(...)
	local args = ML.Pack(...)
	local parts = {}
	for i = 1, args.n do
		parts[#parts + 1] = ML.ToStr(args[i])
	end
	System.LogAlways("[ML] " .. table.concat(parts, " "))
end

-- Runs fn protected and logs any error with a label.
function ML.Try(label, fn, ...)
	local result = ML.Pack(pcall(fn, ...))
	if not result[1] then
		ML.Log("ERROR", label, result[2])
		return nil
	end
	return unpack(result, 2, result.n)
end

-- One tick per generation: the tick from an earlier load stops on its own. The log lets us count them.
function ML.TickStart()
	local gen = ML.gen
	local count = 0
	local function tick()
		if gen ~= ML.gen then
			ML.Log("tick stopped gen=", gen)
			return
		end
		count = count + 1
		-- After ml_uninstall the mod only keeps its dialog options hidden (uninstall.lua).
		if ML.Uninstall and ML.Uninstall.IsQuiet() then
			ML.Try("uninstalled", ML.Uninstall.Quiet)
		else
			for _, handler in ipairs(ML.TickHandlers) do
				ML.Try("tick handler", handler)
			end
		end
		if count % ML.TICK_LOG_EVERY == 0 then
			ML.Log("tick alive gen=", gen, "count=", count)
		end
		Script.SetTimer(ML.TICK_MS, tick)
	end
	Script.SetTimer(ML.TICK_MS, tick)
end

-- The location list changes with the loaded map.
function ML.Region()
	return ML.Try("region", function()
		local trosky, kuttenberg = false, false
		for _, location in pairs(RPG.GetLocations() or {}) do
			local name = tostring(location)
			trosky = trosky or string.find(name, "location_troskovice", 1, true) ~= nil
			kuttenberg = kuttenberg or string.find(name, "location_pritoky", 1, true) ~= nil
		end
		return trosky and "trosky" or (kuttenberg and "kuttenberg" or "unknown")
	end)
end

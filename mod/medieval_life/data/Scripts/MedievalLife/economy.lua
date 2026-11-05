-- =============================================================================
-- Economy mods: when one that changes the prices of the game is installed, KCD2 Life pays and charges price_factor
-- times as much, so its money keeps its worth next to the shops. The mod is known by one of its files, as other mods
-- know MCM: System.IsFileExist also sees the files inside the paks of mods. Its name, file and factor come from
-- economy.toml, through orders_data.lua. ml_economy tells the dialogs which texts with an amount to say.
--
-- =============================================================================
local ML = MedievalLife

ML.Economy = {}
local Economy = ML.Economy

Economy.VARIABLE = "ml_economy"
Economy.active = false

-- Mods cannot come or go while the game runs, so it is asked once, on the first gameplay start, and published on every
-- one: the variables of the dialogs go with the save.
function Economy.Detect()
	if Economy.checked == nil then
		local info = ML.ECONOMY
		local found = info and ML.Try("economy file", function() return System.IsFileExist(info.file) end)
		Economy.active = found == true or found == 1
		Economy.checked = true
		ML.Log("economy:", Economy.active and (info.name .. " found, money x" .. info.price_factor) or "the game's prices")
	end
	Variables.SetGlobal(Economy.VARIABLE, Economy.active and 1 or 0)
end

-- Money in tenths of a groschen, as the economy has it: to the nearest tenth, as tools/generate_orders.py rounds it for
-- the texts.
function Economy.Money(tenths)
	if not Economy.active then
		return tenths
	end
	return math.floor(tenths * ML.ECONOMY.price_factor + 0.5)
end

-- What one of the goods of an errand is worth: its price in the game, or its worth with the economy mod, from
-- economy.toml.
function Economy.Price(goods)
	if not Economy.active then
		return goods.price
	end
	return goods.price * (goods.economy or ML.ECONOMY.price_factor * 100) / 100
end

-- Whole groschen, for what the player reads: the money of the origins and the price of the book.
function Economy.WholeGroschen(tenths)
	return math.max(10, math.floor(Economy.Money(tenths) / 10 + 0.5) * 10)
end

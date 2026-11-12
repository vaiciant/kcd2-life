-- =============================================================================
-- Immersive Eating, by mathe. It plays an eating or drinking animation when the player uses an item from the
-- inventory, and reading a document is using it. It tells food by the Type of the item, and a document has a Type of
-- its own: the book of trades, Type 1, came out as a potion, with the wineskin of drinking in the hands behind the
-- open book, and a slip, Type 5, as food. The game crashed as the book opened, after some times. That mod skips the documents of the game by name, in its global table Kcd2Eating.nonFoodItems: the ones of
-- KCD2 Life go there too. Its table is made when its scripts load, so this looks at it on each load and each tick.
-- Without the mod, nothing.
-- =============================================================================
local ML = MedievalLife

ML.Eating = {}
local Eating = ML.Eating

-- The names of the documents of KCD2 Life, as in item__medieval_life.xml: the book, the slip of before and one
-- slip for each business and turn (generate_orders.py).
function Eating.Documents()
	local names = { "ml_work_book", "ml_errand_slip" }
	for key in pairs(ML.ORDER_BUSINESSES) do
		names[#names + 1] = "ml_order_slip_" .. key .. "_send"
		names[#names + 1] = "ml_order_slip_" .. key .. "_need"
	end
	return names
end

function Eating.Exclude()
	if type(Kcd2Eating) ~= "table" or type(Kcd2Eating.nonFoodItems) ~= "table" or Kcd2Eating.nonFoodItems.ml_work_book then
		return
	end
	local names = Eating.Documents()
	for _, name in ipairs(names) do
		Kcd2Eating.nonFoodItems[name] = true
	end
	ML.Log("Immersive Eating: the documents of KCD2 Life are not food,", #names)
end

ML.TickHandlers[#ML.TickHandlers + 1] = function() ML.Try("eating", Eating.Exclude) end

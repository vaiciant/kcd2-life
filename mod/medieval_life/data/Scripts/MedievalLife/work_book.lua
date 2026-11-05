-- =============================================================================
-- The book of trades: who the character is and where they have worked. Each work adds
-- to its record. A document only has the fixed pages of the table, and the game fills
-- the book with them every time it opens, so the pages are set again right after that.
-- OnBookPosition comes when a book is filled or turned, and does not say which book it
-- is: that comes from the inventory list, which tells the item in focus. Flash
-- translates each part that is a key, so Lua does not need to know the language.
-- =============================================================================
local ML = MedievalLife

ML.WorkBook = {}
local WorkBook = ML.WorkBook

WorkBook.ITEM = "21e729f9-b74a-5561-a565-ea7cba74c93b"
WorkBook.BOOK_ELEMENT = "GeneralBook"
WorkBook.LIST_ELEMENT = "ApseInventoryList"
-- 1 is no scrambled letters: anyone can read their own book. The others are as in the item table.
WorkBook.READABLE = 1
WorkBook.DOCUMENT_TYPE = 1
WorkBook.VISUAL_CATEGORY = 2
-- In tenths of a groschen.
WorkBook.PRICE = 50

-- With an economy mod, its share in whole groschen. The dialog says the price by ml_economy.
local function price()
	return ML.Economy.WholeGroschen(WorkBook.PRICE)
end

-- The age of the character when the life starts.
WorkBook.AGE_FIRST = 18
WorkBook.AGE_LAST = 20
WorkBook.HAS_VARIABLE = "ml_has_book"
WorkBook.CAN_BUY_VARIABLE = "ml_can_buy_book"

function WorkBook.Has()
	return (ML.Try("book count", function() return player.inventory:GetCountOfClass(WorkBook.ITEM) end) or 0) > 0
end

local function coins()
	return ML.Try("book coins", function() return player.inventory:GetCountOfClass(ML.Life.COIN_ITEM) end) or 0
end

local function give()
	ML.Try("book give", function()
		player.inventory:CreateItem(WorkBook.ITEM, 1, 1)
		Game.ShowItemsTransfer(WorkBook.ITEM, 1)
	end)
end

-- For a new character. The parents come from the same lists as the random names.
function WorkBook.Issue()
	local youngest = ML.Days.FIRST_MONTHS - WorkBook.AGE_FIRST * 12
	ML.Store.Set("book_born_months", youngest - math.random(0, (WorkBook.AGE_LAST - WorkBook.AGE_FIRST + 1) * 12 - 1))
	ML.Store.Set("book_father", ML.Typing.RandomName(ML.Female.MAN))
	ML.Store.Set("book_mother", ML.Typing.RandomName(ML.Female.WOMAN))
	give()
end

-- A new book has no work written in it: the old record went with the old book.
function WorkBook.Buy()
	if coins() < price() then
		return
	end
	ML.Try("book pay", function() player.inventory:DeleteItemOfClass(ML.Life.COIN_ITEM, price()) end)
	ML.Store.Set("book_jobs", {})
	give()
end

function WorkBook.Record(key, hours, steady)
	local jobs = ML.Store.Get("book_jobs", {})
	local entry
	for _, job in ipairs(jobs) do
		if job.key == key and job.steady == steady and not job.kind then
			entry = job
		end
	end
	if not entry then
		entry = { key = key, steady = steady, hours = 0 }
		jobs[#jobs + 1] = entry
	end
	entry.hours = entry.hours + hours
	ML.Store.Set("book_jobs", jobs)
end

-- An order done for a business, counted by its kind: deliver, fetch or buy.
function WorkBook.RecordOrder(key, kind)
	local jobs = ML.Store.Get("book_jobs", {})
	local entry
	for _, job in ipairs(jobs) do
		if job.key == key and job.kind == kind then
			entry = job
		end
	end
	if not entry then
		entry = { key = key, kind = kind, count = 0 }
		jobs[#jobs + 1] = entry
	end
	entry.count = entry.count + 1
	ML.Store.Set("book_jobs", jobs)
end

local function add(parts, ...)
	for _, part in ipairs({ ... }) do
		parts[#parts + 1] = part
	end
end

local function line(parts, label, value)
	add(parts, "<paragraph><accent>", label, "</accent> " .. tostring(value) .. "</paragraph>")
end

function WorkBook.Pages()
	local parts = { "<heading>", "@ml_book_title", "</heading>" }
	line(parts, "@ml_book_name", ML.Typing.Load())
	local born = ML.Store.Get("book_born_months")
	add(parts, "<paragraph><accent>", "@ml_book_born", "</accent> ", "@ml_month_name_" .. born % 12 + 1, " " .. math.floor(born / 12) .. "</paragraph>")
	line(parts, "@ml_book_father", ML.Store.Get("book_father", ""))
	line(parts, "@ml_book_mother", ML.Store.Get("book_mother", ""))
	local day, month, year = ML.Days.Date()
	add(parts, "<paragraph><accent>", "@ml_book_date", "</accent> " .. day .. " ", "@ml_month_" .. month, " " .. year .. "</paragraph>")
	line(parts, "@ml_book_days", ML.Days.Current())
	local site = ML.Employment.Site()
	add(parts, "<paragraph><accent>", "@ml_book_steady", "</accent> ", site and "@ml_book_place_" .. site.key or "@ml_book_steady_none", "</paragraph>")
	add(parts, "<newpage/><heading>", "@ml_book_work", "</heading>")
	local jobs = ML.Store.Get("book_jobs", {})
	if #jobs == 0 then
		add(parts, "<paragraph>", "@ml_book_no_work", "</paragraph>")
	end
	local places, order = {}, {}
	for _, job in ipairs(jobs) do
		if not places[job.key] then
			places[job.key] = {}
			order[#order + 1] = job.key
		end
		table.insert(places[job.key], job)
	end
	for _, key in ipairs(order) do
		add(parts, "<paragraph><accent>", "@ml_book_place_" .. key, "</accent>")
		for _, job in ipairs(places[key]) do
			if job.kind then
				add(parts, "<br/>" .. tostring(job.count) .. " ", "@ml_order_book_" .. job.kind .. (job.count == 1 and "_one" or "_many"))
			else
				add(parts, "<br/>", job.steady and "@ml_book_steady_role" or "@ml_book_role", ", " .. tostring(job.hours) .. " ", "@ml_book_hours")
			end
		end
		add(parts, "</paragraph>")
	end
	-- Space to fill. The game lets the page turn from the fixed text, whatever fits here,
	-- and with nothing to turn to it stays on the same pages for ever.
	add(parts, "<newpage/><paragraph> </paragraph>")
	return parts
end

-- Other documents with pages that Lua writes, by item class, like the slip of an errand.
-- Each one gives, for the item in focus, its pages and how readable they are.
WorkBook.documents = {}

function WorkBook.AddDocument(class, document)
	WorkBook.documents[class] = document
end

-- The id of an item as the list writes it: w020000000000aa41, and Lua userdata: 020000000000AA41.
function WorkBook.Digits(id)
	local digits = string.match(tostring(id), "%x+$")
	return digits and string.lower(digits)
end

-- The book or document in focus, and its id.
local function focusedItem()
	local ids = WorkBook.focused
	if not ids then
		return nil
	end
	for _, id in pairs(player.inventory:GetInventoryTable() or {}) do
		local item = ItemManager.GetItem(id)
		if item and (item.class == WorkBook.ITEM or WorkBook.documents[item.class]) then
			local digits = WorkBook.Digits(id)
			if digits and string.find(string.lower(ids), digits, 1, true) then
				return item.class, digits
			end
		end
	end
end

-- The book of trades is always readable. The others say how much.
local function fill(instance, class, digits)
	WorkBook.filling = true
	local document = WorkBook.documents[class]
	if document then
		UIAction.SetArray(WorkBook.BOOK_ELEMENT, instance, "Texts", document.pages(digits))
		UIAction.CallFunction(WorkBook.BOOK_ELEMENT, instance, "SetFullBook", document.readable(), document.type, document.category)
		return
	end
	UIAction.SetArray(WorkBook.BOOK_ELEMENT, instance, "Texts", WorkBook.Pages())
	UIAction.CallFunction(WorkBook.BOOK_ELEMENT, instance, "SetFullBook", WorkBook.READABLE, WorkBook.DOCUMENT_TYPE, WorkBook.VISUAL_CATEGORY)
end

function WorkBook:OnFocusChanged(elementName, instanceId, eventName, args)
	WorkBook.focused = args and args[0]
	WorkBook.turned = false
	WorkBook.filling = false
end

-- It also comes on each turn of a page, and turning back to the start must not rewrite the book.
function WorkBook:OnBookPosition(elementName, instanceId, eventName, args)
	if WorkBook.filling then
		WorkBook.filling = false
		return
	end
	if args and args[0] then
		WorkBook.turned = true
		return
	end
	if WorkBook.turned then
		WorkBook.turned = false
		return
	end
	local class, digits = ML.Try("book focus", focusedItem)
	if class then
		ML.Try("book fill", fill, instanceId, class, digits)
	end
end

function WorkBook:OnBookHidden(elementName, instanceId, eventName, args)
	WorkBook.turned = false
end

function WorkBook.Listen()
	UIAction.RegisterElementListener(WorkBook, WorkBook.LIST_ELEMENT, -1, "OnFocusChanged", "OnFocusChanged")
	UIAction.RegisterElementListener(WorkBook, WorkBook.BOOK_ELEMENT, -1, "OnBookPosition", "OnBookPosition")
	UIAction.RegisterElementListener(WorkBook, WorkBook.BOOK_ELEMENT, -1, "OnHide", "OnBookHidden")
end

-- The dialog reads them with gvar: without the book there is no work, only the offer of a new one.
local function publish()
	Variables.SetGlobal(WorkBook.HAS_VARIABLE, WorkBook.Has() and 1 or 0)
	Variables.SetGlobal(WorkBook.CAN_BUY_VARIABLE, coins() >= price() and 1 or 0)
end

ML.TickHandlers[#ML.TickHandlers + 1] = publish

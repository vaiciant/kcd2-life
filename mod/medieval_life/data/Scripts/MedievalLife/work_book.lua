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

-- Each book keeps its own record, in ML.Store by the id of its item, as the slips of the errands are: the work
-- done, the errands done, and what the character knows of each business, its hours (talked) and the days of its errands
-- (known), with the order in which the character came to each place. Lose the book, and a new one starts empty; find it
-- again, and what it had is back. What happens with no book on the character is not written anywhere.
WorkBook.RECORDS_KEY = "book_records"
-- The first book after takes the record that was kept for the character until then, once.
WorkBook.MOVED_KEY = "book_records_moved"

-- The id of a book of trades in the inventory, as WorkBook.Digits writes it, or nil. FindItem gives the id by its class,
-- with no table for each item as ItemManager.GetItem makes.
local function carriedBook()
	local id = ML.Try("book find", function() return player.inventory:FindItem(WorkBook.ITEM) end)
	return id and WorkBook.Digits(id)
end

-- The places of a record of work, in the order they came, each once.
local function placesOf(jobs)
	local places, seen = {}, {}
	for _, job in ipairs(jobs or {}) do
		if not seen[job.key] then
			seen[job.key] = true
			places[#places + 1] = job.key
		end
	end
	return places
end

-- The record of a book, the one carried without digits. Made the first time.
function WorkBook.BookRecord(digits)
	digits = digits or carriedBook()
	if not digits then
		return nil
	end
	local all = ML.Store.Get(WorkBook.RECORDS_KEY, {})
	local record = all[digits]
	if not record then
		record = { jobs = {}, talked = {}, known = {}, places = {} }
		if not ML.Store.Get(WorkBook.MOVED_KEY) then
			record.jobs = ML.Store.Get("book_jobs", {})
			record.talked = ML.Store.Get("order_talked", {})
			record.known = ML.Store.Get("order_known", {})
			record.places = ML.Store.Get("order_places") or placesOf(record.jobs)
			ML.Store.Set(WorkBook.MOVED_KEY, true)
		end
		all[digits] = record
		ML.Store.Set(WorkBook.RECORDS_KEY, all)
	end
	record.jobs, record.talked = record.jobs or {}, record.talked or {}
	record.known, record.places = record.known or {}, record.places or {}
	return record, digits
end

local function keepRecord(digits, record)
	local all = ML.Store.Get(WorkBook.RECORDS_KEY, {})
	all[digits] = record
	ML.Store.Set(WorkBook.RECORDS_KEY, all)
end

-- Changes to the record of the book carried wait in memory, and go into it once no dialog is open. The book
-- that is opened takes them too before it is shown, into its own record: no search for the book then.
local pending = {}
local pendingTalk = {}

local function onCarried(change)
	pending[#pending + 1] = change
end

function WorkBook.Flush(force, digits)
	if #pending == 0 then
		return
	end
	if not force and ML.Try("in dialog", function() return player.human:IsInDialog() end) then
		return
	end
	local changes = pending
	pending, pendingTalk = {}, {}
	local record
	record, digits = WorkBook.BookRecord(digits)
	if not record then
		return
	end
	local changed = false
	for _, change in ipairs(changes) do
		changed = change(record) or changed
	end
	if changed then
		keepRecord(digits, record)
	end
end

local function arrive(record, key)
	for _, known in ipairs(record.places) do
		if known == key then
			return
		end
	end
	record.places[#record.places + 1] = key
end

-- The character talked to the person of that business: the book shows its hours.
function WorkBook.Talked(key)
	-- Once a second during a dialog: one change waits per business.
	if pendingTalk[key] then
		return
	end
	pendingTalk[key] = true
	onCarried(function(record)
		if record.talked[key] then
			return false
		end
		record.talked[key] = true
		arrive(record, key)
		return true
	end)
end

-- The character knows the days of its errands: they asked, worked there or took one. Talking comes with it.
local function learn(record, key)
	local changed = not (record.talked[key] and record.known[key])
	record.talked[key], record.known[key] = true, true
	arrive(record, key)
	return changed
end

function WorkBook.Learn(key)
	onCarried(function(record) return learn(record, key) end)
end

-- For a new character. The parents come from the same lists as the random names.
function WorkBook.Issue()
	local youngest = ML.Days.FIRST_MONTHS - WorkBook.AGE_FIRST * 12
	ML.Store.Set("book_born_months", youngest - math.random(0, (WorkBook.AGE_LAST - WorkBook.AGE_FIRST + 1) * 12 - 1))
	ML.Store.Set("book_father", ML.Typing.RandomName(ML.Female.MAN))
	ML.Store.Set("book_mother", ML.Typing.RandomName(ML.Female.WOMAN))
	ML.Store.Set(WorkBook.MOVED_KEY, true)
	give()
end

-- A new book has no work written in it: the old record stays with the old book, if it turns up again.
function WorkBook.Buy()
	if coins() < price() then
		return
	end
	ML.Try("book pay", function() player.inventory:DeleteItemOfClass(ML.Life.COIN_ITEM, price()) end)
	ML.Store.Set(WorkBook.MOVED_KEY, true)
	give()
end

function WorkBook.Record(key, hours, steady)
	onCarried(function(record)
		local entry
		for _, job in ipairs(record.jobs) do
			if job.key == key and job.steady == steady and not job.kind then
				entry = job
			end
		end
		if not entry then
			entry = { key = key, steady = steady, hours = 0 }
			record.jobs[#record.jobs + 1] = entry
		end
		entry.hours = entry.hours + hours
		-- Working there teaches the days of its errands.
		learn(record, key)
		return true
	end)
end

-- An order done for a business, counted by its kind: deliver, fetch or buy.
function WorkBook.RecordOrder(key, kind)
	onCarried(function(record)
		local entry
		for _, job in ipairs(record.jobs) do
			if job.key == key and job.kind == kind then
				entry = job
			end
		end
		if not entry then
			entry = { key = key, kind = kind, count = 0 }
			record.jobs[#record.jobs + 1] = entry
		end
		entry.count = entry.count + 1
		learn(record, key)
		return true
	end)
end

local function add(parts, ...)
	for _, part in ipairs({ ... }) do
		parts[#parts + 1] = part
	end
end

-- Laying out the pages. The game flows the text from page to page on its own, and cuts a paragraph where a
-- page ends. So Lua lays the pages out itself, by what it estimates fits, and keeps each section, a business or a
-- place of work, whole on one page: when it would not fit, it starts a new page. A heading goes with its first
-- section. The sizes are measured on a capture of the book in the game: a line is 34 pixels, a paragraph leaves
-- one line empty after it, a heading takes 1.85 lines with its space, the first page holds its heading and seven
-- paragraphs, about 16 lines, and "Pickup or shopping: not for you yet", 35 letters, fits in one line. The length of
-- each text, in its longest language, comes from book_text_data.lua (generate_orders.py), as Flash translates the keys
-- after Lua.
WorkBook.PAGE_LINES = 16
WorkBook.LINE_LETTERS = 35
WorkBook.HEADING_LINES = 1.85
WorkBook.PARAGRAPH_GAP = 1
-- The letters of an accent are bold, and wider.
WorkBook.ACCENT_WIDTH = 1.1

-- The letters of a row: a key by its length, a tag none, the rest as it is.
local function letters(row)
	local count, accent = 0, false
	for _, part in ipairs(row) do
		local width = accent and WorkBook.ACCENT_WIDTH or 1
		if string.sub(part, 1, 1) == "@" then
			count = count + width * ((ML.BOOK_TEXT or {})[string.sub(part, 2)] or WorkBook.LINE_LETTERS)
		elseif string.sub(part, 1, 1) == "<" then
			accent = string.find(part, "^<accent>") ~= nil or (accent and not string.find(part, "^</accent>"))
			local rest = string.gsub(part, "<[^>]*>", "")
			count = count + #rest
		else
			count = count + width * #part
		end
	end
	return count
end

-- A section is a paragraph: its rows, one line each or more if they are long.
local function height(rows)
	local lines = WorkBook.PARAGRAPH_GAP
	for _, row in ipairs(rows) do
		lines = lines + math.max(1, math.ceil(letters(row) / WorkBook.LINE_LETTERS))
	end
	return lines
end

local function paragraph(parts, rows)
	add(parts, "<paragraph>")
	for n, row in ipairs(rows) do
		if n > 1 then
			add(parts, "<br/>")
		end
		add(parts, unpack(row))
	end
	add(parts, "</paragraph>")
end

local function newPage(book)
	add(book.parts, "<newpage/>")
	book.page, book.used = book.page + 1, 0
end

-- A heading with its sections. Each goes whole on a page; the heading, with the first one. With together, all of them
-- stay on the page they start on, whatever the estimate says.
local function chapter(book, heading, sections, together)
	for n, rows in ipairs(sections) do
		local need = height(rows) + (n == 1 and heading and WorkBook.HEADING_LINES or 0)
		if not together and book.used > 0 and book.used + need > WorkBook.PAGE_LINES then
			newPage(book)
		end
		if n == 1 and heading then
			add(book.parts, "<heading>", heading, "</heading>")
		end
		paragraph(book.parts, rows)
		book.used = book.used + need
	end
end

-- When a turn gives its next errand: today, tomorrow or in so many days. With one taken, its next one: the slip
-- says when the taken one is due.
local function whenParts(planned)
	if planned.days == 0 then
		return "@ml_order_book_today"
	elseif planned.days == 1 then
		return "@ml_order_book_tomorrow"
	end
	return "@ml_order_book_in", " " .. planned.days .. " ", "@ml_order_book_days"
end

-- One turn of a business in a row: its label and when, or ? if the character does not know its days, or if the
-- business does not trust them with it yet.
local function turnRow(row, label, planned, known)
	row[#row + 1] = label
	row[#row + 1] = " "
	if known and planned and not planned.blocked then
		for _, part in ipairs({ whenParts(planned) }) do
			row[#row + 1] = part
		end
	else
		row[#row + 1] = "?"
	end
	return row
end

-- The region of a place: its own in jobs.toml, or Trosky, where every place of the mod is today.
local function regionOf(key)
	for _, site in ipairs(ML.JOB_SITES) do
		if site.key == key then
			return site.region or "trosky"
		end
	end
	return "trosky"
end

-- The town of a place: the one of its errands (orders.toml), or the place alone.
local function townOf(key)
	local business = ML.ORDER_BUSINESSES and ML.ORDER_BUSINESSES[key]
	return business and business.town or key
end

-- Places by town: the towns in the order the character first came to one of their places, and in each town its
-- places in the order they came. A place new to a town already written goes after the last one of that town, however
-- many came between.
local function byTown(items, keyOf)
	local towns, order = {}, {}
	for _, item in ipairs(items) do
		local town = townOf(keyOf(item))
		if not towns[town] then
			towns[town] = {}
			order[#order + 1] = town
		end
		table.insert(towns[town], item)
	end
	local result = {}
	for _, town in ipairs(order) do
		for _, item in ipairs(towns[town]) do
			result[#result + 1] = item
		end
	end
	return result
end

-- The businesses this book knows, in the order the character came to them, by town: those they
-- talked to, and the steady job. Orders.Schedule adds those with an order taken or a debt. Only those of the region the
-- character is in: the others stay in the book. Each one is its name and two lines: its hours, if they talked to its
-- person, and delivering; then what it needs. The days show only once they asked for errands, worked there or took
-- one: ? until then. They repeat each cycle, so once known they stay known. Returns the sections and the heading.
local function errandSections(record)
	local region = ML.Try("region", ML.Region)
	local here = region == "trosky" or region == "kuttenberg"
	local worked = {}
	for _, key in ipairs(placesOf(record.jobs)) do
		worked[key] = true
	end
	local keys = {}
	for _, key in ipairs(record.places) do
		keys[#keys + 1] = key
	end
	local site = ML.Employment.Site()
	if site then
		keys[#keys + 1] = site.key
	end
	-- A mistake there must not leave the book empty: then the errands say none.
	local kept = {}
	for _, entry in ipairs(ML.Try("book errands", ML.Orders.Schedule, keys) or {}) do
		if not here or regionOf(entry.key) == region then
			kept[#kept + 1] = entry
		end
	end
	local sections = {}
	for _, entry in ipairs(byTown(kept, function(entry) return entry.key end)) do
		-- A place of the record knows both, as in a book from before.
		local known = record.known[entry.key] or worked[entry.key]
		local hours = (known or record.talked[entry.key]) and string.format("%d-%dh. ", entry.first, entry.last) or "?h. "
		local send, need
		for _, planned in ipairs(entry.turns) do
			if planned.turn == ML.Orders.SEND then
				send = planned
			else
				need = planned
			end
		end
		local rows = { { "<accent>", "@ml_book_place_" .. entry.key, "</accent>" } }
		if entry.gone then
			-- Out of the story's world, or its person dead. What is owed stays written.
			rows[2] = { "@ml_order_book_closed" }
			if entry.owed then
				rows[3] = { "@ml_order_book_owed", " " .. entry.owed .. " ", "@ml_order_slip_gr" }
			end
		elseif entry.owed then
			rows[2] = { hours, "@ml_order_book_owed", " " .. entry.owed .. " ", "@ml_order_slip_gr" }
		else
			rows[2] = turnRow({ hours }, "@ml_order_book_deliver", send, known)
			local kind = known and need and not need.blocked and need.kind
			rows[3] = turnRow({}, "@ml_order_book_" .. (kind or "need"), need, known)
		end
		sections[#sections + 1] = rows
	end
	if #sections == 0 then
		sections[1] = { { "@ml_order_book_none" } }
	end
	return sections, here and "@ml_order_book_title_" .. region or "@ml_order_book_title"
end

local function workSections(jobs)
	local places, order = {}, {}
	for _, job in ipairs(jobs) do
		if not places[job.key] then
			places[job.key] = {}
			order[#order + 1] = job.key
		end
		table.insert(places[job.key], job)
	end
	local sections = {}
	for _, key in ipairs(byTown(order, function(key) return key end)) do
		local rows = { { "<accent>", "@ml_book_place_" .. key, "</accent>" } }
		for _, job in ipairs(places[key]) do
			if job.kind then
				rows[#rows + 1] = { tostring(job.count) .. " ", "@ml_order_book_" .. job.kind .. (job.count == 1 and "_one" or "_many") }
			else
				rows[#rows + 1] = { job.steady and "@ml_book_steady_role" or "@ml_book_role", ", " .. tostring(job.hours) .. " ", "@ml_book_hours" }
			end
		end
		sections[#sections + 1] = rows
	end
	if #sections == 0 then
		sections[1] = { { "@ml_book_no_work" } }
	end
	return sections
end

-- The first page is who the character is. The second starts with the errands: when each business the character knows
-- gives its next one, and if it is today. The work done follows on the second page if it all fits there, and starts a
-- page of its own if it does not, or if the errands went on to the third page or further.
function WorkBook.Pages(digits)
	ML.Try("book flush", WorkBook.Flush, true, digits)
	local book = { parts = {}, page = 1, used = 0 }
	local record = WorkBook.BookRecord(digits) or { jobs = {}, talked = {}, known = {}, places = {} }
	local function field(label, ...)
		return { { "<accent>", label, "</accent> ", ... } }
	end
	local born = ML.Store.Get("book_born_months")
	local day, month, year = ML.Days.Date()
	local site = ML.Employment.Site()
	chapter(book, "@ml_book_title", {
		field("@ml_book_name", tostring(ML.Typing.Load() or "")),
		field("@ml_book_born", "@ml_month_name_" .. born % 12 + 1, " " .. math.floor(born / 12)),
		field("@ml_book_father", tostring(ML.Store.Get("book_father", ""))),
		field("@ml_book_mother", tostring(ML.Store.Get("book_mother", ""))),
		field("@ml_book_date", day .. " ", "@ml_month_" .. month, " " .. year),
		field("@ml_book_days", tostring(ML.Days.Current())),
		field("@ml_book_steady", site and "@ml_book_place_" .. site.key or "@ml_book_steady_none"),
	}, true)
	newPage(book)
	local jobs = record.jobs
	local errands, heading = errandSections(record)
	chapter(book, heading, errands)
	local work = workSections(jobs)
	local total = WorkBook.HEADING_LINES
	for _, rows in ipairs(work) do
		total = total + height(rows)
	end
	if book.page > 2 or (book.used > 0 and book.used + total > WorkBook.PAGE_LINES) then
		newPage(book)
	end
	chapter(book, "@ml_book_work", work)
	-- Space to fill. The game lets the page turn from the fixed text, whatever fits here,
	-- and with nothing to turn to it stays on the same pages for ever.
	add(book.parts, "<newpage/><paragraph> </paragraph>")
	return book.parts
end

-- The pages are written ahead, in the tick, and opening the book only hands them over. Writing them makes
-- hundreds of small tables and asks the engine for the locations, the factions and the people of each business: all
-- of that now happens out of the events of the interface, where the game crashed. They are written again when what
-- they show can change: the book, the day or the hour, a load or a change of region (a new generation), or a value of
-- the mod (Store.serial). And every REFRESH_TICKS seconds anyway, for what the mod does not write, as the points of
-- reputation. While a change of the book waits for a dialog to end, they are written at the opening, as before.
WorkBook.REFRESH_TICKS = 10
local prepared = {}

local function pagesKey(digits)
	local hour = ML.Try("book hour", function() return math.floor(Calendar.GetWorldHourOfDay()) end)
	return string.format("%s|%s|%s|%s|%s", digits, tostring(ML.Days.Current()), tostring(hour), ML.gen, ML.Store.serial)
end

function WorkBook.Prepare()
	if #pending > 0 or not ML.Life.IsStarted() then
		return
	end
	local digits = carriedBook()
	if not digits then
		prepared = {}
		return
	end
	local key = pagesKey(digits)
	prepared.ticks = (prepared.ticks or 0) + 1
	if prepared.key == key and prepared.ticks < WorkBook.REFRESH_TICKS then
		return
	end
	local parts = WorkBook.Pages(digits)
	-- Writing them can write the record of a new book: the key is taken again after it.
	prepared = { digits = digits, key = pagesKey(digits), parts = parts, ticks = 0 }
end

-- The digits of the book whose pages are ready, or nil.
function WorkBook.ReadyDigits()
	return prepared.parts and prepared.digits
end

function WorkBook.PagesFor(digits)
	WorkBook.ready = #pending == 0 and prepared.parts and prepared.digits == digits and prepared.key == pagesKey(digits)
	if WorkBook.ready then
		return prepared.parts
	end
	return WorkBook.Pages(digits)
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

-- The book or document in focus, and its id. It runs for every book that opens, of the game too: only the item in focus
-- is read with ItemManager.GetItem, not each one of the inventory, to do as little as it can while the book opens.
local function focusedItem(ids)
	if not ids then
		return nil
	end
	ids = string.lower(ids)
	-- The book whose pages are ready, with no list and no GetItem.
	local ready = WorkBook.ReadyDigits()
	if ready and string.find(ids, ready, 1, true) then
		return WorkBook.ITEM, ready
	end
	for _, id in pairs(player.inventory:GetInventoryTable() or {}) do
		local digits = WorkBook.Digits(id)
		if digits and string.find(ids, digits, 1, true) then
			local item = ItemManager.GetItem(id)
			if item and (item.class == WorkBook.ITEM or WorkBook.documents[item.class]) then
				return item.class, digits
			end
		end
	end
end

-- Once a game: that FindItem gives the same id as the list of the inventory, or the work would go to another record.
local function checkFound(digits)
	if WorkBook.checked == ML.gen then
		return
	end
	WorkBook.checked = ML.gen
	local found = carriedBook()
	if (ML.Try("book count", function() return player.inventory:GetCountOfClass(WorkBook.ITEM) end) or 0) == 1 then
		ML.Log("book: found by class", found, "in focus", digits, found == digits and "same" or "DIFFERENT")
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
	UIAction.SetArray(WorkBook.BOOK_ELEMENT, instance, "Texts", WorkBook.PagesFor(digits))
	UIAction.CallFunction(WorkBook.BOOK_ELEMENT, instance, "SetFullBook", WorkBook.READABLE, WorkBook.DOCUMENT_TYPE, WorkBook.VISUAL_CATEGORY)
end

function WorkBook:OnFocusChanged(elementName, instanceId, eventName, args)
	WorkBook.focused = args and args[0]
	WorkBook.turned = false
	WorkBook.filling = false
end

-- The pages are written a moment after the event, from a timer. Written inside it, SetFullBook called
-- OnBookPosition again before the event of the game was over, every time: a call inside another, in the code of the
-- interface. The game crashed at a book three times in a row just after the mod had written it, and the first crash
-- at a book was the engine finding a script table released twice. The page is blank for that moment: the table
-- only has ml_book_blank.
WorkBook.FILL_DELAY_MS = 1

local function fillLater(instance)
	-- The item in focus when the book opened, whatever the list says a moment later.
	local ids, token = WorkBook.focused, {}
	WorkBook.waiting, WorkBook.waitingInstance = token, instance
	Script.SetTimer(WorkBook.FILL_DELAY_MS, function()
		-- Closed in the meantime.
		if WorkBook.waiting ~= token then
			return
		end
		WorkBook.waiting = nil
		-- Any book of the game comes here too, and is left as it is. The log says so, to tell the crashes apart.
		local class, digits = ML.Try("book focus", focusedItem, ids)
		if not class then
			ML.Log("book opens: one of the game")
			return
		end
		-- The two lines around the pages tell, after a crash, if it came while the mod wrote them.
		ML.Log("book opens", class == WorkBook.ITEM and "trades" or "document", digits)
		if class == WorkBook.ITEM then
			ML.Try("book check", checkFound, digits)
		end
		WorkBook.ready = nil
		ML.Try("book fill", fill, instance, class, digits)
		ML.Log("book written", WorkBook.ready and "ready" or "made now", WorkBook.filling and "with no position event yet" or "")
	end)
end

-- It also comes on each turn of a page, and turning back to the start must not rewrite the book.
function WorkBook:OnBookPosition(elementName, instanceId, eventName, args)
	-- The one that SetFullBook sends when the mod has written the pages.
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
	-- Nothing else in the event: not even reading the inventory.
	ML.Try("book timer", fillLater, instanceId)
end

-- The book closes. The game names three events for an element that goes (WHGame.dll): OnHide, OnUnload and
-- OnInstanceDestroyed, and only OnHide was heard until 0.1.27. Opened and closed fast, the game stopped with "Access to
-- deleted script object": the pages must not be written to a book that is gone. Another instance
-- that goes does not stop the one waiting. The log says once a game which event closes it.
WorkBook.CLOSE_EVENTS = { "OnHide", "OnUnload", "OnInstanceDestroyed" }
local closedBy = {}

function WorkBook:OnBookClosed(elementName, instanceId, eventName, args)
	WorkBook.turned = false
	local number = tonumber(instanceId)
	local mine = number == nil or number < 0 or number == tonumber(WorkBook.waitingInstance)
	if WorkBook.waiting and mine then
		WorkBook.waiting = nil
		ML.Log("book: closed before it was written,", eventName)
	end
	if closedBy[tostring(eventName)] ~= ML.gen then
		closedBy[tostring(eventName)] = ML.gen
		ML.Log("book: closed by", eventName, "instance", instanceId)
	end
end

function WorkBook.Listen()
	UIAction.RegisterElementListener(WorkBook, WorkBook.LIST_ELEMENT, -1, "OnFocusChanged", "OnFocusChanged")
	UIAction.RegisterElementListener(WorkBook, WorkBook.BOOK_ELEMENT, -1, "OnBookPosition", "OnBookPosition")
	for _, event in ipairs(WorkBook.CLOSE_EVENTS) do
		UIAction.RegisterElementListener(WorkBook, WorkBook.BOOK_ELEMENT, -1, event, "OnBookClosed")
	end
end

-- The dialog reads them with gvar: without the book there is no work, only the offer of a new one.
local function publish()
	Variables.SetGlobal(WorkBook.HAS_VARIABLE, WorkBook.Has() and 1 or 0)
	Variables.SetGlobal(WorkBook.CAN_BUY_VARIABLE, coins() >= price() and 1 or 0)
end

ML.TickHandlers[#ML.TickHandlers + 1] = publish
ML.TickHandlers[#ML.TickHandlers + 1] = function() ML.Try("book flush", WorkBook.Flush) end
ML.TickHandlers[#ML.TickHandlers + 1] = function() ML.Try("book prepare", WorkBook.Prepare) end

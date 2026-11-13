-- =============================================================================
-- Orders of the businesses (F6). A business has two turns, each with its
-- own question in the dialog: what it sends, taken to another business, and what it
-- needs, fetched from another business or bought. Each turn draws a day from 1 to 7, on its
-- own, and asks on that day, that day + 7, + 14... of the life, so two can ask the same day. The draw comes from the day the life started, so it comes out the same anywhere and
-- is not kept. What it needs asks for trust: deliveries and pickups done for that business. The order lasts that day: if nobody takes it, someone else did. A taken
-- order has 12 hours. After that the business loses points and the character owes what the
-- goods are worth, or the money to buy them, and that business gives nothing more until it is
-- paid. The journal has one quest per business, moved with tokens, and the dialog reads the
-- variables below for the nearest employer (ml_order_dialog.xml).
-- The settings change the pay, the 12 hours, the 7 days, the trust and points asked, the points lost and how many
-- unpaid errands go to the guard (settings.lua).
-- =============================================================================
local ML = MedievalLife

ML.Orders = {}
local Orders = ML.Orders

-- The two turns. Each has its state, offer and wait in the dialog: ml_send_* and ml_need_*.
Orders.SEND = "send"
Orders.NEED = "need"
Orders.BRING_VARIABLE = "ml_order_bring"
-- For the order to hand over here: 2 with all that was bought, 1 with all of the rest, 0 if something is missing. The
-- business answers by it.
Orders.HAS_GOODS_VARIABLE = "ml_order_has_goods"
Orders.PICKUP_VARIABLE = "ml_order_pickup"
-- 1 while the nearest business waits for something bought: it can say again what.
Orders.REMIND_VARIABLE = "ml_order_remind"
Orders.CAN_PAY_VARIABLE = "ml_order_can_pay"
-- The casual work reads it too: owing a business, it gives no work.
Orders.OWED_VARIABLE = "ml_order_owed"
-- The debt in groschen, for the line that says it, or 0 if no line has that amount.
Orders.DEBT_VARIABLE = "ml_order_debt"
Orders.STATE_NONE = 0
Orders.STATE_OFFER = 1
Orders.STATE_ACTIVE = 2
Orders.STATE_DEBT = 3
Orders.STATE_WAIT = 4
-- What it needs, when it does not trust the character enough yet.
Orders.STATE_UNTRUSTED = 5
-- Too few points of the panel with that business for that kind.
Orders.STATE_LOW_POINTS = 6
-- Not trusted, after an order of it ran out: the trust has to be earned back.
Orders.STATE_LOST_TRUST = 7
-- Out of the working hours of the business, and too late to get to the place to go before it closes.
Orders.STATE_CLOSED = 8
Orders.STATE_LATE = 9
-- 1 while the business near the player is in its working hours: only then it takes in or hands over.
Orders.OPEN_VARIABLE = "ml_order_open"
-- The taken orders with the world time, the goods and the amount, the day each turn last gave
-- one, and what is owed to each business, in tenths of a groschen. Taken orders and days go by
-- turn: the key of the business for what it sends, and the key with _need for what it needs.
Orders.ACTIVE_KEY = "order_active"
Orders.LAST_KEY = "order_last"
Orders.DEBTS_KEY = "order_debts"
Orders.FORCED_KEY = "order_forced"
-- For each business, the deliveries and pickups done for it and its orders that ran out.
Orders.TRUST_KEY = "order_trust"
-- Past this, more orders run out do not raise what is needed: the numbers would leave 2^24.
Orders.TRUST_FAILS_COUNTED = 16
Orders.NEED_SUFFIX = "_need"
Orders.FAILED_TEXT = "@ml_order_failed"
Orders.FAILED_BUY_TEXT = "@ml_order_failed_buy"
Orders.FAILED_LOST_TEXT = "@ml_order_failed_lost"
Orders.CALLED_OFF_TEXT = "@ml_order_called_off"
Orders.OWE_TEXT = "@ml_order_owe %d @ml_order_groschen"
-- What to buy: "Buy cheap wine (12)". The name of the goods is a text of the generator.
Orders.BUY_TEXT = "@ml_order_buy @%s (%d)"
-- What is still missing to hand over an order: "Still missing: work axe (2)".
Orders.MISSING_TEXT = "@ml_order_still_missing @%s (%d)"
Orders.TEXT_SECONDS = 6
Orders.HOUR_SECONDS = 3600
-- The numbers of this Lua are single floats: the random numbers stay under 2^24 to be exact.
Orders.SEED_RANGE = 65521
Orders.SEED_STEP = 75
-- With the step alone, the draws are a straight line, and the days of two businesses follow each
-- other. A square breaks it, and 4000 squared stays under 2^24.
Orders.MIX_RANGE = 4000
Orders.MIX_ROUNDS = 3
Orders.KEY_STEP = 31
-- The first day of the business and each new order move the destination: 5 and 12 have no common
-- factor, so a business goes through the 12 others before repeating one.
Orders.PLACE_STEP = 3
Orders.ORDER_STEP = 5

local byId = {}
for _, order in ipairs(ML.ORDERS) do
	byId[order.id] = order
end

-- What the settings change.
-- Days between two orders of a turn: days_between, or the setting.
function Orders.Every()
	return ML.Settings.Get("order_days")
end

-- Hours of the working day of the place an order ends at, to do it.
function Orders.DeadlineHours()
	return ML.Settings.Get("order_deadline")
end

-- What an order pays, in whole tenths of a groschen: with an economy mod, its pay, and the setting on top.
function Orders.Pay(tenths)
	return math.floor(ML.Economy.Money(tenths * ML.Settings.Factor("order_pay")) + 0.5)
end

-- The points of the panel that a kind asks for, with the setting.
local function points(minimum)
	return math.floor(minimum * ML.Settings.Factor("order_reputation") + 0.5)
end

local function siteByKey(key)
	for _, site in ipairs(ML.JOB_SITES) do
		if site.key == key then
			return site
		end
	end
end

-- Whether the other place of an order, where a delivery goes or a pickup is fetched from, is open (ML.Jobs.Open): Henry's
-- story has it in the world, as for the work there (story.lua, jobs.toml requires), so Trosky castle while it is closed,
-- or Semine's manor without its people, gets no errand; and its person is alive. Shopping has no other
-- place.
local function reachable(id, region)
	local order = byId[id]
	local place = order and (order.kind == "deliver" and order.to or order.kind == "fetch" and order.from)
	local site = place and siteByKey(place)
	return not site or ML.Jobs.Open(site, region)
end

-- One of a list of orders, by the seed, among those whose other place is open. With every place open, the same one as
-- before.
local function pick(list, seed)
	local open, region = {}, ML.Region()
	for _, id in ipairs(list) do
		if reachable(id, region) then
			open[#open + 1] = id
		end
	end
	return open[1] and open[seed % #open + 1]
end

local function nextRandom(seed)
	return (seed * Orders.SEED_STEP) % (Orders.SEED_RANGE + 16)
end

-- From the world time, so the draws do not touch the random numbers of the game.
local function worldSeed()
	return math.floor(Calendar.GetWorldTime()) % Orders.SEED_RANGE + 1
end

local function mix(seed)
	for _ = 1, Orders.MIX_ROUNDS do
		local low = seed % Orders.MIX_RANGE
		seed = (low * low + nextRandom(seed)) % Orders.SEED_RANGE + 1
	end
	return seed
end

-- A number of this life, from the world day it started: what comes from it comes out the same
-- in any region and after any load, without keeping it.
local function lifeSeed()
	return mix(ML.Days.LifeStart() % Orders.SEED_RANGE + 1)
end

-- Where a turn keeps its taken order and its last day. What a business sends keeps the key
-- alone, as before.
local function slotOf(key, turn)
	return turn == Orders.NEED and key .. Orders.NEED_SUFFIX or key
end

local function turnOf(order)
	return order.kind == "deliver" and Orders.SEND or Orders.NEED
end

-- The first day of a turn, from 1 to days_between, from the life and the slot: each draws on its
-- own, two can share a day, and a new business does not move the others.
-- What a business needs never asks on the day it sends something, so it never gives two orders
-- the same day: its day is drawn among the other six.
local function firstDay(slot)
	local seed = lifeSeed()
	for i = 1, #slot do
		seed = (seed * Orders.KEY_STEP + string.byte(slot, i)) % Orders.SEED_RANGE + 1
	end
	local every, sender = Orders.Every(), string.match(slot, "^(.-)" .. Orders.NEED_SUFFIX .. "$")
	if not sender then
		return mix(seed) % every + 1
	end
	local sends, day = firstDay(sender), mix(seed) % (every - 1) + 1
	return day >= sends and day + 1 or day
end

-- What a business has seen of the character: deliveries and pickups done for it, and its
-- orders that ran out. Pickups need trust_fetch deliveries, and buying, trust_buy deliveries and
-- pickups together, both times trust_factor for each order that ran out, without a limit.
local function trusted(key)
	local trust, rules = ML.Store.Get(Orders.TRUST_KEY, {})[key] or {}, ML.ORDER_RULES
	-- The setting order_trust scales all of it: at 0 everything is trusted from the start.
	local factor = rules.trust_factor ^ math.min(trust.failed or 0, Orders.TRUST_FAILS_COUNTED) * ML.Settings.Factor("order_trust")
	local delivered, fetched = trust.delivered or 0, trust.fetched or 0
	-- Or the work done for it: a steady hour counts whole, and a casual hour for casual_hours_weight.
	local worked = (trust.steady_hours or 0) + (trust.casual_hours or 0) * rules.casual_hours_weight
	return delivered >= rules.trust_fetch * factor or worked >= rules.work_fetch_hours * factor,
		delivered + fetched >= rules.trust_buy * factor or worked >= rules.work_buy_hours * factor
end

-- The hours of a paid work, for the trust of that business. jobs.lua calls it with the pay.
function Orders.AddWork(key, hours, steady)
	local all = ML.Store.Get(Orders.TRUST_KEY, {})
	local trust = all[key] or {}
	local field = steady and "steady_hours" or "casual_hours"
	trust[field] = (trust[field] or 0) + hours
	all[key] = trust
	ML.Store.Set(Orders.TRUST_KEY, all)
end

-- Each kind also asks for points of the panel with that business: rep_deliver, rep_fetch
-- and rep_buy. What it needs is fetched or bought only with both, trust and points.
local function allowed(key)
	local site, rules = siteByKey(key), ML.ORDER_RULES
	local fetch, buy = trusted(key)
	return fetch and ML.Reputation.Accepts(site, points(rules.rep_fetch)), buy and ML.Reputation.Accepts(site, points(rules.rep_buy)), fetch or buy
end

-- A force lasts until its order is taken, or until ml_order_trust: after that, the business asks
-- for trust again.
local function isForced(key, day, turn)
	local forced = ML.Store.Get(Orders.FORCED_KEY, {})
	return forced.key == key and (forced.turn or Orders.SEND) == turn and forced.day == day and not forced.used and forced
end

local function endForce()
	local forced = ML.Store.Get(Orders.FORCED_KEY, {})
	forced.used = true
	ML.Store.Set(Orders.FORCED_KEY, forced)
end

-- What a business sends goes to each of the others in turn. What it needs is fetched or bought,
-- half and half among what it trusts the character with, and the kind can be forced.
local function choose(business, key, turn, seed, kind)
	if turn == Orders.SEND then
		return pick(business.delivers, seed)
	end
	local fetch, buy = allowed(key)
	if kind then
		fetch, buy = kind == "fetch", kind == "buy"
	end
	if not fetch and not buy then
		return nil
	end
	-- A pickup whose places are all out of the world leaves shopping, if it is trusted.
	local fetches, buys = fetch and pick(business.fetches, seed), buy and pick(business.buys, seed)
	if buys and (not fetches or mix(seed) % 2 == 1) then
		return buys
	end
	return fetches or nil
end

-- The order that a turn of a business gives today, if it is its day. A forced one does not ask
-- for trust.
local function offerToday(key, day, turn)
	local business = ML.ORDER_BUSINESSES[key]
	if not business then
		return nil
	end
	local forced = isForced(key, day, turn)
	if forced then
		local seed = lifeSeed() + day + (forced.count or 0) * Orders.ORDER_STEP
		local kind = forced.kind or (turn == Orders.NEED and (mix(seed) % 2 == 1 and "buy" or "fetch")) or nil
		return choose(business, key, turn, seed, kind)
	end
	local place, every = firstDay(slotOf(key, turn)), Orders.Every()
	if day < place or (day - place) % every ~= 0 then
		return nil
	end
	local number = math.floor((day - place) / every)
	return choose(business, key, turn, lifeSeed() + place * Orders.PLACE_STEP + number * Orders.ORDER_STEP)
end

local function count(item)
	return ML.Try("order count", function() return player.inventory:GetCountOfClass(item) end) or 0
end

-- The goods of a taken order: one of what the business sells to take it somewhere, one of what it
-- needs otherwise. An order of an older version has neither which goods nor the amount: it was
-- the first of what the business sells, and the least.
local function goodsOf(taken)
	local order = byId[taken.id]
	local business = order and ML.ORDER_BUSINESSES[order.business]
	if not business then
		return order
	end
	local list = order.kind == "deliver" and business.sells or business.needs
	local goods = list[order.need or taken.goods or 1]
	return order, goods, taken.amount or goods.least
end

local function hasGoods(taken)
	local _, goods, amount = goodsOf(taken)
	return goods and count(goods.goods) >= amount
end

-- Days until the next order of a turn: 1 is tomorrow.
local function daysToNext(slot, day)
	local place, every = firstDay(slot), Orders.Every()
	if day < place then
		return place - day
	end
	local left = (place - day) % every
	return left == 0 and every or left
end

-- With an order today, its id. Waiting, the days left. Otherwise 0.
-- The working hours of a business are those of its work (jobs.toml, Jobs.Day). The hour has minutes in it.
local function isOpen(key)
	local first, last = ML.Jobs.Day(siteByKey(key))
	local hour = Calendar.GetWorldHourOfDay()
	return hour >= first and hour < last
end

-- Where the character must get to before it closes: the place a delivery goes, the place a pickup is fetched from,
-- or the business itself, to bring what was bought.
local function goesTo(order)
	if order.kind == "deliver" then
		return order.to
	elseif order.kind == "fetch" then
		return order.from
	end
	return order.business
end

local function tooLate(order)
	local _, last = ML.Jobs.Day(siteByKey(goesTo(order)))
	return Calendar.GetWorldHourOfDay() >= last - ML.ORDER_RULES.late_margin_hours
end

local function stateFor(site, day, turn)
	if ML.Store.Get(Orders.DEBTS_KEY, {})[site.key] then
		return Orders.STATE_DEBT, 0
	end
	local slot = slotOf(site.key, turn)
	if ML.Store.Get(Orders.ACTIVE_KEY, {})[slot] then
		return Orders.STATE_ACTIVE, 0
	end
	if not ML.ORDER_BUSINESSES[site.key] then
		return Orders.STATE_NONE, 0
	end
	if not isForced(site.key, day, turn) then
		if turn == Orders.SEND and not ML.Reputation.Accepts(site, points(ML.ORDER_RULES.rep_deliver)) then
			return Orders.STATE_LOW_POINTS, 0
		end
		local fetch, buy, earned = allowed(site.key)
		if turn == Orders.NEED and not fetch and not buy then
			if earned then
				return Orders.STATE_LOW_POINTS, 0
			end
			local failed = (ML.Store.Get(Orders.TRUST_KEY, {})[site.key] or {}).failed or 0
			return failed > 0 and Orders.STATE_LOST_TRUST or Orders.STATE_UNTRUSTED, 0
		end
	end
	local offer = offerToday(site.key, day, turn)
	if offer and ML.Store.Get(Orders.LAST_KEY, {})[slot] ~= day then
		if not isOpen(site.key) then
			return Orders.STATE_CLOSED, 0
		end
		-- Delivering and buying can always be taken: the deadline waits while the place is closed. A pickup
		-- needs the place it is fetched from open in time.
		if byId[offer].kind == "fetch" and tooLate(byId[offer]) then
			return Orders.STATE_LATE, 0
		end
		return Orders.STATE_OFFER, offer
	end
	return Orders.STATE_WAIT, daysToNext(slot, day)
end

-- What is owed to a business, in tenths of a groschen, or nil. Work is not given either.
function Orders.Owed(site)
	return site and ML.Store.Get(Orders.DEBTS_KEY, {})[site.key]
end

-- Where a taken order ends: at the other business when it is taken there, at its own otherwise.
local function endsAt(order)
	return order.kind == "deliver" and order.to or order.business
end

-- When an order runs out: deadline_hours of the working hours of the place it ends at. The clock stops while
-- that place is closed, so an order taken late in the day goes on the next morning. It walks the hours from the
-- hour of the day now, and needs no calendar.
local function dueTime(order)
	local first, last = ML.Jobs.Day(siteByKey(endsAt(order)))
	local hour, left, elapsed = Calendar.GetWorldHourOfDay(), Orders.DeadlineHours(), 0
	-- Up to three steps a day: with the longest setting, 72 hours, and a short working day, many days.
	for _ = 1, 100 do
		if hour < first then
			elapsed, hour = elapsed + first - hour, first
		elseif hour >= last then
			elapsed, hour = elapsed + 24 - hour + first, first
		elseif left <= last - hour then
			return Calendar.GetWorldTime() + (elapsed + left) * Orders.HOUR_SECONDS
		else
			elapsed, left, hour = elapsed + last - hour, left - (last - hour), last
		end
	end
	return Calendar.GetWorldTime() + Orders.DeadlineHours() * Orders.HOUR_SECONDS
end

-- An order taken before this version has no due time: then it is the hours of the clock, as it was.
local function dueOf(taken)
	return taken.due or taken.taken + ML.ORDER_RULES.deadline_hours * Orders.HOUR_SECONDS
end

-- For the book of trades: when each turn of a business gives its next order, and what it is. One of:
--   { days = 0, kind, from = hour or nil }  today, until it closes, or from that hour if it has not opened yet
--   { days = n, kind }                      in n days, 1 tomorrow; with one taken, its next one, as the slip says the rest
--   { blocked = true }                      too few points, or not trusted for pickups and shopping: the book says ?
-- A business that is owed gives no order at all: Schedule says so for the whole business.
local function kindOn(key, day, turn)
	local id = offerToday(key, day, turn)
	return id and byId[id] and byId[id].kind or (turn == Orders.SEND and "deliver" or nil)
end

local function turnSchedule(site, day, hour, turn)
	local state, value = stateFor(site, day, turn)
	local first = ML.Jobs.Day(site)
	if state == Orders.STATE_ACTIVE then
		local days = daysToNext(slotOf(site.key, turn), day)
		return { days = days, kind = kindOn(site.key, day + days, turn) }
	elseif state == Orders.STATE_OFFER then
		return { days = 0, kind = byId[value].kind }
	elseif state == Orders.STATE_CLOSED and hour < first then
		return { days = 0, kind = kindOn(site.key, day, turn), from = first }
	elseif state == Orders.STATE_CLOSED or state == Orders.STATE_LATE then
		-- Today's is gone: after closing, or too late to fetch it. The next comes a cycle later.
		local every = Orders.Every()
		return { days = every, kind = kindOn(site.key, day + every, turn) }
	elseif state == Orders.STATE_WAIT then
		return { days = value, kind = kindOn(site.key, day + value, turn) }
	elseif state == Orders.STATE_LOW_POINTS or state == Orders.STATE_UNTRUSTED or state == Orders.STATE_LOST_TRUST then
		return { blocked = true, kind = turn == Orders.SEND and "deliver" or nil }
	end
	return nil
end

-- The businesses of these keys that give orders, with their working hours, what is owed to them, in whole groschen,
-- and each turn as turnSchedule says. The ones with an order taken or a debt come in too, if they are not among them.
-- From the dialog, when the character asks the nearest business for errands: its book of trades learns its days
-- (work_book.lua).
function Orders.Asked()
	local site = ML.Try("order site", ML.Jobs.NearestSite)
	if site then
		ML.WorkBook.Learn(site.key)
	end
end

function Orders.Schedule(keys)
	local day, hour, region = ML.Days.Current(), Calendar.GetWorldHourOfDay(), ML.Region()
	local wanted, list = {}, {}
	local function want(key)
		if not wanted[key] then
			wanted[key] = true
			list[#list + 1] = key
		end
	end
	for _, key in ipairs(keys) do
		want(key)
	end
	for slot in pairs(ML.Store.Get(Orders.ACTIVE_KEY, {})) do
		want((string.gsub(slot, Orders.NEED_SUFFIX .. "$", "")))
	end
	for key in pairs(ML.Store.Get(Orders.DEBTS_KEY, {})) do
		want(key)
	end
	local result = {}
	for _, key in ipairs(list) do
		local site = siteByKey(key)
		if site and ML.ORDER_BUSINESSES[key] then
			local first, last = ML.Jobs.Day(site)
			local owed = Orders.Owed(site)
			local entry = { key = key, first = first, last = last, owed = owed and math.ceil(owed / 10), turns = {} }
			-- Out of the story's world, or with its person dead, the book says it is closed.
			entry.gone = not ML.Jobs.Open(site, region)
			if not owed and not entry.gone then
				for _, turn in ipairs({ Orders.SEND, Orders.NEED }) do
					local planned = turnSchedule(site, day, hour, turn)
					if planned then
						planned.turn = turn
						entry.turns[#entry.turns + 1] = planned
					end
				end
			end
			result[#result + 1] = entry
		end
	end
	return result
end

-- The money to buy, with the profit of the setting.
local function profit()
	return ML.Economy.Money(ML.ORDER_RULES.buy_profit * ML.Settings.Factor("order_pay"))
end

-- An order that can be handed in at this site: with the goods, and fetched ones once picked up.
local function bringable(site)
	for _, taken in pairs(ML.Store.Get(Orders.ACTIVE_KEY, {})) do
		local order = byId[taken.id]
		-- With the order, the option shows: the business says whether something is missing.
		if order and endsAt(order) == site.key and (order.kind ~= "fetch" or taken.picked) then
			return order.id, taken
		end
	end
	return 0
end

-- The order to buy that this business gave, while it is going.
local function buying(site)
	local taken = ML.Store.Get(Orders.ACTIVE_KEY, {})[slotOf(site.key, Orders.NEED)]
	local order = taken and byId[taken.id]
	return order and order.kind == "buy" and taken
end

-- An order to fetch that waits at this site.
local function pickable(site)
	for _, taken in pairs(ML.Store.Get(Orders.ACTIVE_KEY, {})) do
		local order = byId[taken.id]
		if order and order.kind == "fetch" and order.from == site.key and not taken.picked then
			return order.id
		end
	end
	return 0
end

-- The dialog has a line for each text, not for each order: a game decision with hundreds of
-- options runs the game out of stack when loading. So it reads which text
-- to say (say, bring_say and pickup_say, from the generator), and Lua knows which order it is.
local function publishTurn(turn, site, day)
	local state, value = Orders.STATE_NONE, 0
	if site then
		state, value = stateFor(site, day, turn)
	end
	Variables.SetGlobal("ml_" .. turn .. "_state", state)
	-- With an economy mod, the same offer saying its pay: the dialog has the offers of the turn again after them.
	-- With the pay changed in the settings, the dialog goes to a set of its own, in the same order, whose offers say the
	-- amount in a second line, by ml_<turn>_pay.
	local said = state == Orders.STATE_OFFER and byId[value].say or 0
	if said > 0 and ML.Economy.active and not ML.Settings.Changed("order_pay") then
		said = said + ML.ORDER_OFFERS[turn]
	end
	Variables.SetGlobal("ml_" .. turn .. "_offer", said)
	Variables.SetGlobal("ml_" .. turn .. "_wait", state == Orders.STATE_WAIT and value or 0)
	-- The day the offer would be due, 0 today, 1 tomorrow, 2 the day after, 3 later, with a longer time in the settings, and its kind: the business says it.
	local order, dueDay, kind = state == Orders.STATE_OFFER and byId[value], 0, 0
	if order then
		local hours = Calendar.GetWorldHourOfDay() + (dueTime(order) - Calendar.GetWorldTime()) / Orders.HOUR_SECONDS
		dueDay = math.min(math.floor(hours / 24), 3)
		kind = order.kind == "fetch" and 1 or order.kind == "buy" and 2 or 0
	end
	Variables.SetGlobal("ml_" .. turn .. "_due", dueDay)
	-- What it pays, in tenths: with the pay changed in the settings, the offer says it in a line of its own, one per
	-- amount.
	Variables.SetGlobal("ml_" .. turn .. "_pay", order and order.pay and Orders.Pay(order.pay) or 0)
	if turn == Orders.NEED then
		Variables.SetGlobal("ml_need_kind", kind)
	end
end

local function publish()
	local bring, pickup, canPay, said, goods = 0, 0, 0, 0, 0
	local site = ML.Life.IsStarted() and ML.Try("order site", ML.Jobs.NearestSite) or nil
	local day = ML.Days.Current()
	publishTurn(Orders.SEND, site, day)
	publishTurn(Orders.NEED, site, day)
	if site then
		local id, taken = bringable(site)
		local here, waiting = byId[id], byId[pickable(site)]
		bring, pickup = here and here.bring_say or 0, waiting and waiting.pickup_say or 0
		if here and hasGoods(taken) then
			goods = here.kind == "buy" and 2 or 1
		end
		local debt = Orders.Owed(site)
		canPay = debt and count(ML.Life.COIN_ITEM) >= debt and 1 or 0
		local groschen = debt and math.floor(debt / 10 + 0.5)
		said = groschen and ML.ORDER_DEBT_LINES[groschen] and groschen or 0
	end
	Variables.SetGlobal(Orders.DEBT_VARIABLE, said)
	Variables.SetGlobal(Orders.REMIND_VARIABLE, site and buying(site) and 1 or 0)
	Variables.SetGlobal(Orders.BRING_VARIABLE, bring)
	Variables.SetGlobal(Orders.HAS_GOODS_VARIABLE, goods)
	Variables.SetGlobal(Orders.OPEN_VARIABLE, site and isOpen(site.key) and 1 or 0)
	Variables.SetGlobal(Orders.PICKUP_VARIABLE, pickup)
	Variables.SetGlobal(Orders.CAN_PAY_VARIABLE, canPay)
	Variables.SetGlobal(Orders.OWED_VARIABLE, site and Orders.Owed(site) and 1 or 0)
end

-- CreateItem keeps the amount only for what stacks, like food or money. Of anything else, such as a horseshoe, an axe or
-- a belt, it makes one, so the rest are made one at a time, as the game does in player.lua.
local function give(item, amount)
	if amount <= 0 then
		return
	end
	ML.Try("order give", function()
		local before = count(item)
		player.inventory:CreateItem(item, 1, amount)
		for _ = count(item) - before + 1, amount do
			player.inventory:CreateItem(item, 1, 1)
		end
		Game.ShowItemsTransfer(item, amount)
	end)
end

-- The money to buy the goods, in whole groschen: what a shop asks with 50 points, buy_percent of
-- what they are worth or the percent of those goods, when shops sell them dearer, and buy_profit
-- on top, so there is always something left. With an economy mod, what the goods are worth with it, and
-- its profit.
local function moneyFor(goods, amount)
	local rules = ML.ORDER_RULES
	return math.ceil((ML.Economy.Price(goods) * amount * (goods.percent or rules.buy_percent) / 100 + profit()) / 10) * 10
end

-- With the notice of the game: parted with.
-- What does not stack may go one at a time too: it keeps taking one while some are left to take and each try takes one.
local function take(item, amount)
	ML.Try("order take", function()
		local goal = count(item) - amount
		player.inventory:DeleteItemOfClass(item, amount)
		local left = count(item)
		while left > goal do
			player.inventory:DeleteItemOfClass(item, 1)
			local now = count(item)
			if now >= left then
				break
			end
			left = now
		end
		Game.ShowItemsTransfer(item, -amount)
	end)
end

local function notice(text)
	ML.Try("order notice", function() Game.SendInfoText(text, false, nil, Orders.TEXT_SECONDS) end)
end

-- The slip of an errand: a paper in the inventory, worth nothing, with what to do, for
-- whom and by when, written by Lua as the book of trades (work_book.lua shows it). It comes with
-- the order and goes when it is done. If the order runs out it stays, with what is owed, until
-- that is paid. Each slip is kept by the id of its item.
Orders.SLIP_ITEM = "de2861c1-d19b-504e-a669-662ffd3dcdd2"
Orders.SLIPS_KEY = "order_slips"
-- Below this Scholarship its letters come scrambled, as in the documents of the game.
Orders.SLIP_SCHOLARSHIP = 3
-- A letter, as kovaniNaKovarne_forgottenContract of the game.
Orders.SLIP_TYPE = 5
Orders.SLIP_CATEGORY = 1

-- Creates an item in the inventory, as the rest of the mod does, and gives its id: the one of that
-- class that was not there before, or else any of that class, when it joined a pile. With
-- ItemManager.CreateItem the slip gave a Lua error.
local function createItem(class, amount)
	local before, found = {}, nil
	for _, id in pairs(player.inventory:GetInventoryTable() or {}) do
		before[ML.WorkBook.Digits(id)] = true
	end
	player.inventory:CreateItem(class, 1, amount)
	for _, id in pairs(player.inventory:GetInventoryTable() or {}) do
		local item = ItemManager.GetItem(id)
		if item and item.class == class then
			if not before[ML.WorkBook.Digits(id)] then
				return id
			end
			found = found or id
		end
	end
	return found
end

local function dropSlip(digits)
	if not digits then
		return
	end
	local slips = ML.Store.Get(Orders.SLIPS_KEY, {})
	local class = slips[digits] and slips[digits].class or Orders.SLIP_ITEM
	ML.Try("order slip", function()
		for _, id in pairs(player.inventory:GetInventoryTable() or {}) do
			if ML.WorkBook.Digits(id) == digits then
				player.inventory:DeleteItem(id, -1)
				Game.ShowItemsTransfer(class, -1)
			end
		end
	end)
	slips[digits] = nil
	ML.Store.Set(Orders.SLIPS_KEY, slips)
end

-- Each business and turn has its own slip, with its name, so that two slips never pile up and each
-- one can be read. A slip of the same kind that is still there, given to the guard, goes first.
local function giveSlip(record, class)
	for digits, old in pairs(ML.Store.Get(Orders.SLIPS_KEY, {})) do
		if old.class == class then
			dropSlip(digits)
		end
	end
	local digits
	ML.Try("order slip", function()
		local id = createItem(class, 1)
		digits = id and ML.WorkBook.Digits(id)
		Game.ShowItemsTransfer(class, 1)
	end)
	if digits then
		record.class = class
		local slips = ML.Store.Get(Orders.SLIPS_KEY, {})
		slips[digits] = record
		ML.Store.Set(Orders.SLIPS_KEY, slips)
	end
	return digits
end

-- A business and its town, as the slip writes them: "Lawrence the innkeeper, Zhelejov".
local function place(parts, key)
	local business = ML.ORDER_BUSINESSES[key]
	parts[#parts + 1] = "@" .. business.name
	parts[#parts + 1] = ", "
	parts[#parts + 1] = "@ml_order_town_" .. business.town
	-- Its working hours: a delivery or a pickup has to reach both places while they are open.
	local first, last = ML.Jobs.Day(siteByKey(key))
	parts[#parts + 1] = string.format(" (%d-%dh)", first, last)
end

local function slipLine(parts, label, ...)
	parts[#parts + 1] = "<paragraph><accent>"
	parts[#parts + 1] = label
	parts[#parts + 1] = "</accent> "
	for _, part in ipairs({ ... }) do
		parts[#parts + 1] = part
	end
	parts[#parts + 1] = "</paragraph>"
end

-- The left page has who gives it, when it runs out and the pay. The right one, what goes and where,
-- or the money to buy, and the signature of the business at the bottom right. Documents of
-- the game align and size text the same way (text_ui_items.xml: p align, font size).
Orders.SIGNATURE = "<br/><br/><br/><p align='right'><font size='30'><i>"
Orders.SIGNATURE_END = "</i></font></p>"

local function slipPages(digits)
	local parts = { "<heading>", "@ml_order_slip_title", "</heading>" }
	local record = ML.Store.Get(Orders.SLIPS_KEY, {})[digits]
	local order = record and byId[record.id]
	if not order then
		return parts
	end
	local _, goods, amount = goodsOf(record)
	local first, right = {}, {}
	place(first, order.business)
	slipLine(parts, "@ml_order_slip_from", unpack(first))
	if order.kind == "buy" then
		slipLine(right, "@ml_order_slip_buy", tostring(amount) .. " ", "@" .. goods.name)
		slipLine(right, "@ml_order_slip_money", string.format("%g ", (record.money or 0) / 10), "@ml_order_slip_gr")
	else
		slipLine(right, "@ml_order_slip_goods", tostring(amount) .. " ", "@" .. goods.ui)
		local where = {}
		place(where, order.kind == "deliver" and order.to or order.from)
		slipLine(right, order.kind == "deliver" and "@ml_order_slip_deliver" or "@ml_order_slip_fetch", unpack(where))
		if order.kind == "fetch" then
			slipLine(right, "@ml_order_slip_back", unpack(first))
		end
	end
	right[#right + 1] = Orders.SIGNATURE
	right[#right + 1] = "@" .. ML.ORDER_BUSINESSES[order.business].name
	right[#right + 1] = Orders.SIGNATURE_END
	if record.declared then
		slipLine(parts, "@ml_order_slip_reported", "@ml_order_town_" .. record.declared)
	elseif record.debt then
		slipLine(parts, "@ml_order_slip_failed", string.format("%g ", record.debt / 10), "@ml_order_slip_gr")
	else
		-- The hour it runs out, from the hour of now: it can be tomorrow or, counting only working hours, the day after.
		-- With a longer time in the settings, in so many days.
		local left = ((record.due or record.taken + ML.ORDER_RULES.deadline_hours * Orders.HOUR_SECONDS) - Calendar.GetWorldTime()) / Orders.HOUR_SECONDS
		local due = Calendar.GetWorldHourOfDay() + math.max(left, 0)
		local days = math.floor(due / 24)
		due = due % 24
		local at = string.format(" %02d:%02d", math.floor(due), math.floor(due % 1 * 60))
		-- The book translates each part with @ as a whole key, so the number goes in a part of its own.
		if days >= 3 then
			slipLine(parts, "@ml_order_slip_due", "@ml_order_slip_in", " " .. days .. " ", "@ml_order_slip_days_at", at)
		else
			slipLine(parts, "@ml_order_slip_due", days == 2 and "@ml_order_slip_day_after" or days == 1 and "@ml_order_slip_tomorrow" or "@ml_order_slip_today", at)
		end
	end
	if order.kind ~= "buy" then
		-- What it pays now: the settings may have changed since it was taken.
		slipLine(parts, "@ml_order_slip_pay", string.format("%g ", Orders.Pay(order.pay) / 10), "@ml_order_slip_gr")
	end
	parts[#parts + 1] = "<newpage/>"
	for _, part in ipairs(right) do
		parts[#parts + 1] = part
	end
	return parts
end

local function slipReadable()
	local level = ML.Try("slip scholarship", function() return player.soul:GetSkillLevel("scholarship") end) or 0
	return level >= Orders.SLIP_SCHOLARSHIP and 1 or 0
end

local slipDocument = { pages = slipPages, readable = slipReadable, type = Orders.SLIP_TYPE, category = Orders.SLIP_CATEGORY }
ML.WorkBook.AddDocument(Orders.SLIP_ITEM, slipDocument)
for _, business in pairs(ML.ORDER_BUSINESSES) do
	ML.WorkBook.AddDocument(business.slips.send, slipDocument)
	ML.WorkBook.AddDocument(business.slips.need, slipDocument)
end

-- The tokens that end an order are shared by all the orders of its business: Skald lets each one
-- through only to the objective that is active. When the business has no
-- order going, close ends its quest, a moment later, once the objective has taken its token.
local function tell(order, outcome)
	local tokens = ML.ORDER_BUSINESSES[order.business].tokens
	local turn = order.kind == "deliver" and "send_" or "need_"
	ML.Life.SendToken(tokens[(outcome == "done" or outcome == "failed") and turn .. outcome or outcome])
	if outcome == "picked" then
		return
	end
	for _, taken in pairs(ML.Store.Get(Orders.ACTIVE_KEY, {})) do
		local other = byId[taken.id]
		if other and other.business == order.business then
			return
		end
	end
	Script.SetTimer(ML.Life.TOKEN_MS * 1.5, function() ML.Life.SendToken(tokens.close) end)
end

-- Takes the order of the day of a turn at the nearest business: TakeSend and TakeNeed, from the dialog.
local function accept(turn)
	local site, day = ML.Try("order site", ML.Jobs.NearestSite), ML.Days.Current()
	local state, id = Orders.STATE_NONE, 0
	if site then
		ML.WorkBook.Learn(site.key)
		state, id = stateFor(site, day, turn)
	end
	local order = byId[id]
	if state ~= Orders.STATE_OFFER or not order then
		ML.Log("ERROR order accept", turn, site and site.key)
		return
	end
	-- The slip says the hours of the other place too: the book knows them from now on.
	if order.kind == "deliver" or order.kind == "fetch" then
		ML.WorkBook.Talked(order.kind == "deliver" and order.to or order.from)
	end
	-- Which goods and how many: one of what the business sells or needs, and between its least
	-- and its most. To buy, the order says which.
	local business = ML.ORDER_BUSINESSES[order.business]
	local list = order.kind == "deliver" and business.sells or business.needs
	local seed = nextRandom(worldSeed())
	local index = order.need or seed % #list + 1
	local goods = list[index]
	seed = nextRandom(seed)
	local amount = goods.least + seed % (goods.most - goods.least + 1)
	local taken = { id = id, taken = Calendar.GetWorldTime(), due = dueTime(order), goods = index, amount = amount }
	if order.kind == "buy" then
		taken.money = moneyFor(goods, amount)
	end
	if isForced(order.business, day, turn) then
		endForce()
	end
	taken.slip = giveSlip({ id = id, goods = index, amount = amount, money = taken.money, taken = taken.taken, due = taken.due },
		business.slips[turnOf(order)])
	local slot = slotOf(order.business, turnOf(order))
	local active, last = ML.Store.Get(Orders.ACTIVE_KEY, {}), ML.Store.Get(Orders.LAST_KEY, {})
	active[slot] = taken
	last[slot] = day
	ML.Store.Set(Orders.ACTIVE_KEY, active)
	ML.Store.Set(Orders.LAST_KEY, last)
	if order.kind == "deliver" then
		give(goods.goods, amount)
	elseif order.kind == "buy" then
		give(ML.Life.COIN_ITEM, taken.money)
		notice(string.format(Orders.BUY_TEXT, goods.name, amount))
	end
	ML.Life.SendToken(order.accept)
	ML.Log("order taken", order.business, order.kind, order.to or order.from or order.need, id, "goods=", index, "amount=", amount, "money=", taken.money, "day=", day)
end

function Orders.TakeSend()
	accept(Orders.SEND)
end

function Orders.TakeNeed()
	accept(Orders.NEED)
end

-- The business says again what to buy, with the same notice as when it was taken.
function Orders.Remind()
	local site = ML.Try("order site", ML.Jobs.NearestSite)
	local taken = site and buying(site)
	if taken then
		local _, goods, amount = goodsOf(taken)
		notice(string.format(Orders.BUY_TEXT, goods.name, amount))
	end
end

-- The other business hands over what was ordered from it.
function Orders.Pickup()
	local site = ML.Try("order site", ML.Jobs.NearestSite)
	local id = site and pickable(site) or 0
	local order = byId[id]
	local slot = order and slotOf(order.business, Orders.NEED)
	local active = ML.Store.Get(Orders.ACTIVE_KEY, {})
	local taken = slot and active[slot]
	if not taken or taken.id ~= id or taken.picked or not site or site.key ~= order.from or not isOpen(site.key) then
		ML.Log("ERROR order pickup", id, site and site.key)
		return
	end
	taken.picked = true
	ML.Store.Set(Orders.ACTIVE_KEY, active)
	local _, goods, amount = goodsOf(taken)
	give(goods.goods, amount)
	tell(order, "picked")
	ML.Log("order picked", order.business, "from", order.from, id, "amount=", amount)
end

-- Adds one to what a business has seen: delivered, fetched or failed.
local function addTrust(key, field)
	local all = ML.Store.Get(Orders.TRUST_KEY, {})
	local trust = all[key] or {}
	trust[field] = (trust[field] or 0) + 1
	all[key] = trust
	ML.Store.Set(Orders.TRUST_KEY, all)
end

-- The state is written before the pay, as in the work: a retry cannot pay twice. To buy, the pay
-- is what is left of the money.
function Orders.Deliver()
	local site = ML.Try("order site", ML.Jobs.NearestSite)
	local id = site and bringable(site) or 0
	local order = byId[id]
	local slot = order and slotOf(order.business, turnOf(order))
	local active = ML.Store.Get(Orders.ACTIVE_KEY, {})
	local taken = slot and active[slot]
	if not taken or taken.id ~= id or not site or site.key ~= endsAt(order) or (order.kind == "fetch" and not taken.picked) or not hasGoods(taken)
			or not isOpen(site.key) then
		ML.Log("ERROR order deliver", id, site and site.key)
		return
	end
	local _, goods, amount = goodsOf(taken)
	active[slot] = nil
	ML.Store.Set(Orders.ACTIVE_KEY, active)
	take(goods.goods, amount)
	dropSlip(taken.slip)
	tell(order, "done")
	give(ML.Life.COIN_ITEM, Orders.Pay(order.pay))
	local business = siteByKey(order.business)
	local before = ML.Reputation.Points(business)
	ML.Reputation.AddPoints(business, ML.ORDER_RULES.done_points)
	ML.WorkBook.RecordOrder(order.business, order.kind)
	if order.kind ~= "buy" then
		addTrust(order.business, order.kind == "deliver" and "delivered" or "fetched")
	end
	ML.Log("order done", order.business, order.kind, id, "money=", count(ML.Life.COIN_ITEM), "points", before, "->", ML.Reputation.Points(business))
end

-- For ml_uninstall: every taken order, debt, slip and note goes, with no penalty, and each business with an order
-- going closes its quest as Done.
function Orders.Clear()
	local businesses = {}
	for _, taken in pairs(ML.Store.Get(Orders.ACTIVE_KEY, {})) do
		local order = byId[taken.id]
		if order then
			businesses[order.business] = true
		end
	end
	for digits in pairs(ML.Store.Get(Orders.SLIPS_KEY, {})) do
		dropSlip(digits)
	end
	local notes = count(Orders.NOTE_ITEM)
	if notes > 0 then
		ML.Try("order notes", function() player.inventory:DeleteItemOfClass(Orders.NOTE_ITEM, notes) end)
	end
	ML.Store.Set(Orders.ACTIVE_KEY, {})
	ML.Store.Set(Orders.DEBTS_KEY, {})
	for key in pairs(businesses) do
		ML.Life.SendToken(ML.ORDER_BUSINESSES[key].tokens.close)
		ML.Log("order closed for uninstall", key)
	end
end

-- The business said that something is missing: the notice says what, and how many are still to come.
function Orders.Missing()
	local site = ML.Try("order site", ML.Jobs.NearestSite)
	local id, taken = 0, nil
	if site then
		id, taken = bringable(site)
	end
	if not taken then
		ML.Log("ERROR order missing", site and site.key)
		return
	end
	local _, goods, amount = goodsOf(taken)
	local left = amount - count(goods.goods)
	if left > 0 then
		-- What a business sends has only the game's own name of the item.
		notice(string.format(Orders.MISSING_TEXT, goods.name or goods.ui, left))
	end
	ML.Log("order missing", byId[id].business, id, "left=", left, "of", amount)
end

function Orders.PayDebt()
	local site = ML.Try("order site", ML.Jobs.NearestSite)
	local debts = ML.Store.Get(Orders.DEBTS_KEY, {})
	local debt = site and debts[site.key]
	if not debt or count(ML.Life.COIN_ITEM) < debt then
		ML.Log("ERROR order pay", site and site.key, debt)
		return
	end
	debts[site.key] = nil
	ML.Store.Set(Orders.DEBTS_KEY, debts)
	take(ML.Life.COIN_ITEM, debt)
	-- What was owed is paid: its slips go.
	for digits, record in pairs(ML.Store.Get(Orders.SLIPS_KEY, {})) do
		local owed = byId[record.id]
		if record.debt and not record.declared and owed and owed.business == site.key then
			dropSlip(digits)
		end
	end
	ML.Log("order debt paid", site.key, debt)
end

function Orders.ShowDebt()
	local debt = Orders.Owed(ML.Try("order site", ML.Jobs.NearestSite))
	if debt then
		notice(string.format(Orders.OWE_TEXT, debt / 10))
	end
end

-- A theft of errands. After crime_fails orders of a town run out and stay unpaid,
-- their slips pass to the guard of that town: the businesses forget the debts, and the guard takes
-- each slip as a theft, 50 groschen each. One more theft is of IOUs worth what was owed, and
-- they leave the inventory a moment later: the guard charges what it does not find on the
-- character ("you'll pay for them too"), so the fine is 200 groschen and the debt. IOUs that stay
-- in the inventory were only the 50. The game makes a theft as
-- on the forge of Kuttenberg (utils/crime/theft/pushstimulus_theft.xml): switch:stimulus:theft with
-- the method pick, and what was stolen as an item, which has to be one
-- (AI/crime/createTheftInformation.xml), and a different one for each theft. The guards of a town
-- far away do not take it, so it waits until the character is within crime_range of one of the
-- authorities of that town, and then all of them in the map hear it: killing one does not wipe it.
Orders.CRIMES_KEY = "order_crimes"
Orders.CRIME_MESSAGE = "switch:stimulus:theft"
Orders.NOTE_ITEM = "0ecd68ee-0f3f-507a-bde8-6e677f7e01e8"
Orders.REPORTED_TEXT = "@ml_order_reported @ml_order_town_%s"
-- The place of pick in crime_theftMethod (ai_enums.xml), if Lua has no table for it.
Orders.CRIME_METHOD_PICK = 5
-- Long enough for the guards to read the IOUs before they go (AI/crime/createTheftInformation.xml).
Orders.NOTES_GONE_MS = 5000

local function reportTheft(guards, victim, item, count)
	local methods = rawget(_G, "enum_crime_theftMethod")
	for _, guard in ipairs(guards) do
		local message = XGenAIModule.MakeTableFromType(Orders.CRIME_MESSAGE)
		message.method = methods and methods.pick or Orders.CRIME_METHOD_PICK
		message.owner = victim.this.id
		message.pivot = item
		message.information.perceivedWuid = item
		message.count = count
		message.immediate = false
		message.treatAsPersonalSource = false
		XGenAIModule.SendMessageToEntityData(guard.this.id, Orders.CRIME_MESSAGE, message)
		ML.Log("crime sent to", guard:GetName(), "victim", victim:GetName(), "count", count)
	end
end

-- The authorities of a town in the map, if the character is near one of them.
local function authoritiesNear(town)
	local found, near, here = {}, false, player:GetWorldPos()
	local range = ML.ORDER_RULES.crime_range
	for _, name in ipairs(ML.ORDER_AUTHORITIES[town] or {}) do
		local guard = System.GetEntityByName(name)
		if guard then
			found[#found + 1] = guard
			local there = guard:GetWorldPos()
			near = near or (there.x - here.x) ^ 2 + (there.y - here.y) ^ 2 <= range * range
		end
	end
	return near and found or {}
end

-- After an order of that business runs out with a debt: its slips unpaid in that town, not yet
-- given to the guard.
local function checkCrime(key)
	local town = ML.ORDER_BUSINESSES[key].town
	local slips, unpaid = ML.Store.Get(Orders.SLIPS_KEY, {}), {}
	for digits, record in pairs(slips) do
		local order = byId[record.id]
		if record.debt and not record.declared and order and ML.ORDER_BUSINESSES[order.business].town == town then
			unpaid[#unpaid + 1] = digits
		end
	end
	-- The setting order_guard, crime_fails by default: 0 is never.
	local limit = ML.Settings.Get("order_guard")
	if limit == 0 or #unpaid < limit then
		return
	end
	local debts = ML.Store.Get(Orders.DEBTS_KEY, {})
	for business in pairs(debts) do
		if ML.ORDER_BUSINESSES[business] and ML.ORDER_BUSINESSES[business].town == town then
			debts[business] = nil
		end
	end
	ML.Store.Set(Orders.DEBTS_KEY, debts)
	local debt = 0
	for _, digits in ipairs(unpaid) do
		slips[digits].declared = town
		debt = debt + slips[digits].debt
	end
	ML.Store.Set(Orders.SLIPS_KEY, slips)
	local crimes = ML.Store.Get(Orders.CRIMES_KEY, {})
	local crime = type(crimes[town]) == "table" and crimes[town] or { debt = 0 }
	crime.debt, crime.victim = crime.debt + debt, key
	crimes[town] = crime
	ML.Store.Set(Orders.CRIMES_KEY, crimes)
	notice(string.format(Orders.REPORTED_TEXT, town))
	ML.Log("order crime", town, "slips=", #unpaid)
end

-- The theft goes once the character is in its town: one for each slip given to the guard, with the
-- business that gave it as the victim.
local function reportCrimes()
	if not ML.Life.IsStarted() then
		return
	end
	local crimes = ML.Store.Get(Orders.CRIMES_KEY, {})
	for town, crime in pairs(crimes) do
		local guards = authoritiesNear(town)
		if #guards > 0 then
			local slips, told = ML.Store.Get(Orders.SLIPS_KEY, {}), 0
			for _, id in pairs(player.inventory:GetInventoryTable() or {}) do
				local record = slips[ML.WorkBook.Digits(id)]
				local order = record and byId[record.id]
				if order and record.declared == town and not record.reported then
					local site = siteByKey(order.business)
					reportTheft(guards, site and System.GetEntityByName(site.npcs[1]) or guards[1], id, 1)
					record.reported = true
					told = told + 1
				end
			end
			ML.Store.Set(Orders.SLIPS_KEY, slips)
			-- What was owed, in IOUs that go a moment later.
			local debt = type(crime) == "table" and crime.debt or 0
			local victim = type(crime) == "table" and siteByKey(crime.victim)
			local notes = debt > 0 and createItem(Orders.NOTE_ITEM, debt)
			if notes then
				reportTheft(guards, victim and System.GetEntityByName(victim.npcs[1]) or guards[1], notes, debt)
				Script.SetTimer(Orders.NOTES_GONE_MS, function()
					ML.Try("order notes", function() player.inventory:DeleteItemOfClass(Orders.NOTE_ITEM, debt) end)
				end)
			end
			crimes[town] = nil
			ML.Store.Set(Orders.CRIMES_KEY, crimes)
			ML.Log("order crime reported", town, "slips=", told, "debt=", debt, "guards=", #guards)
			return
		end
	end
end

-- The debt is what the goods are worth, in whole groschen, when the character has them: taken
-- to deliver, or picked up. To buy, it is the money. An order to fetch that was not picked up
-- costs only the points.
local function fail(slot, taken)
	local order, goods, amount = goodsOf(taken)
	local active, debts = ML.Store.Get(Orders.ACTIVE_KEY, {}), ML.Store.Get(Orders.DEBTS_KEY, {})
	active[slot] = nil
	ML.Store.Set(Orders.ACTIVE_KEY, active)
	local text = Orders.FAILED_TEXT
	if order and goods then
		local key, debt = order.business, 0
		if order.kind == "buy" then
			debt, text = taken.money or moneyFor(goods, amount), Orders.FAILED_BUY_TEXT
		elseif order.kind == "deliver" or taken.picked then
			debt = math.ceil(ML.Economy.Price(goods) * amount / 10) * 10
		else
			text = Orders.FAILED_LOST_TEXT
		end
		if debt > 0 then
			debts[key] = (debts[key] or 0) + debt
			ML.Store.Set(Orders.DEBTS_KEY, debts)
			-- The slip stays, and says what is owed.
			local slips = ML.Store.Get(Orders.SLIPS_KEY, {})
			if taken.slip and slips[taken.slip] then
				slips[taken.slip].debt = debt
				ML.Store.Set(Orders.SLIPS_KEY, slips)
			end
			checkCrime(key)
		else
			dropSlip(taken.slip)
		end
		tell(order, order.kind == "fetch" and not taken.picked and "lost" or "failed")
		addTrust(key, "failed")
		ML.Reputation.AddPoints(siteByKey(key), -ML.Settings.Get("order_fail_points"))
		ML.Log("order failed", key, order.kind, taken.id, "debt=", debts[key])
	end
	notice(text)
end

-- Where a taken order must go now: where a delivery goes, where a pickup is fetched from until it is picked, and the
-- business itself after that and to bring what was bought.
local function goingTo(order, taken)
	if order.kind == "fetch" and taken.picked then
		return order.business
	end
	return goesTo(order)
end

-- A taken order whose place lost its person, found dead, is called off: no debt, no points and no trust lost. The
-- character keeps what they carry.
local function callOff(slot, taken, order)
	local active = ML.Store.Get(Orders.ACTIVE_KEY, {})
	active[slot] = nil
	ML.Store.Set(Orders.ACTIVE_KEY, active)
	dropSlip(taken.slip)
	tell(order, "lost")
	notice(Orders.CALLED_OFF_TEXT)
	ML.Log("order called off", order.business, order.kind, taken.id, "nobody at", goingTo(order, taken))
end

local function checkDeadlines()
	if not ML.Life.IsStarted() then
		return
	end
	local now = Calendar.GetWorldTime()
	for slot, taken in pairs(ML.Store.Get(Orders.ACTIVE_KEY, {})) do
		local order = byId[taken.id]
		local site = order and siteByKey(goingTo(order, taken))
		if site and ML.Jobs.Dead(site) then
			callOff(slot, taken, order)
			return
		end
		if now >= dueOf(taken) then
			fail(slot, taken)
			return
		end
	end
end

-- Talking to the person of a business teaches its hours. The dialog of the mod talks to the nearest employer,
-- and so does this. Once a second, and only with the character of a new life, who has the book.
local function noticeTalk()
	if not ML.Life.IsStarted() or not ML.Try("in dialog", function() return player.human:IsInDialog() end) then
		return
	end
	local site = ML.Try("talk site", ML.Jobs.NearestSite)
	if site then
		ML.WorkBook.Talked(site.key)
	end
end

ML.TickHandlers[#ML.TickHandlers + 1] = checkDeadlines
ML.TickHandlers[#ML.TickHandlers + 1] = noticeTalk
ML.TickHandlers[#ML.TickHandlers + 1] = function() ML.Try("order crimes", reportCrimes) end
ML.TickHandlers[#ML.TickHandlers + 1] = publish

-- Test shortcuts, to remove before publishing.
-- ml_order_force <business> [deliver|fetch|buy]: that turn gives its order today. Each force moves
-- to the next order, so forcing again the same day gives another one.
function Orders.Force(line)
	local key, kind = string.match(line or "", "^(%S+)%s*(%S*)")
	if not key or not ML.ORDER_BUSINESSES[key] or (kind ~= "" and kind ~= "deliver" and kind ~= "fetch" and kind ~= "buy") then
		ML.Log("ml_order_force needs a business key of jobs.toml and maybe a kind, like apothecary or apothecary fetch")
		return
	end
	local turn = (kind == "fetch" or kind == "buy") and Orders.NEED or Orders.SEND
	local last = ML.Store.Get(Orders.LAST_KEY, {})
	last[slotOf(key, turn)] = nil
	ML.Store.Set(Orders.LAST_KEY, last)
	local count = ML.Store.Get(Orders.FORCED_KEY, {}).count or 0
	local day = ML.Days.Current()
	ML.Store.Set(Orders.FORCED_KEY, { key = key, turn = turn, kind = kind ~= "" and kind or nil, day = day, count = count + 1 })
	local order = byId[offerToday(key, day, turn)]
	ML.Log("order forced", key, order.kind, "day=", day, "with", order.to or order.from or order.need)
end

-- ml_crime_test [note]: the authorities of the town nearby hear that the character stole a slip from
-- the innkeeper, or 300 IOUs with note: the fine should be 50 or 80 groschen. ml_crime_forget makes them forget. To remove before publishing.
Orders.CRIME_VICTIM = "ttkc_inkeeper"
Orders.CRIME_NOTE_COUNT = 300

local function crimeGuards(line)
	local guardName = string.match(line or "", "^(%S*)")
	if guardName ~= "" then
		return { System.GetEntityByName(guardName) }
	end
	for town in pairs(ML.ORDER_AUTHORITIES) do
		local guards = authoritiesNear(town)
		if #guards > 0 then
			return guards
		end
	end
	return {}
end

function Orders.CrimeTest(line)
	local notes = string.match(line or "", "^(%S*)") == "note"
	local guards, victim = crimeGuards(""), System.GetEntityByName(Orders.CRIME_VICTIM)
	if #guards == 0 or not victim then
		ML.Log("ml_crime_test found no authorities nearby or no victim. guards=", #guards, "victim=", victim and victim:GetName())
		return
	end
	ML.Try("crime test", function()
		local count = notes and Orders.CRIME_NOTE_COUNT or 1
		reportTheft(guards, victim, createItem(notes and Orders.NOTE_ITEM or Orders.SLIP_ITEM, count), count)
	end)
end

-- ml_crime_forget [guard]: the guard forgets its crimes, as Skald does with crime:forgetCrimesData.
function Orders.CrimeForget(line)
	for _, guard in ipairs(crimeGuards(line)) do
		ML.Try("crime forget", function()
			local message = XGenAIModule.MakeTableFromType("crime:forgetCrimesData")
			message.self = guard.this.id
			XGenAIModule.SendMessageToEntityData(guard.this.id, "crime:forgetCrimesData", message)
			ML.Log("crime forgotten by", guard:GetName())
		end)
	end
end

-- Moves the time of every taken order back, so the next tick runs them out.
function Orders.Expire()
	local active = ML.Store.Get(Orders.ACTIVE_KEY, {})
	for _, taken in pairs(active) do
		taken.taken = taken.taken - ML.ORDER_RULES.deadline_hours * Orders.HOUR_SECONDS
		taken.due = Calendar.GetWorldTime() - 1
	end
	ML.Store.Set(Orders.ACTIVE_KEY, active)
end

-- ml_order_trust <business> <delivered> [fetched] [failed]: sets what that business has seen.
function Orders.SetTrust(line)
	local key, delivered, fetched, failed, steady, casual = string.match(line or "", "^(%S+)%s+(%d+)%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)")
	if not key or not ML.ORDER_BUSINESSES[key] then
		ML.Log("ml_order_trust needs a business key and how many deliveries, like apothecary 5, or apothecary 10 5 1 with pickups and orders run out, "
			.. "or apothecary 0 0 0 50 20 with steady and casual hours worked")
		return
	end
	local all = ML.Store.Get(Orders.TRUST_KEY, {})
	all[key] = { delivered = tonumber(delivered), fetched = tonumber(fetched) or 0, failed = tonumber(failed) or 0,
		steady_hours = tonumber(steady) or 0, casual_hours = tonumber(casual) or 0 }
	ML.Store.Set(Orders.TRUST_KEY, all)
	endForce()
	ML.Log("order trust", key, all[key], "fetch, buy=", trusted(key))
end

function Orders.Status()
	-- The site the dialog takes, the one of the NPC nearest the player, and the order to hand over there.
	local here = ML.Try("order site", ML.Jobs.NearestSite)
	ML.Log("orders here", here and here.key or "no site", "deliver=", here and bringable(here) or 0)
	local day, now = ML.Days.Current(), Calendar.GetWorldTime()
	local last, trust = ML.Store.Get(Orders.LAST_KEY, {}), ML.Store.Get(Orders.TRUST_KEY, {})
	for key in pairs(ML.ORDER_BUSINESSES) do
		local fetch, buy = trusted(key)
		local fetchNow, buyNow = allowed(key)
		ML.Log("orders trust", key, trust[key] or {}, "fetch=", fetch, "buy=", buy, "with points fetch=", fetchNow, "buy=", buyNow,
			"deliver points=", ML.Reputation.Accepts(siteByKey(key), points(ML.ORDER_RULES.rep_deliver)))
		for _, turn in ipairs({ Orders.SEND, Orders.NEED }) do
			local slot, today = slotOf(key, turn), offerToday(key, day, turn)
			local order = today and byId[today]
			ML.Log("orders business", slot, "first day=", firstDay(slot), "today=", order and order.kind, order and (order.to or order.from or order.need),
				"next in=", daysToNext(slot, day), "last=", last[slot])
		end
	end
	for slot, taken in pairs(ML.Store.Get(Orders.ACTIVE_KEY, {})) do
		local order = byId[taken.id]
		ML.Log("orders taken", slot, order and order.kind, order and (order.to or order.from or order.need), "goods=", taken.goods, "amount=", taken.amount,
			"money=", taken.money, "picked=", taken.picked, "hours left=", (dueOf(taken) - now) / Orders.HOUR_SECONDS)
	end
	for key, debt in pairs(ML.Store.Get(Orders.DEBTS_KEY, {})) do
		ML.Log("orders debt", key, debt)
	end
	for digits, record in pairs(ML.Store.Get(Orders.SLIPS_KEY, {})) do
		ML.Log("orders slip", digits, record)
	end
	for town, crime in pairs(ML.Store.Get(Orders.CRIMES_KEY, {})) do
		ML.Log("orders crime waiting", town, crime, "authorities near=", #authoritiesNear(town))
	end
	ML.Log("orders day=", day)
end

"""Generates what the mod needs from the orders out of a single file.

Reads mod/medieval_life/orders.toml, jobs.toml for the businesses and economy.toml for the mod of prices that the money
follows, and writes:

- Scripts/MedievalLife/orders_data.lua: rules, what each business sells and what it needs, and its orders, with pay
  and tokens. There are three kinds: take something of its own to each of the other businesses, bring it
  from each of the others something it needs, and buy it each thing it needs.
- Quests/medieval_life/trosecko/ml_order_<business>.xml: one repeatable quest per business, with one objective per
  order (two when fetching: pick up and come back), driven by tokens like ml_employment. And its definition and node in
  trosecko.xml.
- Quests/medieval_life/trosecko/ml_work/nebakovObrana/ml_order_dialog.xml: the dialog of the orders, inside the
  Gameplay with VoiceNamespace, to use the recorded lines of Henry. And its definition in nebakovObrana.xml.
- The debt, with its amount and the option to pay, also inside the work dialogs written by hand:
  ml_casual_dialog.xml and ml_work_dialog.xml.
- Libs/Tables/item/item__medieval_life.xml: the tokens of each order (accepted, done and run out).
- localization/*_xml/text__medieval_life.xml: the texts, in English and Spanish.

The texts come from templates, with the names of the people as the game writes them (text_ui_soul.xml) and the
gender of their Skald character. Looks up each business in jobs.toml and each item in the game tables, and stops if
they do not exist.
tools/install_mod.py runs it before packing.

Usage: python -I -X utf8 mod/medieval_life/tools/generate_orders.py mod/medieval_life
"""
import math
import os
import pathlib
import re
import sys
import tomllib
import uuid
import zipfile
from xml.sax.saxutils import escape

# The repository: this file is in mod/medieval_life/tools/.
ROOT = pathlib.Path(__file__).resolve().parents[3]
TABLES = ROOT / "game_files/Tables.pak/Libs/Tables"
ITEMS = TABLES / "item"
# KCD2_GAME, or the game in the default Steam library, or in the maintainer's.
GAME_PLACES = (r"C:\Program Files (x86)\Steam\steamapps\common\KingdomComeDeliverance2", r"E:\SteamLibrary\steamapps\common\KingdomComeDeliverance2")
GAME = pathlib.Path(os.environ.get("KCD2_GAME") or next((p for p in GAME_PLACES if os.path.isfile(os.path.join(p, "Data", "Tables.pak"))), GAME_PLACES[0]))
LANGUAGES = (("English_xml", "en"), ("Spanish_xml", "es"))
# Each order has a token to accept it, and each business, the ones that end them, shared by all its objectives:
# an If only lets them through to the active objective. The game goes through every token when loading, recursively,
# and with 1393 it ran out of stack. send_* are for delivering, and need_* for fetching or
# buying. picked is picking up, lost is running out before picking up, with no debt, and close closes the quest when
# the business has none active.
SHARED = ("send_done", "send_failed", "picked", "lost", "need_done", "need_failed", "close")
QUESTS = "data/Quests/medieval_life/trosecko"
NEW_LIFE_SOUL = "e9f088ff-48e3-5fa1-b733-80504a56d1dc"
# Recorded lines of Henry in the quest nebakovObrana, as in ml_casual_dialog. The question is not the one of the
# day laborer: "Is there something I can do for you? Anything?", with voice and lips in that folder.
HENRY_ASK = ("doml_henry_jenze_mne_na_t_72lu", "2.8")
HENRY_AGREE = ("bejk_henry_dobre_neco_s_t_25zt", "1.85")
# The question of the turn of what the business needs: the option says fetch or buy, and Henry says
# "I'll gladly do anything you need, just tell me", with voice and lips in nebakovObrana.
HENRY_NEED = ("os_k_henry_proste_bych_ra_SqDb", "3.17")
# Handing over and receiving something in the dialog, like Betty in
# svatba/po_svatbe/sekera_u_hostinske/naval_prachy.xml: AnimationCommand with the fragment, its Guid and its variant.
GIVE = ("ADLG_Give", "00ebf610-b3ea-9950-e27a-18618ccae1a3", "0")
TAKE = ("ADLG_Take", "8f890737-6b10-2c51-77d5-c6d0ccf58c77", "0")
HANDS_OVER = ((GIVE, None), (TAKE, "HENRY"))
HANDS_IN = ((GIVE, "HENRY"), (TAKE, None))
TEXTS = {
    "ui_ml_order_ask": ("Any errands for me?", "¿Tienes algún encargo para mí?"),
    "ui_ml_order_need_ask": ("Need me to fetch or buy you something?", "¿Necesitas que te traiga o te compre algo?"),
    # How many unpaid errands go to the guard is a setting, so the texts do not say how many, nor the 12 hours.
    "ml_order_reported": ("You owe for errands you never paid. The businesses reported you to the guard of",
                          "Debes encargos que nunca pagaste. Los negocios te denunciaron a la guardia de"),
    "ml_order_lost_trust": ("You've let me down before. You'll have to earn my trust back by working more for me.",
                            "Ya me has fallado. Tendrás que recuperar mi confianza trabajando más para mí."),
    "ui_ml_order_remind": ("What was it you needed me to buy?", "¿Qué era lo que necesitabas que te comprara?"),
    "ml_order_remind": ("This. Don't forget it again.", "Esto. Que no se te olvide otra vez."),
    "ml_order_untrusted": ("I don't trust you enough for that yet. Work more for me first.",
                           "Todavía no confío lo suficiente en ti para eso. Primero trabaja más para mí."),
    "ml_order_buy_offer": ("I need you to buy something for me. I'll give you the money, and whatever's left over is yours.",
                           "Necesito que me compres algo. Te doy el dinero, y lo que sobre es tuyo."),
    "ui_ml_order_buy_bring": ("I bring what you asked me to buy.", "Traigo lo que me pediste que comprara."),
    "ml_order_bought": ("Just what I needed. Keep whatever money is left.", "Justo lo que necesitaba. Quédate con lo que sobró."),
    "ml_order_take_this": ("Here, take it. Mind it gets there whole.", "Toma. Que llegue entero."),
    "ml_order_take_money": ("Here's the money.", "Aquí tienes el dinero."),
    "ml_order_take_this_tomorrow": ("Here, take it. No need to rush: it can get there tomorrow, by the hour on the slip.",
                                    "Toma. No hace falta correr: puede llegar mañana, a la hora de la boleta."),
    "ml_order_take_this_later": ("Here, take it. No need to rush: it can get there the day after tomorrow, by the hour on the slip.",
                                 "Toma. No hace falta correr: puede llegar pasado mañana, a la hora de la boleta."),
    "ml_order_take_money_tomorrow": ("Here's the money. Bring it to me tomorrow, by the hour on the slip.",
                                     "Aquí tienes el dinero. Tráemelo mañana, a la hora de la boleta."),
    "ml_order_take_money_later": ("Here's the money. Bring it to me the day after tomorrow, by the hour on the slip.",
                                  "Aquí tienes el dinero. Tráemelo pasado mañana, a la hora de la boleta."),
    "ml_order_fetch_tomorrow": ("There's time: bring it back to me tomorrow, by the hour on the slip.",
                                "Hay tiempo: tráemelo mañana, a la hora de la boleta."),
    "ml_order_fetch_later": ("There's time: bring it back to me the day after tomorrow, by the hour on the slip.",
                             "Hay tiempo: tráemelo pasado mañana, a la hora de la boleta."),
    # Due in three days or more, with a longer time in the settings.
    "ml_order_take_this_days": ("Here, take it. No need to rush: you have a few days, until the day and hour on the slip.",
                                "Toma. No hace falta correr: tienes unos días, hasta el día y la hora de la boleta."),
    "ml_order_take_money_days": ("Here's the money. You have a few days: bring it to me by the day and hour on the slip.",
                                 "Aquí tienes el dinero. Tienes unos días: tráemelo para el día y la hora de la boleta."),
    "ml_order_fetch_days": ("There's time: you have a few days to bring it back to me, until the day and hour on the slip.",
                            "Hay tiempo: tienes unos días para traérmelo, hasta el día y la hora de la boleta."),
    "ml_order_handed": ("Here it is, all of it. Don't lose it on the way.", "Aquí está todo. Que no se te pierda en el camino."),
    "ml_order_buy": ("Buy", "Compra"),
    "ml_order_failed_buy": ("You didn't bring it in time. Now you owe the money you were given.",
                            "No cumpliste a tiempo. Ahora debes el dinero que te dieron."),
    "ml_order_failed_lost": ("You didn't pick up the order in time.", "No recogiste el pedido a tiempo."),
    "ml_order_log_picked": ("I have the order. Now to take it back.", "Ya tengo el pedido. Ahora hay que llevarlo de vuelta."),
    "ml_order_log_lost": ("I didn't get there in time. At least I owe nothing.", "No llegué a tiempo. Al menos no debo nada."),
    "ml_order_log_buy": ("I took the money. The slip says by when I must bring what was asked.",
                         "Recibí el dinero. La boleta dice para cuándo tengo que traer lo pedido."),
    "ml_order_log_buy_canceled": ("I didn't make it in time. They'll take me for a thief until I pay back the money.",
                                  "No llegué a tiempo. Me tomarán por ladrón hasta que devuelva el dinero."),
    "ui_ml_order_accept": ("I'll do it.", "Lo hago."),
    "ui_ml_order_decline": ("Not now.", "Ahora no."),
    "ui_ml_order_pay": ("I've come to pay what I owe.", "Vengo a pagar lo que debo."),
    "ml_order_have": ("You already have my errand. Off you go.", "Ya tienes mi encargo. Anda, ve."),
    "ml_order_debt": ("You owe me for the goods you never delivered. Pay up, or there's no work for you here.",
                      "Me debes la mercancía que nunca entregaste. Paga, o aquí no hay trabajo para ti."),
    "ml_order_paid": ("We're even.", "Estamos a mano."),
    "ml_order_short": ("That's not enough. Come back when you have it all.", "No te alcanza. Vuelve cuando lo tengas todo."),
    "ml_order_owe": ("You owe", "Debes"),
    "ml_order_groschen": ("groschen.", "groschen."),
    "ml_order_wait_1": ("Nothing today. Come back tomorrow.", "Hoy no tengo nada. Vuelve mañana."),
    "ml_order_wait_later": ("Nothing today. Come back another day.", "Hoy no tengo nada. Vuelve otro día."),
    "ml_order_received": ("Just in time. Here's what was agreed.", "Justo a tiempo. Aquí tienes lo acordado."),
    "ml_order_late": ("It's too late for errands today: there's no time before they close. Come back tomorrow.",
                      "Ya es tarde para encargos hoy: no hay tiempo antes de que cierren. Vuelve mañana."),
    "ml_order_missing": ("That's not all of it. Come back when you have everything.", "Eso no está completo. Vuelve cuando lo tengas todo."),
    "ml_order_still_missing": ("Still missing:", "Todavía falta:"),
    "ml_order_failed": ("You didn't deliver in time. Now you owe the value of the goods.", "No cumpliste a tiempo. Ahora debes el valor de la mercancía."),
    "ml_order_log_active": ("I took the errand. The slip says by when.",
                            "Acepté el encargo. La boleta dice para cuándo."),
    "ml_order_log_done": ("Done and paid.", "Cumplido y pagado."),
    "ml_order_log_canceled": ("I didn't make it in time. They'll take me for a thief until I pay for the goods.",
                              "No llegué a tiempo. Me tomarán por ladrón hasta que pague la mercancía."),
    # What the book of trades notes at the business that gave the order, by kind, in singular and plural.
    "ml_order_book_deliver_one": ("delivery errand", "encargo de entrega"),
    "ml_order_book_deliver_many": ("delivery errands", "encargos de entrega"),
    "ml_order_book_fetch_one": ("pickup errand", "encargo de recogida"),
    "ml_order_book_fetch_many": ("pickup errands", "encargos de recogida"),
    "ml_order_book_buy_one": ("shopping errand", "encargo de compra"),
    "ml_order_book_buy_many": ("shopping errands", "encargos de compra"),
    # The slip of an order: orders.lua builds its pages with these parts.
    "ml_order_slip_title": ("Errand slip", "Boleta de encargo"),
    "ml_order_slip_from": ("Errand of", "Encargo de"),
    "ml_order_slip_deliver": ("Deliver to", "Entregar a"),
    "ml_order_slip_fetch": ("Pick up from", "Recoger donde"),
    "ml_order_slip_back": ("Bring it back to", "Traerlo de vuelta a"),
    "ml_order_slip_buy": ("Buy", "Comprar"),
    "ml_order_slip_goods": ("Goods", "Mercancía"),
    "ml_order_slip_in": ("in", "en"),
    "ml_order_slip_due": ("Due", "Vence"),
    "ml_order_slip_today": ("today at", "hoy a las"),
    "ml_order_slip_tomorrow": ("tomorrow at", "mañana a las"),
    "ml_order_slip_day_after": ("the day after tomorrow at", "pasado mañana a las"),
    # "Due in 5 days, at 14:00": ml_order_slip_in, the number and this.
    "ml_order_slip_days_at": ("days, at", "días, a las"),
    "ml_order_slip_pay": ("Pay", "Pago"),
    "ml_order_slip_money": ("Money given", "Dinero entregado"),
    "ml_order_slip_gr": ("groschen", "groschen"),
    "ml_order_slip_reported": ("Reported to the guard of", "Denunciado a la guardia de"),
    "ml_order_slip_failed": ("Not done in time. Owed:", "No se cumplió a tiempo. Se debe:"),
    "qdesc_ml_order": ("Someone in town trusted me with an errand. If I don't finish it by the time on the slip, I'll owe the value of the goods.",
                       "Alguien del pueblo me confió un encargo. Si no lo cumplo para la hora de la boleta, deberé el valor de la mercancía."),
}
# The waits of 2 days or more, and the sentence added to the offer when the destination is in the other town.
WAIT = ("Nothing today. Come back in {days} days.", "Hoy no tengo nada. Vuelve en {days} días.")
# The debt with its amount, one line for each possible amount. For any other, ml_order_debt goes, without the amount.
DEBT = ("You owe me {groschen} groschen for the goods you never delivered. Pay up, or there's no work for you here.",
        "Me debes {groschen} groschen por la mercancía que nunca entregaste. Paga, o aquí no hay trabajo para ti.")
FAR = ("It's in {town}, and the road can be dangerous. That's why it pays well.", "Es en {town}, y el camino puede ser peligroso. Por eso paga bien.")
# The templates of each pair. {sender} is the business that gives the order and {other}, the other business: the one it
# is taken to, or where it is picked up. The dialogs do not say which goods it is; only the objective to buy,
# which needs it.
TITLE = ("An errand for {sender}", "Un encargo de {sender}")
# The name of the slip of each turn in the inventory.
SLIP_NAME = {"send": ("Slip from {sender}", "Boleta de {sender}"), "need": ("Order from {sender}", "Pedido de {sender}")}
OFFER = ("I need a package taken to {other}. You'll be paid {pay} groschen when you hand it over.",
         "Necesito que le lleves un paquete a {other}. Al recibirlo, te pagará {pay} groschen.")
OBJECTIVE = ("Take the package from {sender} to {other}{where}", "Llevar el paquete de {sender} a {other}{where}")
WHERE = (" in {town}", ", en {town}")
BRING = ("I bring a package from {sender}.", "Traigo un paquete de parte de {sender}.")
FETCH_OFFER = ("{other} has an order of mine ready. Pick it up and bring it here, and I'll pay you {pay} groschen.",
               "{other} tiene listo un pedido mío. Ve a buscarlo y tráemelo, y te pagaré {pay} groschen.")
# The same offers for a pay changed in the settings, in two lines: the first without the amount, and then the one
# with it, from one line for each amount that the settings give. The dialog cannot put a number in a line.
OFFER_PLAIN = ("I need a package taken to {other}.", "Necesito que le lleves un paquete a {other}.")
FETCH_OFFER_PLAIN = ("{other} has an order of mine ready.", "{other} tiene listo un pedido mío.")
PAY_LINE = {"deliver": ("You'll be paid {pay} groschen when you hand it over.", "Al recibirlo, te pagará {pay} groschen."),
            "fetch": ("Pick it up and bring it here, and I'll pay you {pay} groschen.", "Ve a buscarlo y tráemelo, y te pagaré {pay} groschen.")}
# For an amount without a line, which the settings do not give: the slip says it.
PAY_SLIP = {"deliver": ("You'll be paid when you hand it over: the slip says how much.", "Al recibirlo, te pagará lo que dice la boleta."),
            "fetch": ("Pick it up and bring it here, and I'll pay you what the slip says.", "Ve a buscarlo y tráemelo, y te pagaré lo que dice la boleta.")}
# The steps of the pay of the errands in the settings, 25 to 300 % (the slider of settings.lua).
ORDER_PAY_PERCENTS = range(25, 301, 25)
PICK = ("Pick up the order of {sender} from {other}{where}", "Recoger el pedido de {sender} donde {other}{where}")
BACK = ("Take the order back to {sender}{back}", "Llevarle el pedido a {sender}{back}")
PICKUP = ("I've come for the order of {sender}.", "Vengo por el pedido de {sender}.")
FETCH_BRING = ("I bring your order from {other}.", "Traigo tu pedido de parte de {other}.")
BUY_OBJECTIVE = ("Buy {goods} for {sender}", "Comprar {goods} para {sender}")


def read(path):
    return path.read_text("utf-8-sig", errors="replace")


def edit(path, change):
    raw = path.read_bytes().decode("utf-8")
    crlf = "\r\n" in raw
    text = change(raw.replace("\r\n", "\n"))
    path.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))


def guid(name):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"medieval_life/{name}"))


def game_items():
    found = {}
    for path in ITEMS.glob("item*.xml"):
        for body in re.findall(r"<\w+ ([^>]*?)/?>", read(path)):
            row = dict(re.findall(r'(\w+)="([^"]*)"', body))
            if "Name" in row and re.fullmatch(r"[0-9a-f-]{36}", row.get("Id", "")):
                found[row["Name"]] = row
    return found


def people(sites, places):
    """Name in English and Spanish, and whether it is a woman, of the first NPC of each site, as the game writes them.
    And the soul of each NPC of the site, for the marker of the destination. A generic NPC, with no name in the game,
    takes the name of the place from jobs.toml."""
    characters, female, souls = {}, {}, {}
    for path in (TABLES / "rpg").glob("soul*.xml"):
        for body in re.findall(r"<soul ([^>]*)>", read(path)):
            row = dict(re.findall(r'(\w+)="([^"]*)"', body))
            characters[row.get("soul_name")] = row.get("skald_character_name")
            souls[row.get("soul_name")] = row.get("soul_id")
    for path in TABLES.rglob("skald_character*.xml"):
        for body in re.findall(r"<skald_character ([^>]*)>", read(path)):
            row = dict(re.findall(r'(\w+)="([^"]*)"', body))
            female[row.get("skald_character_name")] = row.get("gender") == "1"
    names = []
    for folder, _ in LANGUAGES:
        text = zipfile.ZipFile(GAME / "Localization" / f"{folder}.pak").read("text_ui_soul.xml").decode("utf-8", "replace")
        names.append(dict(re.findall(r"<Row><Cell>([^<]*)</Cell><Cell>[^<]*</Cell><Cell>([^<]*)</Cell></Row>", text)))
    found = {}
    for key, npcs in sites.items():
        character = characters.get(npcs[0])
        uiname = f"{character}_uiName"
        if not character or uiname not in names[0] or uiname not in names[1]:
            names_of = places[key]
        else:
            names_of = (names[0][uiname], names[1][uiname])
        missing = [npc for npc in npcs if not souls.get(npc)]
        if missing:
            raise SystemExit(f"jobs.toml, {key}: cannot find the soul of {missing} in the game")
        found[key] = {"names": names_of, "female": female.get(character, False),
                      "souls": " ".join(souls[npc] for npc in npcs)}
    return found


def soul_names():
    """The soul_name values of the game tables, to check the authorities of each town."""
    found = set()
    for path in (TABLES / "rpg").glob("soul*.xml"):
        found.update(re.findall(r'<soul [^>]*soul_name="([^"]*)"', read(path)))
    return found


def spanish(text):
    """The Spanish contractions the template leaves: de el, a el."""
    return re.sub(r"\ba el\b", "al", re.sub(r"\bde el\b", "del", text))


def sentence(text):
    return text[0].upper() + text[1:]


def load(mod_dir):
    data = tomllib.loads((mod_dir / "orders.toml").read_text("utf-8"))
    # The economy mod that KCD2 Life adapts its money to.
    data["economy"] = tomllib.loads((mod_dir / "economy.toml").read_text("utf-8"))["realish"]
    for field in ("name", "file", "price_factor"):
        if field not in data["economy"]:
            raise SystemExit(f"economy.toml: missing {field}")
    jobs = tomllib.loads((mod_dir / "jobs.toml").read_text("utf-8"))["site"]
    sites = {s["key"]: s["npcs"] for s in jobs}
    places = {s["key"]: (s["place_en"], s["place_es"]) for s in jobs}
    for field in ("days_between", "deadline_hours", "fail_points", "done_points", "pay_same_town", "pay_other_town", "fetch_pay_factor", "buy_percent",
                  "trust_fetch", "trust_buy", "trust_factor", "rep_deliver", "rep_fetch", "rep_buy", "crime_fails", "crime_range", "authorities", "towns", "town_names", "neighbors", "business"):
        if field not in data:
            raise SystemExit(f"orders.toml: missing {field}")
    in_towns = [key for keys in data["towns"].values() for key in keys]
    if sorted(in_towns) != sorted(sites):
        raise SystemExit(f"orders.toml: the towns must have each site of jobs.toml once: {sorted(set(sites) ^ set(in_towns))}")
    if sorted(data["town_names"]) != sorted(data["towns"]):
        raise SystemExit("orders.toml: town_names must have the same towns as towns")
    if sorted(data["authorities"]) != sorted(data["towns"]):
        raise SystemExit("orders.toml: authorities must have the same towns as towns")
    # An order goes at most to a neighboring town, and being neighbors goes both ways.
    if sorted(data["neighbors"]) != sorted(data["towns"]):
        raise SystemExit("orders.toml: neighbors must have the same towns as towns")
    for town, near in data["neighbors"].items():
        for other in near:
            if other not in data["towns"] or town not in data["neighbors"][other]:
                raise SystemExit(f"orders.toml, neighbors: {town} and {other} must be neighbors both ways")
    known = soul_names()
    missing = [name for names in data["authorities"].values() for name in names if name not in known]
    if missing:
        raise SystemExit(f"orders.toml: cannot find these souls of authorities in the game: {missing}")
    town_of = {key: town for town, keys in data["towns"].items() for key in keys}
    who = people(sites, places)
    items = game_items()
    for business in data["business"]:
        key = business.get("key")
        if key not in sites:
            raise SystemExit(f"orders.toml, {key}: is not a site of jobs.toml")
        # What it sells goes to delivering, and what it needs, to fetching and buying. At least three of each.
        for side, named in (("sells", False), ("needs", True)):
            if len(business.get(side, [])) < 3:
                raise SystemExit(f"orders.toml, {key}: {side} needs at least 3 items")
            for goods in business[side]:
                fields = ("goods", "amount", "en", "es") if named else ("goods", "amount")
                if any(field not in goods for field in fields):
                    raise SystemExit(f"orders.toml, {key}: {goods} of {side} is missing one of {fields}")
                if goods["goods"] not in items:
                    raise SystemExit(f"orders.toml, {key}: the item {goods['goods']} does not exist")
                least, most = goods["amount"]
                if not 0 < least <= most:
                    raise SystemExit(f"orders.toml, {key}: amount of {goods['goods']} goes from least to most")
                item = items[goods["goods"]]
                goods.update(item=item["Id"], price=int(item.get("Price", "0")), least=least, most=most, ui=item.get("UIName", ""))
        for column, language in enumerate(("en", "es")):
            if f"name_{language}" in business:
                who[key]["names"] = tuple(business[f"name_{language}"] if c == column else n for c, n in enumerate(who[key]["names"]))
    used = {goods["goods"] for b in data["business"] for goods in b["sells"] + b["needs"]}
    unknown = sorted(set(data["economy"].get("percent", {})) - used)
    if unknown:
        raise SystemExit(f"economy.toml, percent: these goods are in no errand: {unknown}")
    orders = []
    # The texts of the dialog go by text and not by order: an offer depends only on who
    # receives or hands over and on whether it is in the other town, and handing over or picking up, only on who sends.
    # said keeps each text once, with its key.
    said = data["said"] = {}

    def say(order, field, key, column, text):
        order[f"{field}_key"] = key
        said.setdefault(key, ["", ""])[column] = text

    def add(sender, kind, code, other=None, need=None):
        """One order, with the pay, the tokens and the texts of its kind. other is the destination when delivering and
        the origin when fetching; need, the number of the goods when buying."""
        far = other is not None and town_of[other] != town_of[sender]
        pay = 0 if kind == "buy" else data["pay_other_town"] if far else data["pay_same_town"]
        # A pickup is there and back: it pays fetch_pay_factor times as much, to the nearest tenth of a groschen,
        # the smallest coin the pay can have (orders_data.lua keeps it in tenths).
        if kind == "fetch":
            pay = math.floor(pay * data["fetch_pay_factor"] * 10 + 0.5) / 10
        order = {"id": len(orders) + 1, "business": sender, "kind": kind, "code": code, "other": other, "need": need,
                 "number": sum(1 for o in orders if o["business"] == sender) + 1,
                 "pay": pay,
                 # What it pays with an economy mod, rounded as economy.lua rounds it.
                 "pay_economy": economy_money(round(pay * 10), data) / 10,
                 "tokens": {"accept": guid(f"ml_order_{code}_accept")}}
        side = "far" if far else "near"

        def amount(value, language):
            text = f"{value:g}"
            return text.replace(".", ",") if language == "es" else text

        for column, language in enumerate(("en", "es")):
            fix = spanish if language == "es" else (lambda text: text)
            fields = {"sender": who[sender]["names"][column], "pay": amount(order["pay"], language), "where": "", "back": ""}
            note = ""
            if other:
                town = data["town_names"][town_of[other]][column]
                fields["other"] = who[other]["names"][column]
                if far:
                    fields["where"] = WHERE[column].format(town=town)
                    fields["back"] = WHERE[column].format(town=data["town_names"][town_of[sender]][column])
                    note = " " + FAR[column].format(town=town)
            if kind == "deliver":
                say(order, "offer", f"ml_order_offer_{other}_{side}", column, sentence(fix(OFFER[column].format(**fields))) + note)
                say(order, "bring", f"ui_ml_order_bring_{sender}", column, sentence(fix(BRING[column].format(**fields))))
                order[f"objective_{language}"] = sentence(fix(OBJECTIVE[column].format(**fields)))
            elif kind == "fetch":
                say(order, "offer", f"ml_order_fetch_offer_{other}_{side}", column, sentence(fix(FETCH_OFFER[column].format(**fields))) + note)
                say(order, "pickup", f"ui_ml_order_pickup_{sender}", column, sentence(fix(PICKUP[column].format(**fields))))
                say(order, "bring", f"ui_ml_order_fetched_{other}", column, sentence(fix(FETCH_BRING[column].format(**fields))))
                order[f"pick_{language}"] = sentence(fix(PICK[column].format(**fields)))
            else:
                say(order, "offer", "ml_order_buy_offer", column, TEXTS["ml_order_buy_offer"][column])
                say(order, "bring", "ui_ml_order_buy_bring", column, TEXTS["ui_ml_order_buy_bring"][column])
                goods = data["by_key"][sender]["needs"][need - 1][language]
                order[f"objective_{language}"] = sentence(fix(BUY_OBJECTIVE[column].format(goods=goods, **fields)))
            # The same offer with the pay of an economy mod. Buying says no amount, so it keeps its text.
            if kind in ("deliver", "fetch"):
                template = OFFER if kind == "deliver" else FETCH_OFFER
                twin = dict(fields, pay=amount(order["pay_economy"], language))
                say(order, "offer_economy", order["offer_key"] + ECONOMY_SUFFIX, column, sentence(fix(template[column].format(**twin))) + note)
                # And without the amount, for a pay changed in the settings.
                plain = OFFER_PLAIN if kind == "deliver" else FETCH_OFFER_PLAIN
                say(order, "offer_plain", order["offer_key"] + PLAIN_SUFFIX, column, sentence(fix(plain[column].format(**fields))) + note)
            else:
                order["offer_economy_key"] = order["offer_key"]
                order["offer_plain_key"] = order["offer_key"]
        orders.append(order)

    data["by_key"] = {b["key"]: b for b in data["business"]}
    # Buying earns the same as an order in the town, within the money that is given.
    data["buy_profit"] = round(data["pay_same_town"] * 10)
    # Delivering goes first in every business, with the numbers and codes from before, so that an order taken
    # in a saved game, its tokens and its texts do not change.
    def reach(sender):
        """The other businesses of its town and of the neighboring towns, in the order of the towns."""
        town = town_of[sender]
        return [other for other in in_towns if other != sender and other in data["by_key"]
                and (town_of[other] == town or town_of[other] in data["neighbors"][town])]

    for business in data["business"]:
        for other in reach(business["key"]):
            add(business["key"], "deliver", f"{business['key']}_{other}", other=other)
    for business in data["business"]:
        for other in reach(business["key"]):
            add(business["key"], "fetch", f"{business['key']}_from_{other}", other=other)
    for business in data["business"]:
        for need in range(1, len(business["needs"]) + 1):
            add(business["key"], "buy", f"{business['key']}_buy_{need}", need=need)
    for business in data["business"]:
        sender = business["key"]
        business["titles"] = tuple(sentence((spanish if c else (lambda x: x))(TITLE[c].format(sender=who[sender]["names"][c]))) for c in range(2))
        # Coming back with what was picked up is one objective per business, and it says its town, because it can come
        # from the other.
        business["back"] = tuple(sentence((spanish if c else (lambda x: x))(BACK[c].format(
            sender=who[sender]["names"][c], back=WHERE[c].format(town=data["town_names"][town_of[sender]][c])))) for c in range(2))
        business["tokens"] = {name: guid(f"ml_order_{sender}_{name}") for name in SHARED}
        # One slip per business and turn, with its name, so that they do not stack.
        business["slips"] = {turn: guid(f"ml_order_slip_{sender}_{turn}") for turn in ("send", "need")}
        business["slip_names"] = {turn: tuple(sentence((spanish if c else (lambda x: x))(SLIP_NAME[turn][c].format(sender=who[sender]["names"][c])))
                                              for c in range(2)) for turn in ("send", "need")}
    # The souls of the destinations: only the businesses give and receive orders.
    data["souls"] = {key: who[key]["souls"] for key in in_towns if key in data["by_key"]}
    # For the slip: the name of each business and its town.
    data["names"] = {key: who[key]["names"] for key in in_towns}
    data["town_of"] = town_of
    # The number of each text, which orders.lua publishes for the dialog: the offers, by turn, and handing over and
    # picking up.
    data["groups"] = {}
    for name, field, kinds in (("send", "offer", ("deliver",)), ("need", "offer", ("fetch", "buy")),
                               ("bring", "bring", ("deliver", "fetch", "buy")), ("pickup", "pickup", ("fetch",))):
        keys = data["groups"][name] = []
        for o in orders:
            if o["kind"] in kinds:
                if o[f"{field}_key"] not in keys:
                    keys.append(o[f"{field}_key"])
                o[f"{name}_say"] = keys.index(o[f"{field}_key"]) + 1
    # With an economy mod the offers say its pay: the same offers again after them, in the same order, with their
    # twin texts. orders.lua adds the number of offers of the turn to the one it publishes.
    # With the pay changed in the settings, a third time, without the amount.
    data["economy_groups"], data["plain_groups"] = {}, {}
    # The kind of each offer of the third set: deliver and fetch go on to the line with the amount, buy does not.
    kind_of = {o["offer_key"]: o["kind"] for o in orders}
    data["plain_kinds"] = {name: [kind_of[key] for key in data["groups"][name]] for name in ("send", "need")}
    # What an order pays with the settings, as orders.lua works it out (Orders.Pay), with and without the economy mod.
    data["settings_pays"] = {kind: sorted({settings_pay(round(o["pay"] * 10), percent, economy, data)
                                           for o in orders if o["kind"] == kind
                                           for percent in ORDER_PAY_PERCENTS for economy in (False, True)})
                             for kind in ("deliver", "fetch")}
    for kind, pays in data["settings_pays"].items():
        for tenths in pays:
            said[f"ml_order_pay_{kind}_{tenths}"] = [sentence((spanish if c else (lambda x: x))(
                PAY_LINE[kind][c].format(pay=groschen_text(tenths / 10, "es" if c else "en")))) for c in range(2)]
        said[f"ml_order_pay_{kind}_slip"] = list(PAY_SLIP[kind])
    for name in ("send", "need"):
        for field, groups in (("offer_economy_key", data["economy_groups"]), ("offer_plain_key", data["plain_groups"])):
            twin = {o["offer_key"]: o[field] for o in orders if o.get(f"{name}_say")}
            groups[name] = [twin[key] for key in data["groups"][name]]
    # What can be owed, in whole groschen, as orders.lua works it out: the value of the goods that were being taken or
    # were picked up, rounded up, or the money that was given to buy. With an economy mod too.
    debts = set()
    profit_economy = economy_money(data["buy_profit"], data)
    for b in data["business"]:
        for goods in b["sells"] + b["needs"]:
            for price in (goods["price"], goods["price"] * economy_percent(goods, data) / 100):
                debts |= {math.ceil(price * amount / 10) for amount in range(goods["least"], goods["most"] + 1)}
        for goods in b["needs"]:
            for price, profit in ((goods["price"], data["buy_profit"]), (goods["price"] * economy_percent(goods, data) / 100, profit_economy)):
                debts |= {money(price, amount, goods.get("percent", data["buy_percent"]), profit) for amount in range(goods["least"], goods["most"] + 1)}
    data["debts"] = sorted(debts - {0})
    return data, orders


# The twin of a text that says an amount, with the amount of the economy mod.
ECONOMY_SUFFIX = "_economy"
# And the one that says no amount.
PLAIN_SUFFIX = "_plain"


def settings_pay(tenths, percent, economy, data):
    """What an order of that pay gives with the pay of the settings at percent, as Orders.Pay: Economy.Money of the
    pay times the factor, to the nearest tenth."""
    value = tenths * percent / 100
    if economy:
        value = math.floor(value * data["economy"]["price_factor"] + 0.5)
    return math.floor(value + 0.5)


def groschen_text(value, language):
    """An amount of groschen as the offers say it: 1.5, 10, and with a comma in Spanish."""
    text = f"{value:g}"
    return text.replace(".", ",") if language == "es" else text


def economy_money(tenths, data):
    """Money in tenths with an economy mod: price_factor times as much, to the nearest tenth, as economy.lua
    rounds it in Economy.Money."""
    return math.floor(tenths * data["economy"]["price_factor"] + 0.5)


def economy_percent(goods, data):
    """What the goods are worth with an economy mod, in percent of the game's price: their own in economy.toml, or
    price_factor."""
    return data["economy"].get("percent", {}).get(goods["goods"], round(data["economy"]["price_factor"] * 100))


def money(price, amount, percent, profit):
    """The money of an order to buy, in whole groschen, as orders.lua works it out: what a shop asks with
    50 points, plus the profit."""
    return math.ceil((price * amount * percent / 100 + profit) / 10)


def write_lua(mod_dir, data, orders):
    def order_row(o):
        place = {"deliver": f'to = "{o["other"]}"', "fetch": f'from = "{o["other"]}"', "buy": f'need = {o["need"]}'}[o["kind"]]
        tokens = "".join(f'\t\t{t} = "{g}",\n' for t, g in o["tokens"].items())
        says = f'\t\tsay = {o.get("send_say") or o.get("need_say")},\n\t\tbring_say = {o["bring_say"]},\n'
        if o["kind"] == "fetch":
            says += f'\t\tpickup_say = {o["pickup_say"]},\n'
        return f'\t{{\n\t\tid = {o["id"]},\n\t\tbusiness = "{o["business"]}",\n\t\tkind = "{o["kind"]}",\n\t\t{place},\n\t\tpay = {round(o["pay"] * 10)},\n{says}{tokens}\t}},\n'

    def goods_rows(b, side):
        rows = ""
        for n, g in enumerate(b[side], 1):
            name = f'\t\t\t\tname = "ml_order_goods_{b["key"]}_{n}",\n' if side == "needs" else ""
            if side == "needs" and "percent" in g:
                name += f'\t\t\t\tpercent = {g["percent"]},\n'
            rows += (f'\t\t\t{{\n\t\t\t\tgoods = "{g["item"]}",\n\t\t\t\tleast = {g["least"]},\n\t\t\t\tmost = {g["most"]},\n'
                     f'\t\t\t\tprice = {g["price"]},\n\t\t\t\teconomy = {economy_percent(g, data)},\n\t\t\t\tui = "{g["ui"]}",\n{name}\t\t\t}},\n')
        return rows

    def ids(b, kind):
        return ", ".join(str(o["id"]) for o in orders if o["business"] == b["key"] and o["kind"] == kind)

    def shared(b):
        return "".join(f'\t\t\t{name} = "{g}",\n' for name, g in b["tokens"].items())

    businesses = "".join(f'''	{b["key"]} = {{
		name = "ml_order_name_{b["key"]}",
		slips = {{ send = "{b["slips"]["send"]}", need = "{b["slips"]["need"]}" }},
		town = "{data["town_of"][b["key"]]}",
		tokens = {{
{shared(b)}		}},
		sells = {{
{goods_rows(b, "sells")}		}},
		needs = {{
{goods_rows(b, "needs")}		}},
		delivers = {{ {ids(b, "deliver")} }},
		fetches = {{ {ids(b, "fetch")} }},
		buys = {{ {ids(b, "buy")} }},
	}},
''' for b in data["business"])
    (mod_dir / "data/Scripts/MedievalLife/orders_data.lua").write_bytes(f'''-- Generated by tools/generate_orders.py from mod/medieval_life/orders.toml. Edit that file, not this one.
-- Money is in tenths of a groschen, and price is what one of the goods is worth in the game.
MedievalLife.ORDER_RULES = {{
	days_between = {data["days_between"]},
	deadline_hours = {data["deadline_hours"]},
	fail_points = {data["fail_points"]},
	done_points = {data["done_points"]},
	buy_percent = {data["buy_percent"]},
	trust_fetch = {data["trust_fetch"]},
	trust_buy = {data["trust_buy"]},
	trust_factor = {data["trust_factor"]},
	work_fetch_hours = {data["work_fetch_hours"]},
	late_margin_hours = {data["late_margin_hours"]},
	work_buy_hours = {data["work_buy_hours"]},
	casual_hours_weight = {data["casual_hours_weight"]},
	rep_deliver = {data["rep_deliver"]},
	rep_fetch = {data["rep_fetch"]},
	rep_buy = {data["rep_buy"]},
	buy_profit = {data["buy_profit"]},
	crime_fails = {data["crime_fails"]},
	crime_range = {data["crime_range"]},
}}
-- The economy mod that KCD2 Life adapts its money to, from economy.toml. economy is, for each goods below, its
-- worth with that mod in percent of the game's price.
MedievalLife.ECONOMY = {{
	name = "{data["economy"]["name"]}",
	file = "{data["economy"]["file"]}",
	price_factor = {data["economy"]["price_factor"]},
}}
-- How many offers each turn has. With the economy mod, the dialog has them again after these, saying its pay.
MedievalLife.ORDER_OFFERS = {{ send = {len(data["groups"]["send"])}, need = {len(data["groups"]["need"])} }}
-- The authorities of each town, by soul_name, the highest rank first: they hear a theft of errands.
MedievalLife.ORDER_AUTHORITIES = {{
{"".join(f'	{town} = {{ {", ".join(chr(34) + name + chr(34) for name in names)} }},{chr(10)}' for town, names in data["authorities"].items())}}}
-- Every order of every business: take something of its own to each of the others (to), bring back from
-- each of the others something it needs (from), or buy each thing it needs (need).
MedievalLife.ORDERS = {{
{"".join(order_row(o) for o in orders)}}}
-- What each business sells and needs, with how many go, and its orders by kind. name is the text of
-- the goods to buy. tokens end its orders in the journal: one for each outcome, shared by all of them.
MedievalLife.ORDER_BUSINESSES = {{
{businesses}}}
-- The debts in whole groschen that have their own line in the dialogs. Any other gets the line without the amount.
MedievalLife.ORDER_DEBT_LINES = {{
{"".join(f"	[{n}] = true,{chr(10)}" for n in data["debts"])}}}
'''.encode("utf-8"))


def token_trigger(name, item, y):
    return f'''				<Function Name="{name}_descriptor" PositionY="{y}" PositionX="-600" MethodName="wh::entitymodule::CreateItemClassDescriptor" DeclaringType="wh::entitymodule">
					<Constant Name="ItemClass" Value="{item}" />
					<Constant Name="Amount" Value="1" />
				</Function>
				<ItemDescriptorTrigger Name="{name}_token" PositionY="{y}" PositionX="-300">
					<Edge From="new_life.Inventory" To="Inventory" />
					<Edge From="{name}_descriptor.ItemDescriptor" To="ItemDescriptor" />
					<Edge From="in_life" To="IsActive" />
				</ItemDescriptorTrigger>
'''


def objective(name, text, marker, logs):
    """An objective with its logs: logs gives the text of Started, Completed and Canceled, or None if it has none."""
    entries = '\t\t\t\t\t\t<EnumLog Type="None" Name="None" />\n'
    for (kind, state), log in zip((("Started", "Active"), ("Completed", "Done"), ("Canceled", "Canceled")), logs):
        tracked = f' IsTracked="true" Marker="{marker}"' if kind == "Started" else ""
        inner = f'\n\t\t\t\t\t\t\t<Log StringName="{log}" />\n\t\t\t\t\t\t</EnumLog>\n' if log else " />\n"
        entries += f'\t\t\t\t\t\t<EnumLog Type="{kind}" Name="{state}"{tracked}' + (">" + inner if log else inner)
    return f'''				<Objective TypeT="ProgressFailable" Name="{name}">
					<LocalizedName StringName="{text}" />
					<Logs>
{entries}					</Logs>
				</Objective>
'''


def objective_node(tag, state, node, y, starts, ends):
    """The state of an objective and its node. starts are the tokens that start it, and ends, the shared ones that
    end it: each one goes through an If that only lets it go on if the objective is active, as if_active in
    legacy_of_the_forge. Delivering keeps the names from before, objective_state_<n> and objective_<n>, so as not
    to lose what was saved."""
    ifs, lines = "", ""
    for token in starts:
        lines += f'\t\t\t\t\t<Edge From="{token}_token.OnAcquire" To="SetActive" />\n'
    for i, (token, to) in enumerate(ends):
        gate = f"{state}_{token}_if"
        ifs += f'''				<If Name="{gate}" PositionY="{y + 50 * i}" PositionX="-150">
					<Edge From="{state}.Active" To="Condition" />
					<Edge From="{token}_token.OnAcquire" To="Exec" />
				</If>
'''
        lines += f'\t\t\t\t\t<Edge From="{gate}.True" To="{to}" />\n'
    return ifs + f'''				<State Name="{state}" PositionY="{y}" PositionX="0" RequiredForOutput="trosecko" TypeT="ProgressFailable">
{lines}				</State>
				<{tag} Name="{node}" PositionY="{y}" PositionX="300" RequiredForOutput="trosecko">
					<Edge From="{state}.State" To="Progress" />
				</{tag}>
'''


def write_quest(mod_dir, business, own, souls):
    """Each objective marks who to go to: the marker is set on the NPC with that soul when the objective starts, and
    IsTracked tracks the quest so that it shows on the map and the compass. Delivering marks the
    destination; picking up, where it is picked up, and coming back, the business; buying, the business, where what was
    bought is taken."""
    key = business["key"]
    triggers, objectives, nodes = "", "", ""
    y = 200
    for name, g in business["tokens"].items():
        triggers += token_trigger(name, g, y)
        y += 200
    for o in own:
        n, code = o["number"], o["code"]
        triggers += token_trigger(f"accept_{n}", o["tokens"]["accept"], y)
        y += 200
        row = 100 + 300 * n
        if o["kind"] == "deliver":
            nodes += objective_node(f"order_{n}", f"objective_state_{n}", f"objective_{n}", row, [f"accept_{n}"],
                                    [("send_done", "SetDone"), ("send_failed", "SetCanceled")])
            objectives += objective(f"order_{n}", f"ml_order_{code}_objective", f"to_{o['other']}",
                                    ("ml_order_log_active", "ml_order_log_done", "ml_order_log_canceled"))
        elif o["kind"] == "fetch":
            nodes += objective_node(f"pick_{n}", f"pick_objective_state_{n}", f"pick_objective_{n}", row, [f"accept_{n}"],
                                    [("picked", "SetDone"), ("lost", "SetCanceled")])
            objectives += objective(f"pick_{n}", f"ml_order_{code}_pick", f"to_{o['other']}",
                                    ("ml_order_log_active", "ml_order_log_picked", "ml_order_log_lost"))
        else:
            nodes += objective_node(f"buy_{n}", f"buy_objective_state_{n}", f"buy_objective_{n}", row, [f"accept_{n}"],
                                    [("need_done", "SetDone"), ("need_failed", "SetCanceled")])
            objectives += objective(f"buy_{n}", f"ml_order_{code}_objective", f"to_{key}",
                                    ("ml_order_log_buy", "ml_order_log_done", "ml_order_log_buy_canceled"))
    nodes += objective_node("back", "back_objective_state", "back_objective", 100, ["picked"],
                            [("need_done", "SetDone"), ("need_failed", "SetCanceled")])
    objectives += objective("back", f"ml_order_{key}_back", f"to_{key}", (None, "ml_order_log_done", "ml_order_log_canceled"))
    assets = "".join(f'\t\t\t\t<SoulAsset Name="to_{other}" SharedSoulGuids="{guids}" />\n' for other, guids in souls.items())
    active = "".join(f'\t\t\t\t\t<Edge From="accept_{o["number"]}_token.OnAcquire" To="SetActive" />\n' for o in own)
    ended = '\t\t\t\t\t<Edge From="close_token.OnAcquire" To="SetDone" />\n'
    text = f'''<?xml version="1.0" encoding="utf-8"?>
<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="brambora">
	<!-- Generated by tools/generate_orders.py from mod/medieval_life/orders.toml. Edit that file, not this one.
	     The orders of one business in the journal: one objective each, and one to bring back what was picked up.
	     Lua sends a token when one is taken. The tokens that end them are shared by the whole business, and an If
	     lets each one through only to the objective that is active, as if_active in legacy_of_the_forge: the game
	     goes through every token trigger when loading, and too many run it out of stack.
	     close ends the quest as Done when the business has no order going, because after SetFailed a quest does
	     not open again. in_life comes from the state of ml_new_life, saved since the life
     began: a business added later works in a life that began before it. -->
	<Skald>
		<Quest Name="ml_order_{key}" Type="Side" Players="0 2" Repeatable="true">
			<Ports>
				<Port Name="in_life" Direction="In" Type="bool" />
			</Ports>
			<Nodes>
				<ObjectProperties Name="new_life" PositionY="100" PositionX="-900" DeclaringType="wh::rpgmodule::I_Soul">
					<Asset Name="I_Soul" Alias="new_life" />
				</ObjectProperties>
{triggers}				<State Name="quest_state" PositionY="-100" PositionX="0" RequiredForOutput="trosecko" TypeT="wh::questmodule::QuestProgress">
{active}{ended}				</State>
{nodes}				<Output Name="Output">
					<Edge From="quest_state.State" To="Progress" />
				</Output>
			</Nodes>
			<Assets>
				<SoulAsset Name="new_life" SharedSoulGuids="{NEW_LIFE_SOUL}" />
{assets}			</Assets>
			<QuestName StringName="qname_ml_order_{key}" />
			<QuestDescription StringName="qdesc_ml_order" />
			<Objectives>
{objectives}			</Objectives>
		</Quest>
	</Skald>
</Database>
'''
    (mod_dir / QUESTS / f"ml_order_{key}.xml").write_bytes(text.encode("utf-8"))


def write_level(mod_dir, keys):
    definitions = "".join(f'\t\t\t\t<Definition File="trosecko/ml_order_{key}.xml" />\n' for key in keys)
    nodes = "".join(f'''				<ml_order_{key} Name="ml_order_{key}" PositionY="{1000 + 200 * i}" PositionX="0" RequiredForOutput="trosecko">
					<Edge From="ml_new_life.in_life" To="in_life" />
				</ml_order_{key}>
''' for i, key in enumerate(keys))

    def change(text):
        text = re.sub(r'\t\t\t\t<Definition File="trosecko/ml_order_[a-z_]+\.xml" />\n', "", text)
        text = re.sub(r"\t\t\t\t<ml_order_([a-z_]+) Name=.*?</ml_order_\1>\n", "", text, flags=re.S)
        if text.count("\t\t\t</Definitions>") != 1 or text.count('\t\t\t\t<Output Name="Output">') != 1:
            raise SystemExit("trosecko.xml: cannot find where to add the orders")
        text = text.replace("\t\t\t</Definitions>", definitions + "\t\t\t</Definitions>")
        return text.replace('\t\t\t\t<Output Name="Output">', nodes + '\t\t\t\t<Output Name="Output">')

    edit(mod_dir / "data/Quests/medieval_life/trosecko.xml", change)


def response(role, string=None, length=None, moves=()):
    """One line of the dialog. moves are animations of handing over or receiving something, (GIVE or TAKE, role), with
    role None for whoever speaks."""
    commands = "".join(f'<AnimationCommand{f" Role={chr(34)}{who}{chr(34)}" if who else ""} FragmentId="{move[0]}" Guid="{move[1]}" Variant="{move[2]}" />\n'
                       for move, who in moves)
    commands = f"<Commands>\n{commands}</Commands>\n" if commands else ""
    if not string and not commands:
        return f'<Response Role="{role}" />'
    reference = f' ReferenceLength="{length}"' if length else ""
    text = f'<Text StringName="{string}" />\n' if string else ""
    return f'<Response Role="{role}"{reference}>\n{text}{commands}</Response>'


def sequence(name, condition, end, prompt=None, elements=(), script=None, decision=None, goto=None):
    attributes = f' EntryCondition="{escape(condition)}"' if condition else ""
    attributes += f' EndType="{end}"'
    attributes += f' GoToDecision="{goto}"' if goto else ""
    attributes += f' ExitScript="{script}"' if script else ""
    body = f'<UiPrompt StringName="{prompt}" />\n' if prompt else ""
    body += "<Elements>\n" + "\n".join(elements) + "\n</Elements>\n"
    body += decision or ""
    return f'<Sequence{attributes} Name="{name}">\n{body}</Sequence>'


def decision(name, sequences, autoselect=False):
    auto = ' Autoselect="true"' if autoselect else ""
    return (f'<Decision Name="{name}"{auto} VoiceoverFallbackLevel="2" VoiceoverFallbackLevelRoles="role_ml_employer HENRY">\n'
            "<Sequences>\n" + "\n".join(sequences) + "\n</Sequences>\n</Decision>\n")


def indent(text, level):
    lines, depth, out = text.split("\n"), level, []
    for line in lines:
        if not line:
            continue
        if line.startswith("</"):
            depth -= 1
        out.append("\t" * depth + line)
        if line.startswith("<") and not line.startswith("</") and not line.endswith("/>") and f"</{line[1:].split()[0].rstrip('>')}>" not in line:
            depth += 1
    return "\n".join(out) + "\n"


def debt_sequences(prefix, owed, debts):
    """What the business that is owed says, with the amount, and the option to pay, which is always offered. If
    there is not enough, the business says so and the notice shows how much is owed. The first sequence, without the
    amount, has the decision to pay, and those of each amount jump to it with GoTo, like the dialogs of the game.
    orders.lua sets ml_order_debt."""
    pay = decision(f"dec_{prefix}_pay", [
        sequence(f"seq_{prefix}_pay", "gvar('ml_order_can_pay') == 1", "EndDialogue", "ui_ml_order_pay", script="MedievalLife.Orders.PayDebt()",
                 elements=[response("HENRY"), response("role_ml_employer", "ml_order_paid", moves=HANDS_IN)]),
        sequence(f"seq_{prefix}_pay_short", "gvar('ml_order_can_pay') == 0", "EndDialogue", "ui_ml_order_pay", script="MedievalLife.Orders.ShowDebt()",
                 elements=[response("HENRY"), response("role_ml_employer", "ml_order_short")]),
        sequence(f"seq_{prefix}_pay_later", None, "EndDialogue", "ui_ml_never_mind", elements=[response("HENRY")]),
    ])
    found = [sequence(f"seq_{prefix}_debt", f"{owed} & gvar('ml_order_debt') == 0", "Decision",
                      elements=[response("role_ml_employer", "ml_order_debt")], decision=pay)]
    for groschen in debts:
        found.append(sequence(f"seq_{prefix}_debt_{groschen}", f"{owed} & gvar('ml_order_debt') == {groschen}", "GoTo", goto=f"dec_{prefix}_pay",
                              elements=[response("role_ml_employer", f"ml_order_debt_{groschen}")]))
    return found


def put_sequences(path, parent, prefix, sequences, level):
    """Puts the debt sequences at the start of the decision parent of a dialog written by hand, first removing the ones
    that an earlier run left (those that start with prefix, with everything they have inside)."""
    def change(text):
        while match := re.search(rf'\n[ \t]*<Sequence [^>]*Name="{prefix}[^"]*">', text):
            depth = 0
            for tag in re.finditer(r"<Sequence[ >]|</Sequence>", text[match.start():]):
                depth += -1 if tag.group().startswith("</") else 1
                if depth == 0:
                    text = text[:match.start()] + text[match.start() + tag.end():]
                    break
        start = text.find(f'<Decision Name="{parent}"')
        opened = text.find("<Sequences>\n", start)
        if start < 0 or opened < 0:
            raise SystemExit(f"{path.name}: cannot find the decision {parent}")
        opened += len("<Sequences>\n")
        return text[:opened] + indent("\n".join(sequences), level) + text[opened:]

    edit(path, change)


# What the business says on handing over an order, by the day it is due: today, tomorrow or the day after.
TAKE_LINES = {
    "deliver": ("ml_order_take_this", "ml_order_take_this_tomorrow", "ml_order_take_this_later", "ml_order_take_this_days"),
    "buy": ("ml_order_take_money", "ml_order_take_money_tomorrow", "ml_order_take_money_later", "ml_order_take_money_days"),
    "fetch": (None, "ml_order_fetch_tomorrow", "ml_order_fetch_later", "ml_order_fetch_days"),
}


def turn_sequences(turn, data, offers, tag="", kinds=None):
    """What a business answers in one of its two turns: send, what it sends (delivering), or need, what it needs
    (fetching or buying). Both read their variables, ml_<turn>_state, _offer and _wait, which orders.lua sets.
    tag goes in the names of the sequences and decisions, for a second set in the same dialog. With kinds, the
    kind of each offer, the offers of deliver and fetch say no amount and go on to a line that says it, by ml_<turn>_pay."""
    prefix = turn + tag
    state, offer, wait = f"gvar('ml_{turn}_state')", f"gvar('ml_{turn}_offer')", f"gvar('ml_{turn}_wait')"
    found = [
        sequence(f"seq_{prefix}_have", f"{state} == 2", "EndDialogue", elements=[response("role_ml_employer", "ml_order_have")]),
        *debt_sequences(prefix, f"{state} == 3", data["debts"]),
        # Too few points in the panel with that business for that kind.
        sequence(f"seq_{prefix}_distrust", f"{state} == 6", "EndDialogue",
                 elements=[response("role_ml_employer", "ml_casual_distrust")]),
    ]
    # Out of the working hours of the business, or too late to get there before the place to go closes.
    found.append(sequence(f"seq_{prefix}_closed", f"{state} == 8", "EndDialogue", script="MedievalLife.Jobs.ShowHours()",
                          elements=[response("role_ml_employer", "ml_work_closed")]))
    found.append(sequence(f"seq_{prefix}_late", f"{state} == 9", "EndDialogue", elements=[response("role_ml_employer", "ml_order_late")]))
    # Fetching and buying ask for trust with that business: deliveries and pickups done.
    if turn == "need":
        found.append(sequence(f"seq_{prefix}_untrusted", f"{state} == 5", "EndDialogue", elements=[response("role_ml_employer", "ml_order_untrusted")]))
        found.append(sequence(f"seq_{prefix}_lost_trust", f"{state} == 7", "EndDialogue", elements=[response("role_ml_employer", "ml_order_lost_trust")]))
    for days in range(1, data["days_between"] + 1):
        found.append(sequence(f"seq_{prefix}_wait_{days}", f"{state} == 4 & {wait} == {days}", "EndDialogue",
                              elements=[response("role_ml_employer", f"ml_order_wait_{days}")]))
    # Any other wait gets the line without days, so that the business always answers.
    found.append(sequence(f"seq_{prefix}_wait_later", f"{state} == 4 & {wait} > {data['days_between']}", "EndDialogue",
                          elements=[response("role_ml_employer", "ml_order_wait_later")]))
    take = "TakeSend" if turn == "send" else "TakeNeed"
    # One way to take the order for all of them: the first offer has the decision, and the others jump to it with
    # GoTo, as the debts do. On accepting, the business hands over the goods when delivering and the money when buying,
    # nothing when fetching, and it says whether the order is for tomorrow or the day after: the deadline counts
    # working hours. orders.lua sets ml_<turn>_due (0 today, 1 tomorrow, 2 the day after, 3 later with a longer
    # time in the settings) and ml_need_kind (1 fetch, 2 buy).
    due, kind = f"gvar('ml_{turn}_due')", "gvar('ml_need_kind')"
    when = ((0, f"{due} == 0"), (1, f"{due} == 1"), (2, f"{due} == 2"), (3, f"{due} >= 3"))
    if turn == "send":
        cases = [("deliver", None, TAKE_LINES["deliver"], HANDS_OVER)]
    else:
        cases = [("fetch", f"{kind} == 1", TAKE_LINES["fetch"], ()), ("buy", f"{kind} == 2", TAKE_LINES["buy"], HANDS_OVER)]
    takes = []
    for name, which, lines, moves in cases:
        for day, condition in when:
            agree = [response("HENRY", *HENRY_AGREE)]
            if lines[day]:
                agree.append(response("role_ml_employer", lines[day], moves=moves))
            full = f"{which} & {condition}" if which else condition
            takes.append(sequence(f"seq_{prefix}_accept_{name}_{day}", full, "EndDialogue", "ui_ml_order_accept",
                                  script=f"MedievalLife.Orders.{take}()", elements=agree))
    takes.append(sequence(f"seq_{prefix}_decline", None, "EndDialogue", "ui_ml_order_decline", elements=[response("HENRY")]))
    if kinds:
        return found + offers_with_pay(turn, prefix, data, offers, kinds, takes)
    for i, said in enumerate(offers, 1):
        if i == 1:
            found.append(sequence(f"seq_{prefix}_offer_{i}", f"{state} == 1 & {offer} == {i}", "Decision",
                                  elements=[response("role_ml_employer", said)], decision=decision(f"dec_{prefix}_take", takes)))
        else:
            found.append(sequence(f"seq_{prefix}_offer_{i}", f"{state} == 1 & {offer} == {i}", "GoTo",
                                  elements=[response("role_ml_employer", said)], goto=f"dec_{prefix}_take"))
    return found


def offers_with_pay(turn, prefix, data, offers, kinds, takes):
    """The offers for a pay changed in the settings: each says no amount, and then the business says it, from one
    line for each amount that the settings give, chosen by ml_<turn>_pay, in tenths (orders.lua). Buying says no amount,
    and goes straight to taking it. The decision to take it goes in the first line with an amount."""
    pay = f"gvar('ml_{turn}_pay')"
    lines = []
    for kind in ("deliver", "fetch"):
        if kind not in kinds:
            continue
        lines += [(f"{pay} == {tenths}", f"ml_order_pay_{kind}_{tenths}") for tenths in data["settings_pays"][kind]]
        # Any other amount: the line that leaves it to the slip.
        lines.append((None, f"ml_order_pay_{kind}_slip"))
    paid = []
    for n, (condition, said) in enumerate(lines, 1):
        if n == 1:
            paid.append(sequence(f"seq_{prefix}_pay_{n}", condition, "Decision", elements=[response("role_ml_employer", said)],
                                 decision=decision(f"dec_{prefix}_take", takes)))
        else:
            paid.append(sequence(f"seq_{prefix}_pay_{n}", condition, "GoTo", elements=[response("role_ml_employer", said)],
                                 goto=f"dec_{prefix}_take"))
    found, first = [], True
    for i, (said, kind) in enumerate(zip(offers, kinds), 1):
        condition = f"gvar('ml_{turn}_state') == 1 & gvar('ml_{turn}_offer') == {i}"
        if kind == "buy":
            found.append(sequence(f"seq_{prefix}_offer_{i}", condition, "GoTo", elements=[response("role_ml_employer", said)],
                                  goto=f"dec_{prefix}_take"))
        elif first:
            first = False
            found.append(sequence(f"seq_{prefix}_offer_{i}", condition, "Decision", elements=[response("role_ml_employer", said)],
                                  decision=decision(f"dec_{prefix}_pay", paid, autoselect=True)))
        else:
            found.append(sequence(f"seq_{prefix}_offer_{i}", condition, "GoTo", elements=[response("role_ml_employer", said)],
                                  goto=f"dec_{prefix}_pay"))
    return found


def write_dialog(mod_dir, data, orders):
    # The errands show also where the character has a steady job.
    asked = "gvar('ml_new_life') == 1"
    groups = data["groups"]
    # With the pay changed in the settings, the same questions lead to the offers without the amount, in decisions
    # of their own: the three sets in one decision would pass the width that crashed the game.
    # orders.lua then publishes the offer without adding anything, and settings.lua sets ml_order_pay_custom.
    custom = "gvar('ml_order_pay_custom')"
    top = []
    for tag, which, offers, kinds in (("", f"{custom} != 1", {t: groups[t] + data["economy_groups"][t] for t in ("send", "need")}, {}),
                                      ("_plain", f"{custom} == 1", data["plain_groups"], data["plain_kinds"])):
        top.append(sequence(f"seq_order_ask{tag}", f"{asked} & gvar('ml_send_state') > 0 & {which}", "Decision", "ui_ml_order_ask",
                            elements=[response("HENRY", *HENRY_ASK)],
                            decision=decision(f"dec_send_open{tag}", turn_sequences("send", data, offers["send"], tag, kinds.get("send")), autoselect=True)))
        top.append(sequence(f"seq_need_ask{tag}", f"{asked} & gvar('ml_need_state') > 0 & {which}", "Decision", "ui_ml_order_need_ask",
                            elements=[response("HENRY", *HENRY_NEED)],
                            decision=decision(f"dec_need_open{tag}", turn_sequences("need", data, offers["need"], tag, kinds.get("need")), autoselect=True)))
    # Handing over: to the destination when delivering, and to the business when fetching or buying. Picking up: where it
    # is picked up, when fetching. One option per text, and Lua knows which order it is.
    # The option shows with the order, whether or not what must be handed over is there. What the business answers is one
    # for all: received, bought or something missing, by ml_order_has_goods (2 with what was bought, 1 with the rest, 0 if
    # something is missing). The decision goes in the first option, and the others jump to it with GoTo, like the debts
    # and the dialogs of the game.
    # Out of the working hours of the business, nothing is handed over: ml_order_open.
    hand = decision("dec_order_hand", [
        sequence("seq_order_hand_closed", "gvar('ml_order_open') == 0", "EndDialogue", script="MedievalLife.Jobs.ShowHours()",
                 elements=[response("role_ml_employer", "ml_work_closed")]),
        sequence("seq_order_hand_bought", "gvar('ml_order_open') == 1 & gvar('ml_order_has_goods') == 2", "EndDialogue", script="MedievalLife.Orders.Deliver()",
                 elements=[response("role_ml_employer", "ml_order_bought", moves=HANDS_IN)]),
        sequence("seq_order_hand_received", "gvar('ml_order_open') == 1 & gvar('ml_order_has_goods') == 1", "EndDialogue", script="MedievalLife.Orders.Deliver()",
                 elements=[response("role_ml_employer", "ml_order_received", moves=HANDS_IN)]),
        sequence("seq_order_hand_missing", "gvar('ml_order_open') == 1 & gvar('ml_order_has_goods') == 0", "EndDialogue", script="MedievalLife.Orders.Missing()",
                 elements=[response("role_ml_employer", "ml_order_missing")]),
    ], autoselect=True)
    for i, prompt in enumerate(groups["bring"], 1):
        condition = f"gvar('ml_new_life') == 1 & gvar('ml_order_bring') == {i}"
        if i == 1:
            top.append(sequence(f"seq_order_bring_{i}", condition, "Decision", prompt, elements=[response("HENRY")], decision=hand))
        else:
            top.append(sequence(f"seq_order_bring_{i}", condition, "GoTo", prompt, elements=[response("HENRY")], goto="dec_order_hand"))
    # What had to be bought, once more, with the same notice.
    top.append(sequence("seq_order_remind", "gvar('ml_new_life') == 1 & gvar('ml_order_remind') == 1", "EndDialogue", "ui_ml_order_remind",
                        script="MedievalLife.Orders.Remind()", elements=[response("HENRY"), response("role_ml_employer", "ml_order_remind")]))
    # Picking up, also only in working hours: one answer for all, like handing over.
    pick = decision("dec_order_pick", [
        sequence("seq_order_pick_closed", "gvar('ml_order_open') == 0", "EndDialogue", script="MedievalLife.Jobs.ShowHours()",
                 elements=[response("role_ml_employer", "ml_work_closed")]),
        sequence("seq_order_pick_handed", "gvar('ml_order_open') == 1", "EndDialogue", script="MedievalLife.Orders.Pickup()",
                 elements=[response("role_ml_employer", "ml_order_handed", moves=HANDS_OVER)]),
    ], autoselect=True)
    for i, prompt in enumerate(groups["pickup"], 1):
        condition = f"gvar('ml_new_life') == 1 & gvar('ml_order_pickup') == {i}"
        if i == 1:
            top.append(sequence(f"seq_order_pickup_{i}", condition, "Decision", prompt, elements=[response("HENRY")], decision=pick))
        else:
            top.append(sequence(f"seq_order_pickup_{i}", condition, "GoTo", prompt, elements=[response("HENRY")], goto="dec_order_pick"))
    body = indent(decision("dec_order", top).replace('<Decision Name="dec_order"', '<Decision Name="dec_order" Priority="General"', 1), 4)
    text = f'''<?xml version="1.0" encoding="utf-8"?>
<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="brambora">
	<!-- Generated by tools/generate_orders.py from mod/medieval_life/orders.toml. Edit that file, not this one.
	     The orders, in the dialog of every employer, like ml_casual_dialog. A business has two turns, each with its
	     own question: what it sends (ml_send_*) and what it needs, fetched or bought (ml_need_*). Lua keeps
	     their state, offer and wait, and ml_order_bring, ml_order_has_goods, ml_order_pickup and ml_order_can_pay, up to date for the
	     nearest one (orders.lua). A business always answers: with its order, with when to come back, or with what is
	     owed. Only Henry's lines to ask and to agree have a voice. -->
	<Skald>
		<FaderDialog Name="ml_order_dialog">
			<Text Text="ml_order_dialog" />
			<Dialogue TechnicalStatus="Enabled">
				<SelectedSouls>
					<SelectedSoul Role="HENRY" Voice="tomMcKay" Type="Wave" Language="ENG" />
					<SelectedSoul Role="role_ml_employer" Voice="bobBordeaux" Type="Wave" Language="ENG" />
				</SelectedSouls>
{body}			</Dialogue>
		</FaderDialog>
	</Skald>
</Database>
'''
    (mod_dir / QUESTS / "ml_work/nebakovObrana/ml_order_dialog.xml").write_bytes(text.encode("utf-8"))

    def change(text):
        if "ml_order_dialog" in text:
            return text
        text = text.replace('\t\t\t\t<Definition File="nebakovObrana/ml_casual_dialog.xml" />\n',
                            '\t\t\t\t<Definition File="nebakovObrana/ml_casual_dialog.xml" />\n\t\t\t\t<Definition File="nebakovObrana/ml_order_dialog.xml" />\n')
        return text.replace('\t\t\t\t<ml_casual_dialog Name="dialog" PositionY="0" PositionX="0" />\n',
                            '\t\t\t\t<ml_casual_dialog Name="dialog" PositionY="0" PositionX="0" />\n\t\t\t\t<ml_order_dialog Name="orders" PositionY="200" PositionX="0" />\n')

    edit(mod_dir / QUESTS / "ml_work/nebakovObrana.xml", change)
    # Asking a business that is owed for day labor or a steady job leads to the same debt.
    owed = "gvar('ml_order_owed') == 1"
    put_sequences(mod_dir / QUESTS / "ml_work/nebakovObrana/ml_casual_dialog.xml", "dec_open", "seq_work_debt", debt_sequences("work", owed, data["debts"]), 9)
    put_sequences(mod_dir / QUESTS / "ml_work/zavodniPodkovy/ml_work_dialog.xml", "dec_job_debt", "seq_job_debt", debt_sequences("job", owed, data["debts"]), 9)


def write_tokens(mod_dir, data, orders):
    rows = "\t\t<!-- Tell the journal that an order was taken, done or run out. Generated by tools/generate_orders.py. -->\n"
    named = [(f"ml_order_{o['code']}_{t}", g) for o in orders for t, g in o["tokens"].items()]
    named += [(f"ml_order_{b['key']}_{t}", g) for b in data["business"] for t, g in b["tokens"].items()]
    for name, g in named:
        rows += (f'\t\t<MiscItem Type="5" SubType="0" IsDivisible="true" IconId="{g}" UIInfo="ui_in_ml_state" UIName="ui_nm_ml_state" '
                 f'Model="manmade/common_furniture/sacks/sack_items/sack_items.cgf" Weight="0" Price="0" FadeCoef="1" VisibilityCoef="1" '
                 f'Id="{g}" Name="{name}" />\n')

    def change(text):
        # Any tool name: the comment written under the earlier name of this script must go too.
        text = re.sub(r"\t\t<!-- Tell the journal that an order was taken, done or run out\. Generated by tools/\w+\.py\. -->\n", "", text)
        text = re.sub(r'\t\t<MiscItem [^\n]*Name="ml_order_[a-z_0-9]+" />\n', "", text)
        if text.count("\t</ItemClasses>") != 1:
            raise SystemExit("item__medieval_life.xml: cannot find the end of ItemClasses")
        return text.replace("\t</ItemClasses>", rows + "\t</ItemClasses>")

    edit(mod_dir / "data/Libs/Tables/item/item__medieval_life.xml", change)


def write_slips(mod_dir, data):
    """The slips of each business and turn: documents like ml_errand_slip, with the name of the business, so
    that they do not stack in the inventory and each one can be read. They go between two markers in item__medieval_life.xml."""
    rows = ""
    for b in data["business"]:
        for turn, g in b["slips"].items():
            rows += (f'\t\t<Document Type="5" VisualCategory="1" IconId="letter_simple" UIInfo="ui_in_ml_errand_slip" '
                     f'UIName="ml_order_slipname_{b["key"]}_{turn}" Model="characters/assets/parchment_folded/parchment_folded.cdf" '
                     f'EntityScript="Book" Weight="0.01" Price="0" FadeCoef="2.666667" VisibilityCoef="0.707106769" Id="{g}" '
                     f'Name="ml_order_slip_{b["key"]}_{turn}">\n\t\t\t<DocumentContent Parts="ml_book_blank" />\n\t\t</Document>\n')
    start, end = "\t\t<!-- generated slips: start -->\n", "\t\t<!-- generated slips: end -->\n"

    def change(text):
        if start in text:
            text = text[:text.index(start)] + text[text.index(end) + len(end):]
        anchor = "\t\t<!-- What is owed for errands, a tenth of a groschen each"
        if text.count(anchor) != 1:
            raise SystemExit("item__medieval_life.xml: cannot find where to put the slips")
        return text.replace(anchor, start + rows + end + anchor)

    edit(mod_dir / "data/Libs/Tables/item/item__medieval_life.xml", change)


def write_text(mod_dir, data, orders):
    for column, (folder, language) in enumerate(LANGUAGES):
        rows = {key: pair[column] for key, pair in TEXTS.items()}
        for days in range(2, data["days_between"] + 1):
            rows[f"ml_order_wait_{days}"] = WAIT[column].format(days=days)
        for groschen in data["debts"]:
            rows[f"ml_order_debt_{groschen}"] = DEBT[column].format(groschen=groschen)
        for business in data["business"]:
            rows[f"qname_ml_order_{business['key']}"] = business["titles"][column]
            rows[f"ml_order_{business['key']}_back"] = business["back"][column]
            rows[f"ml_order_name_{business['key']}"] = data["names"][business["key"]][column]
            for turn, names in business["slip_names"].items():
                rows[f"ml_order_slipname_{business['key']}_{turn}"] = names[column]
        for town, names in data["town_names"].items():
            rows[f"ml_order_town_{town}"] = names[column]
        for business in data["business"]:
            for n, goods in enumerate(business["needs"], 1):
                rows[f"ml_order_goods_{business['key']}_{n}"] = goods[language]
        for o in orders:
            base = f"ml_order_{o['code']}"
            for field, key in (("objective", f"{base}_objective"), ("pick", f"{base}_pick"), ("back", f"{base}_back")):
                if f"{field}_{language}" in o:
                    rows[key] = o[f"{field}_{language}"]
        for key, pair in data["said"].items():
            rows[key] = pair[column]
        lines = "".join(f"  <Row><Cell>{k}</Cell><Cell>{k}</Cell><Cell>{escape(v)}</Cell></Row>\n" for k, v in rows.items())

        def change(text):
            text = re.sub(r"  <Row><Cell>(?:ui_|qname_|qdesc_)?ml_order(?:_[a-z_0-9]*)?</Cell>[^\n]*\n", "", text)
            if text.count("</Table>") != 1:
                raise SystemExit(f"{folder}: cannot find the end of the table")
            return text.replace("</Table>", lines + "</Table>")

        edit(mod_dir / "localization" / folder / "text__medieval_life.xml", change)


def main(mod_dir):
    data, orders = load(mod_dir)
    keys = [b["key"] for b in data["business"]]
    write_lua(mod_dir, data, orders)
    for key in keys:
        write_quest(mod_dir, data["by_key"][key], [o for o in orders if o["business"] == key], data["souls"])
    write_level(mod_dir, keys)
    write_dialog(mod_dir, data, orders)
    write_tokens(mod_dir, data, orders)
    write_slips(mod_dir, data)
    write_text(mod_dir, data, orders)
    print(f"{len(keys)} businesses, {len(orders)} orders")


if __name__ == "__main__":
    main((ROOT / sys.argv[1]).resolve())

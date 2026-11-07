"""Generates what the mod needs from the jobs out of a single file.

Reads mod/medieval_life/jobs.toml and writes:

- Scripts/MedievalLife/jobs_data.lua: sites, pay and experience, and the bed of each rental of the game, from the level.
- Libs/Storm/roles/medieval_life.xml: the rule that gives the role role_ml_employer to each NPC.
- localization/*_xml/text__medieval_life.xml: the text of the clock and the one of the book of trades for each site, and
  one summary line per combination of skills and hours, in English and Spanish. The names of the skills
  come from the game.
- data/Quests/Final/Barbora/utils/roomrenting/: copies of the game's four dialogs of room rental, with their options only
  for Henry. They come from the game of whoever builds and are not versioned.

Looks up every NPC and skill in the game tables and stops if they do not exist.
tools/install_mod.py runs it before packing.

Usage: python -I mod/medieval_life/tools/generate_jobs.py mod/medieval_life
"""
import hashlib
import math
import os
import pathlib
import re
import sys
import tomllib
import zipfile

# The repository: this file is in mod/medieval_life/tools/.
ROOT = pathlib.Path(__file__).resolve().parents[3]
TABLES = ROOT / "game_files/Tables.pak/Libs/Tables/rpg"
# KCD2_GAME, or the game in the default Steam library, or in the maintainer's.
GAME_PLACES = (r"C:\Program Files (x86)\Steam\steamapps\common\KingdomComeDeliverance2", r"E:\SteamLibrary\steamapps\common\KingdomComeDeliverance2")
GAME = pathlib.Path(os.environ.get("KCD2_GAME") or next((p for p in GAME_PLACES if os.path.isfile(os.path.join(p, "Data", "Tables.pak"))), GAME_PLACES[0]))
LANGUAGES = (("English_xml", "en"), ("Spanish_xml", "es"))
SUMMARY = {
    "English_xml": "Worked {hours} h at {wage} g/h: +{pay} g. {main} +{xp_main} XP, {secondary} +{xp_secondary} XP.",
    "Spanish_xml": "Trabajaste {hours} h a {wage} g/h: +{pay} g. {main} +{xp_main} XP, {secondary} +{xp_secondary} XP.",
}
DECIMAL = {"English_xml": ".", "Spanish_xml": ","}
GLOBALS = ("wage", "xp_main", "xp_secondary", "first_hour", "last_hour", "min_hours", "role_en", "role_es",
           "steady_wage", "steady_work_days", "steady_days_off", "steady_min_hours", "steady_hire_last_hour", "steady_late_minutes", "steady_faults", "steady_fault_days",
           "steady_rehire_quit_days", "steady_rehire_fired_days", "steady_area", "steady_meal", "steady_role_en", "steady_role_es",
           "casual_meal", "casual_meal_min_hours", "casual_meal_health", "casual_meal_fresh",
           "casual_min_reputation", "steady_min_reputation", "rent_until_hour", "rent_week_days", "rent_week_paid_nights", "rent_area")


def read(path):
    return path.read_text("utf-8-sig", errors="replace")


def souls():
    names = set()
    for path in TABLES.glob("soul*.xml"):
        names.update(re.findall(r'soul_name="([^"]+)"', read(path)))
    return names


def fail(site, message):
    raise SystemExit(f"jobs.toml, {site.get('key', '?')}: {message}")


# What the story of Henry must have in the world for a site to be offered (story.lua).
REQUIRES = {"castle", "semine", "semine_manor"}


def check(data):
    for field in GLOBALS:
        if field not in data:
            raise SystemExit(f"jobs.toml: missing {field}")
    known_souls = souls()
    known_skills = set(re.findall(r'skill_name="([^"]+)"', read(TABLES / "skill.xml")))
    known_stats = set(re.findall(r'stat_name="([^"]+)"', read(TABLES / "stat.xml")))
    sites = data.get("site", [])
    keys = [s.get("key") for s in sites]
    if len(set(keys)) != len(keys):
        raise SystemExit("jobs.toml: two sites have the same key")
    for site in sites:
        for field in ("key", "npcs", "name_en", "name_es", "place_en", "place_es", "main", "secondary"):
            if field not in site:
                fail(site, f"missing {field}")
        if not re.fullmatch(r"[a-z_]+", site["key"]):
            fail(site, "the key must be lowercase")
        for npc in site["npcs"]:
            if npc not in known_souls:
                fail(site, f"NPC {npc} does not exist")
        for field in ("main", "secondary"):
            if site[field] not in known_skills | known_stats:
                fail(site, f"{field}: {site[field]} does not exist")
        if site.get("requires", "castle") not in REQUIRES:
            fail(site, f"requires must be one of {sorted(REQUIRES)}")
        hours = site.get("hours", [data["first_hour"], data["last_hour"]])
        if len(hours) != 2 or not all(isinstance(h, int) for h in hours) or not 0 <= hours[0] < hours[1] <= 24 \
                or hours[1] - hours[0] < data["min_hours"]:
            fail(site, "hours must be [first, last], whole hours of one day, at least min_hours apart")
    return sites, known_stats


def food():
    found = {}
    for path in (TABLES.parent / "item").glob("item*.xml"):
        for row in re.findall(r"<Food [^>]*>", read(path)):
            item = dict(re.findall(r'(\w+)="([^"]*)"', row))
            found[item.get("Name")] = item
    return found


def rent_places(sites):
    """The bed of each rental of the game, from the level: the smart object where the character lies, its prompt
    (BedTrigger) and the door of the room, if it has one. Once rented, the bed of the game is Henry's, so rent.lua hides
    its prompt and puts the mod's own bed in its place, unseen, on the same mattress."""
    wanted = {s["rent"]: s for s in sites if "rent" in s}
    if not wanted:
        return {}
    pak = zipfile.ZipFile(GAME / "Data/Levels/trosecko/level.pak")
    text = pak.read(pak.getinfo("objects_mission0.xml")).decode("utf-8", errors="replace")
    entities = {m.group(1): m.group(0) for m in re.finditer(r'<Entity [^>]*?EntityId="(\d+)"[^>]*>.*?</Entity>', text, re.S)}

    def attr(entity, name, default=""):
        found = re.search(r'\b' + name + r'="([^"]*)"', entity)
        return found.group(1) if found else default

    def links(entity):
        return {name.replace("&apos;", "'"): target for target, name in re.findall(r'<Link TargetId="(\d+)"[^>]*Name="([^"]*)"', entity)}

    def place(entity):
        x, y, z = (float(n) for n in attr(entity, "Pos").split(","))
        w, _, _, qz = (float(n) for n in attr(entity, "Rotate", "1,0,0,0").split(","))
        return {"x": round(x, 3), "y": round(y, 3), "z": round(z, 3), "yaw": round(2 * math.atan2(qz, w), 4)}

    found = {}
    for holder, site in wanted.items():
        entity = next((e for e in entities.values() if attr(e, "Name") == holder and attr(e, "EntityClass") == "SmartObjectHolder"), None)
        if not entity:
            fail(site, f"rent: the level has no SmartObjectHolder {holder}")
        link = links(entity)
        bed = entities.get(link.get("asset['bed']") or link.get("bed", ""), "")
        if attr(bed, "EntityClass") != "StanceSmartObject":
            fail(site, f"rent: {holder} has no bed")
        prompt = entities.get(links(bed).get("mTrigger", ""), "")
        if attr(prompt, "EntityClass") != "BedTrigger":
            fail(site, f"rent: the bed of {holder} has no BedTrigger")
        door = entities.get(link.get("asset['dvere']", ""), "")
        # How the bed of the game is used. A low bed lies on a click. A high bed, as in Zhelejov and the smithy of
        # Tachov, sits on a click and lies on a hold: its smart object has no way to lie down from standing.
        click = re.search(r"<Click\b[^>]*>", prompt).group(0) if "<Click" in prompt else ""
        hold = re.search(r"<Hold\b[^>]*>", prompt).group(0) if "<Hold" in prompt else ""
        if attr(click, "sAction") == "lying":
            sit = False
        elif attr(hold, "sAction") == "lying" and attr(click, "sAction") in ("", "sitting"):
            sit = True
        else:
            fail(site, f"rent: the BedTrigger of {holder} lies neither on a click nor on a hold")
        found[site["key"]] = {
            "price": round(site["rent_price"] * 10),
            "price_economy": round(site["rent_price_economy"] * 10) if "rent_price_economy" in site else 0,
            # The mark of the bed on the map and the compass: the game shows it while the bed is the character's, and the mod
            # takes the others off. Its id is the EntityGuid of the bed and "BED POI" in bytes, as in whdata_0.
            "mark": attr(bed, "EntityGuid") + "-4245-4420504f4900",
            # Its name: a high bed uses the smart object of the game.
            "object": dict(place(bed), name=attr(bed, "Name"), helpers=attr(bed, "soclass_SmartObjectHelpers"), type=attr(bed, "guidSmartObjectType"),
                           bed=attr(bed, "esBedTypes"), sleep=attr(bed, "esSleepQuality"), reading=attr(bed, "esReadingQuality")),
            "trigger": dict(place(prompt), name=attr(prompt, "Name"), scale=round(float(attr(prompt, "Scale", "1,1,1").split(",")[0]), 3),
                            **({"sit": True} if sit else {})),
            "door": attr(door, "Name") if door else "",
        }
    return found


def write_lua(mod_dir, data, sites, stats):
    def flag(name):
        return "true" if name in stats else "false"

    def bed(site):
        if "bed" not in site:
            return ""
        return "\n		bed = { " + ", ".join(str(n) for n in site["bed"]) + " },"

    def requires(site):
        return f'\n		requires = "{site["requires"]}",' if "requires" in site else ""

    places = rent_places(sites)

    def lua_table(values):
        def lua(v):
            if isinstance(v, bool):
                return "true" if v else "false"
            return f'"{v}"' if isinstance(v, str) else str(v)
        return "{ " + ", ".join(f"{k} = {lua(v)}" for k, v in values.items()) + " }"

    def rent(site):
        if site["key"] not in places:
            return ""
        r = places[site["key"]]
        door = f'\n			door = "{r["door"]}",' if r["door"] else ""
        door += f'\n			price_economy = {r["price_economy"]},' if r["price_economy"] else ""
        return (f'\n		rent = {{\n			price = {r["price"]},\n			mark = "{r["mark"]}",\n			object = {lua_table(r["object"])},\n'
                f'			trigger = {lua_table(r["trigger"])},{door}\n		}},')

    def hours(site):
        if "hours" not in site:
            return ""
        return f'\n		first_hour = {site["hours"][0]},\n		last_hour = {site["hours"][1]},'

    items = food()

    def meal(field, health):
        for name in data[field]:
            if name not in items:
                raise SystemExit(f"jobs.toml, {field}: {name} does not exist")
        print(f"{field}:", sum(float(items[name]["NutritionBenefit"]) for name in data[field]))
        return ", ".join(f'{{ "{items[name]["Id"]}", {health(name)} }}' for name in data[field])

    steady_meal = meal("steady_meal", lambda name: 1)
    casual_meal = meal("casual_meal", lambda name: 1 if name in data["casual_meal_fresh"] else data["casual_meal_health"])
    rows = "".join(f'''	{{
		key = "{s["key"]}",
		npcs = {{ {", ".join(f'"{n}"' for n in s["npcs"])} }},
		text = "@ml_job_{s["key"]}",
		main = "{s["main"]}",
		main_is_stat = {flag(s["main"])},
		secondary = "{s["secondary"]}",
		secondary_is_stat = {flag(s["secondary"])},
		summary = "@ml_work_done_{s["main"]}_{s["secondary"]}_",
		main_text = "@{game_key(s["main"])}",
		secondary_text = "@{game_key(s["secondary"])}",
		steady = {"true" if s.get("steady") else "false"},
		steady_summary = "@ml_shift_done_{s["main"]}_{s["secondary"]}_",{bed(s)}{requires(s)}{hours(s)}{rent(s)}
	}},
''' for s in sites)
    path = mod_dir / "data/Scripts/MedievalLife/jobs_data.lua"
    path.write_bytes(f'''-- Generated by tools/generate_jobs.py from mod/medieval_life/jobs.toml. Edit that file, not this one.
-- wage is in tenths of a groschen per hour.
MedievalLife.JOB_RULES = {{
	wage = {round(data["wage"] * 10)},
	xp_main = {data["xp_main"]},
	xp_secondary = {data["xp_secondary"]},
	first_hour = {data["first_hour"]},
	last_hour = {data["last_hour"]},
	min_hours = {data["min_hours"]},
	steady_wage = {round(data["steady_wage"] * 10)},
	steady_work_days = {data["steady_work_days"]},
	steady_days_off = {data["steady_days_off"]},
	steady_min_hours = {data["steady_min_hours"]},
	steady_hire_last_hour = {data["steady_hire_last_hour"]},
	steady_late_minutes = {data["steady_late_minutes"]},
	steady_faults = {data["steady_faults"]},
	steady_fault_days = {data["steady_fault_days"]},
	steady_rehire_quit_days = {data["steady_rehire_quit_days"]},
	steady_rehire_fired_days = {data["steady_rehire_fired_days"]},
	steady_area = {data["steady_area"]},
	casual_min_reputation = {data["casual_min_reputation"]},
	steady_min_reputation = {data["steady_min_reputation"]},
	rent_until_hour = {data["rent_until_hour"]},
	rent_week_days = {data["rent_week_days"]},
	rent_week_paid_nights = {data["rent_week_paid_nights"]},
	rent_area = {data["rent_area"]},
	steady_meal = {{ {steady_meal} }},
	casual_meal = {{ {casual_meal} }},
	casual_meal_min_hours = {data["casual_meal_min_hours"]},
	-- The amounts with a key of their own for the summary with settings: ml_work_pay_<tenths>, ml_work_rate_<hundredths>
	-- and ml_work_xp_<points>.
	summary_pay_max = {custom_limits(data, sites)[0]},
	summary_rate_max = {custom_limits(data, sites)[1]},
	summary_xp_max = {custom_limits(data, sites)[2]},
}}
MedievalLife.JOB_SITES = {{
{rows}}}
'''.encode("utf-8"))


def edit(path, change):
    raw = path.read_bytes().decode("utf-8")
    crlf = "\r\n" in raw
    text = change(raw.replace("\r\n", "\n"))
    path.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))


def write_storm(mod_dir, sites):
    names = "".join(f'					<hasName name="{npc}" />\n' for site in sites for npc in site["npcs"])
    rule = ('		<rule name="ml_employers">\n			<selectors>\n				<or>\n' + names +
            '				</or>\n			</selectors>\n			<operations>\n				<addRole name="role_ml_employer" />\n			</operations>\n		</rule>\n')

    def change(text):
        text, count = re.subn(r'\t\t<rule name="ml_employers">.*?</rule>\n', lambda _: rule, text, flags=re.S)
        if count != 1:
            raise SystemExit("roles/medieval_life.xml: cannot find the rule ml_employers")
        return text

    edit(mod_dir / "data/Libs/Storm/roles/medieval_life.xml", change)


SKILL_KEYS = {}


def game_key(name):
    """The key of the text of a skill or a stat in the game. skill.xml gives the one of each skill: the one of
    horse_riding is ui_skill_horse_whispering. jobs.lua puts it in the summary of work when the settings change the pay."""
    if not SKILL_KEYS:
        SKILL_KEYS.update(re.findall(r'skill_name="([^"]+)"[^>]*ui_string_name="([^"]+)"', read(TABLES / "skill.xml")))
    return SKILL_KEYS.get(name, f"ui_stat_{name}")


def game_names(folder):
    """The names of the skills and stats, as the game shows them."""
    pak = zipfile.ZipFile(GAME / "Localization" / f"{folder}.pak")
    text = pak.read("text_ui_soul.xml").decode("utf-8", "replace")
    rows = dict(re.findall(r"<Row><Cell>(ui_(?:skill|stat)_[a-z_]+)</Cell><Cell>[^<]*</Cell><Cell>([^<]*)</Cell></Row>", text))
    return lambda name: rows[game_key(name)]


def summaries(data, sites, folder):
    """One row per combination and duration: Lua cannot build translated text."""
    name_of, rows = game_names(folder), {}
    point = DECIMAL[folder]

    factor = data["economy_factor"]

    def amount(value):
        return f"{value:.2f}".rstrip("0").rstrip(".").replace(".", point)

    def add(prefix, site, wage, first_hours):
        main, secondary = site["main"], site["secondary"]
        for hours in range(first_hours, data["last_hour"] - data["first_hour"] + 1):
            key = f"{prefix}_{main}_{secondary}_{hours}"
            fields = dict(hours=hours, main=name_of(main), xp_main=hours * data["xp_main"],
                          secondary=name_of(secondary), xp_secondary=hours * data["xp_secondary"])
            # Amounts without trailing zeros, as the economy line and the line of the settings: "+9 g.", not "+9.0 g.".
            rows[key] = SUMMARY[folder].format(wage=amount(wage), pay=amount(wage * hours), **fields)
            # With an economy mod, what it pays, as economy.lua rounds it: jobs.lua adds _economy.
            tenths = math.floor(round(wage * 10) * hours * factor + 0.5)
            rows[key + "_economy"] = SUMMARY[folder].format(wage=amount(wage * factor), pay=amount(tenths / 10), **fields)

    for site in sites:
        add("ml_work_done", site, data["wage"], data["min_hours"])
        if site.get("steady"):
            add("ml_shift_done", site, data["steady_wage"], data["steady_min_hours"])
    return "".join(f"  <Row><Cell>{key}</Cell><Cell>{key}</Cell><Cell>{text}</Cell></Row>\n" for key, text in rows.items())


# The steps of the pay and the experience in the settings, 25 to 300 % (the sliders of settings.lua).
PAY_PERCENTS = range(25, 301, 25)
SETTINGS_FACTOR_MAX = max(PAY_PERCENTS) / 100
# What the summary with settings says after the hours: the wage, as the usual line says it.
RATE = {"English_xml": "h at {wage} g/h:", "Spanish_xml": "h a {wage} g/h:"}


def custom_limits(data, sites):
    """The highest pay, in tenths of a groschen, wage per hour, in hundredths, and experience of one stretch of work with
    the settings at their top."""
    hours = max([data["last_hour"] - data["first_hour"]] + [s["hours"][1] - s["hours"][0] for s in sites if "hours" in s])
    wage = max(data["wage"], data["steady_wage"])
    pay = math.ceil(hours * wage * 10 * SETTINGS_FACTOR_MAX)
    rate = math.ceil(wage * 100 * SETTINGS_FACTOR_MAX)
    xp = math.ceil(hours * max(data["xp_main"], data["xp_secondary"]) * SETTINGS_FACTOR_MAX)
    return pay, rate, xp


def steady_rates(data):
    """The wages per hour of the steady job, in hundredths, that the pay of the settings gives, with and without the
    economy mod, as jobs.lua works them out (Jobs.Rate). The terms of the job have one text for each."""
    tenths = round(data["steady_wage"] * 10)
    return sorted({math.floor(tenths * 10 * percent / 100 * factor + 0.5)
                   for percent in PAY_PERCENTS for factor in (1, data["economy_factor"])})


def plain(value, point):
    """An amount without trailing zeros, as the summaries say it."""
    return f"{value:.2f}".rstrip("0").rstrip(".").replace(".", point)


def custom_pieces(data, sites, folder, text):
    """The summary with the pay or the experience of the settings is built in jobs.lua. SendInfoText keeps only keys and
    whole numbers, so each amount is a key: "h at 0.9 g/h:" for the wage, "+1.8 g." for the pay, "+6 XP," for the
    first skill and "+2 XP." for the last one. And the terms of the steady job, one per wage that the
    settings give, from the usual one with its wage changed."""
    point = DECIMAL[folder]
    pay_max, rate_max, xp_max = custom_limits(data, sites)
    rows = {}
    for hundredths in range(rate_max + 1):
        rows[f"ml_work_rate_{hundredths}"] = RATE[folder].format(wage=plain(hundredths / 100, point))
    for tenths in range(pay_max + 1):
        rows[f"ml_work_pay_{tenths}"] = f"+{plain(tenths / 10, point)} g."
    for xp in range(xp_max + 1):
        rows[f"ml_work_xp_{xp}"] = f"+{xp} XP,"
        rows[f"ml_work_xp_last_{xp}"] = f"+{xp} XP."
    terms = re.search(r"<Row><Cell>ml_steady_terms</Cell><Cell>ml_steady_terms</Cell><Cell>([^<]*)</Cell></Row>", text)
    usual = plain(data["steady_wage"], point) + " groschen"
    if not terms or terms.group(1).count(usual) != 1:
        raise SystemExit(f"{folder}: ml_steady_terms does not say its wage as '{usual}' once")
    for hundredths in steady_rates(data):
        rows[f"ml_steady_terms_wage_{hundredths}"] = terms.group(1).replace(usual, plain(hundredths / 100, point) + " groschen")
    return "".join(f"  <Row><Cell>{key}</Cell><Cell>{key}</Cell><Cell>{text}</Cell></Row>\n" for key, text in rows.items())


# The terms of the steady job with the pay of the settings, one sequence per wage, between two marks.
TERMS_DIALOG = "data/Quests/medieval_life/trosecko/ml_work/zavodniPodkovy/ml_work_dialog.xml"
TERMS_MARKS = (6 * '\t' + '<!-- BEGIN terms with the settings -->\n', 6 * '\t' + '<!-- END terms with the settings -->\n')
TERMS_SEQUENCE = """						<Sequence EntryCondition="gvar('ml_job_offer') == 1 &amp; gvar('ml_work_pay_custom') == 1 &amp; gvar('ml_work_wage') == {n}" EndType="GoTo" GoToDecision="dec_job" Name="seq_job_ask_wage_{n}">
							<UiPrompt StringName="ui_ml_job_ask" />
							<Elements>
								<Response Role="HENRY" ReferenceLength="2.73">
									<Text StringName="cele_henry_hledam_praci_n_SI9N" />
								</Response>
								<Response Role="role_ml_employer">
									<Text StringName="ml_steady_terms_wage_{n}" />
								</Response>
							</Elements>
						</Sequence>
"""


def write_terms_dialog(mod_dir, data):
    def change(text):
        begin, end = TERMS_MARKS
        if text.count(begin) != 1 or text.count(end) != 1:
            raise SystemExit(f"{TERMS_DIALOG}: the marks of the terms with the settings are missing")
        head, rest = text.split(begin)
        _, tail = rest.split(end)
        return head + begin + "".join(TERMS_SEQUENCE.format(n=n) for n in steady_rates(data)) + end + tail

    edit(mod_dir / TERMS_DIALOG, change)


def write_text(mod_dir, data, sites):
    for folder, language in LANGUAGES:
        def change(text):
            text = re.sub(r"  <Row><Cell>ml_job_[a-z_]+</Cell>[^\n]*\n", "", text)
            text = re.sub(r"  <Row><Cell>ml_book_(?:place_[a-z_]+|role|steady_role)</Cell>[^\n]*\n", "", text)
            text = re.sub(r"  <Row><Cell>ml_(?:work|shift)_done_[a-z_0-9]+</Cell>[^\n]*\n", "", text)
            text = re.sub(r"  <Row><Cell>ml_work_(?:rate|pay|xp|xp_last)_[0-9]+</Cell>[^\n]*\n", "", text)
            text = re.sub(r"  <Row><Cell>ml_steady_terms_wage_[0-9]+</Cell>[^\n]*\n", "", text)
            rows = "".join(f"  <Row><Cell>ml_job_{s['key']}</Cell><Cell>ml_job_{s['key']}</Cell><Cell>{s['name_' + language]}</Cell></Row>\n" for s in sites)
            rows += "".join(f"  <Row><Cell>ml_book_place_{s['key']}</Cell><Cell>ml_book_place_{s['key']}</Cell><Cell>{s['place_' + language]}</Cell></Row>\n" for s in sites)
            rows += f"  <Row><Cell>ml_book_role</Cell><Cell>ml_book_role</Cell><Cell>{data['role_' + language]}</Cell></Row>\n"
            rows += f"  <Row><Cell>ml_book_steady_role</Cell><Cell>ml_book_steady_role</Cell><Cell>{data['steady_role_' + language]}</Cell></Row>\n"
            rows += summaries(data, sites, folder)
            rows += custom_pieces(data, sites, folder, text)
            if text.count("</Table>") != 1:
                raise SystemExit(f"{folder}: cannot find the end of the table")
            return text.replace("</Table>", rows + "</Table>")

        edit(mod_dir / "localization" / folder / "text__medieval_life.xml", change)


# The game's room rental, in four dialogs: for one night (roomrentonenight) and the room of Zhelejov (roomrent), each with
# an innkeeper man and woman. They give the bed to Henry, so the new character rents with the option of the mod,
# and the game's options show only while Henry plays. Each dialog has two root options, right under its first
# decision: "Can I spend the night here?" and staying from time to time, or a room and board and a room for good. A file
# of the mod with the same path replaces the game's one, as the barber of the frameworks does.
RENT_DIALOGS = {
    "Quests/Final/Barbora/utils/roomrenting/roomrentonenight/muz_pronajem_onenight_save.xml": "3ccee3983ed36a913bc70c7935938b58be17843ee2ef82fb0e975a0031282ed7",
    "Quests/Final/Barbora/utils/roomrenting/roomrentonenight/zena_pronajem_onenight_save.xml": "c8968a367cadffb915296ce8606038c68b348e54d4a53bdb67ee6bbb6c279d11",
    "Quests/Final/Barbora/utils/roomrenting/roomrent/muz_v_hostinci_pronajem.xml": "66e5ed242ea63078a49faeeb263e181913b94837d516b51faeb8d965c7615de7",
    "Quests/Final/Barbora/utils/roomrenting/roomrent/zena_v_hostinci_pronajem.xml": "8c7d7e16563e19fa6ba3e195c441d3ecbc3a0246e57fcb6a69f8e1a0bf57baff",
}
RENT_ROOT_OPTIONS = 2
# life.lua sets it to 1 on every tick while the new character plays, and to 0 while Henry plays or after ml_uninstall.
HENRY_ONLY = " AND gvar('ml_new_life') != 1"


def write_rent_dialogs(mod_dir):
    """The hashes are those of game 1.5.6. If an update changes a dialog, the old copy would hide the change, so the tool
    stops until someone reads the new file and updates its hash."""
    with zipfile.ZipFile(GAME / "Data" / "Scripts.pak") as z:
        for path, sha in RENT_DIALOGS.items():
            raw = z.read(path)
            found = hashlib.sha256(raw).hexdigest()
            if found != sha:
                raise SystemExit(f"{path} changed in the game (sha256 {found}). Check its root options, then update RENT_DIALOGS.")
            text = raw.decode("utf-8-sig")
            roots = re.findall(r'\n\t{6}<Sequence EntryCondition="([^"]*)"', text)
            if len(roots) != RENT_ROOT_OPTIONS:
                raise SystemExit(f"{path}: {len(roots)} root options, not {RENT_ROOT_OPTIONS}. Did the game change?")
            for condition in roots:
                old = f'EntryCondition="{condition}"'
                if text.count(old) != 1:
                    raise SystemExit(f"{path}: {old} not found exactly once. Did the game change?")
                text = text.replace(old, f'EntryCondition="{condition}{HENRY_ONLY}"')
            dest = mod_dir / "data" / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(text, encoding="utf-8-sig", newline="")


# Buying a horse: the game asks the horse trader about the soul of Henry, alias player, for the horse the buyer
# already has, the charisma for haggling, the money to pay, and who gets the saddle and the bridle. So the new
# character heard "you already have one" for Henry's horse, and could not pay with their own money. These copies ask
# player_any, whoever plays: Henry while he plays, as before. The washing of horses, which Realish Economy replaces, is
# left alone. With the sha256 of game 1.5.6 and how many player aliases each has.
HORSE_COPIES = {
    "Quests/Final/Barbora/trosecko/nakup_koni__trosecko/horse_trader_semin.xml": ("f51676cf373b877fed51871acaf1608dedc3473baf286d4a73121c1cc207e2cc", 3),
    "Quests/Final/Barbora/trosecko/nakup_koni__trosecko/horse_trader_semin/sedivka_focus_cam.xml": ("17626afd6f1c24d661817911eabc33517b06fd49cb136da55c25a66fc47508c1", 2),
    "Quests/Final/Barbora/trosecko/nakup_koni__trosecko/horse_handler_trosecko.xml": ("2b46a208562329816565cc0c9fe478cf7567771c9a7dadc062d410cae56453d8", 1),
    "Quests/Final/Barbora/kutnohorsko/nakup_koni__kutnohorsko/horse_trader_kutna_hora.xml": ("8c6a2d0284af487b1aa7fbfef8ab94b459abf14aec18cf9db1b22f71934edf55", 1),
    "Quests/Final/Barbora/utils/horsebuying_utils/horsebuying_payment.xml": ("fb277591381ad7c73dd25cc1923202e3d8d9c50ff24c1cbb6f1c2ad5227d1ea0", 1),
    "Quests/Final/Barbora/utils/horsebuying_utils/HorseBuying_StartingEquip.xml": ("40630e0c92e1afbed628eddeea993c456b2d2c65d4b696e9a523a52672340c06", 1),
    "Quests/Final/Barbora/utils/horsebuying_utils/horseinstance.xml": ("8ffffd9da29dce6a53f748fe407179af5e90b203b278cca9c51edbc17a13d37d", 1),
    "Quests/Final/Barbora/utils/horsebuying_utils/horsebuying_transactionscene.xml": ("67960ab67013e1d37e1a6f487a15ea517e05445c04c70f5ede8bf9df7f838ed8", 2),
}
PLAYER_ALIAS, PLAYING_ALIAS = 'Alias="player"', 'Alias="player_any"'


def write_horse_copies(mod_dir):
    """As the rent dialogs: if an update changes one of the files, the tool stops until someone reads it again."""
    with zipfile.ZipFile(GAME / "Data" / "Scripts.pak") as z:
        for path, (sha, aliases) in HORSE_COPIES.items():
            raw = z.read(path)
            found = hashlib.sha256(raw).hexdigest()
            if found != sha:
                raise SystemExit(f"{path} changed in the game (sha256 {found}). Check its player aliases, then update HORSE_COPIES.")
            text = raw.decode("utf-8-sig")
            if text.count(PLAYER_ALIAS) != aliases:
                raise SystemExit(f"{path}: {text.count(PLAYER_ALIAS)} player aliases, not {aliases}. Did the game change?")
            dest = mod_dir / "data" / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(text.replace(PLAYER_ALIAS, PLAYING_ALIAS), encoding="utf-8-sig", newline="")


def main(mod_dir):
    data = tomllib.loads((mod_dir / "jobs.toml").read_text("utf-8"))
    # The economy mod that the pay follows (economy.toml): the summaries of work say its amounts too.
    data["economy_factor"] = tomllib.loads((mod_dir / "economy.toml").read_text("utf-8"))["realish"]["price_factor"]
    sites, stats = check(data)
    write_lua(mod_dir, data, sites, stats)
    write_storm(mod_dir, sites)
    write_text(mod_dir, data, sites)
    write_terms_dialog(mod_dir, data)
    write_rent_dialogs(mod_dir)
    write_horse_copies(mod_dir)
    print(f"{len(sites)} sites, {len(RENT_DIALOGS)} rent dialogs of the game for Henry only, "
          f"{len(HORSE_COPIES)} horse buying files of the game for whoever plays")


if __name__ == "__main__":
    main((ROOT / sys.argv[1]).resolve())

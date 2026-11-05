"""Generates everything the mod needs from the origins out of a single file.

Reads mod/medieval_life/origins.toml and writes:

- Scripts/MedievalLife/origins_data.lua: money, clothes, weapon, experience and items.
- Quests/.../ml_selector.xml: one option per origin, for man and for woman.
- Quests/.../ml_weapons.xml and one token per origin in the item table: Skald equips the weapon of each one.
- localization/*_xml/text__medieval_life.xml: the name of each origin, in English and Spanish.

Looks up every name in the game tables and stops if it does not exist or is not of the requested gender.
tools/install_mod.py runs it before packing.

Usage: python -I mod/medieval_life/tools/generate_origins.py mod/medieval_life
"""
import pathlib
import re
import sys
import tomllib
import uuid

# The repository: this file is in mod/medieval_life/tools/.
ROOT = pathlib.Path(__file__).resolve().parents[3]
TABLES = ROOT / "game_files/Tables.pak/Libs/Tables"
GENDERS = ("man", "woman")
LANGUAGES = (("English_xml", "name_en"), ("Spanish_xml", "name_es"))
# A level asks for 80 XP and each next one 30 more.
XP_FIRST, XP_STEP = 80, 30
MAX_LEVEL = 30
# From the end of the switch: the black screen goes by.
WIELD_AGAIN = "15s"
WIELD_MARK = "		<!-- Tokens that ask Skald for the weapon of each origin, generated from origins.toml. They only stay for a moment. -->\n"
# The quality comes from the health of the item. It is the top of each band.
QUALITY_HEALTH = {1: 0.1, 2: 0.3, 3: 0.6}
# What quality_basic reaches, besides the weapon: the tunic or the dress, and the hose.
BASIC_CLOTHES = re.compile(r"Tunic|Hose|F_SimpleDress|F_Cotehardie|F_Surcote")


def read(path):
    return path.read_text("utf-8-sig", errors="replace")


def clothing_presets():
    text = read(TABLES / "item/clothing_preset.xml")
    rows = re.findall(r'<clothing_preset clothing_preset_id="([^"]+)" clothing_preset_name="([^"]+)" gender="([^"]+)"[^>]*(?<!/)>(.*?)</clothing_preset>', text, re.S)
    return {name: (guid, gender, re.findall(r"<Guid>([^<]+)</Guid>", body)) for guid, name, gender, body in rows}


def weapon_presets():
    text = read(TABLES / "item/weapon_preset.xml")
    rows = re.findall(r'weapon_preset_id="([^"]+)" weapon_preset_name="([^"]+)"[^>]*(?<!/)>(.*?)</weapon_preset>', text, re.S)
    return {name: (guid, re.findall(r'item_class_id="([^"]+)"', body)) for guid, name, body in rows}


def items():
    found = {}
    for path in (TABLES / "item").glob("item*.xml"):
        for row in re.findall(r'<[A-Z][A-Za-z]+ [^>]*\bId="[0-9a-f-]{36}"[^>]*>', read(path)):
            data = dict(re.findall(r'(\w+)="([^"]*)"', row))
            if data.get("Name"):
                found[data["Name"]] = data["Id"]
    return found


def skills():
    return set(re.findall(r'skill_name="([^"]+)"', read(TABLES / "rpg/skill.xml")))


def xp_for_level(level):
    return sum(XP_FIRST + XP_STEP * step for step in range(level - 1))


def fail(origin, message):
    raise SystemExit(f"origins.toml, {origin.get('key', '?')}: {message}")


def pieces(guids, origin, names):
    """Each piece of the preset, with the health of its quality."""
    basic = origin.get("quality_basic", origin["quality"])
    return [(guid, QUALITY_HEALTH[basic if BASIC_CLOTHES.match(names.get(guid, "")) else origin["quality"]]) for guid in guids]


def resolve(data):
    clothes, weapons, known_items, known_skills = clothing_presets(), weapon_presets(), items(), skills()
    names = {guid: name for name, guid in known_items.items()}
    origins = data.get("origin", [])
    keys = [o.get("key") for o in origins]
    if len(set(keys)) != len(keys):
        raise SystemExit("origins.toml: two origins have the same key")
    if data.get("default") not in keys:
        raise SystemExit(f"origins.toml: default '{data.get('default')}' is not any origin")
    for_all = data.get("for_all", [])
    for item in for_all:
        if item not in known_items:
            raise SystemExit(f"origins.toml, for_all: {item} does not exist")
    resolved = []
    for origin in origins:
        for field in ("key", "name_en", "name_es", "clothes", "clothes_female", "quality", "money"):
            if field not in origin:
                fail(origin, f"missing {field}")
        for field, gender in (("clothes", "Male"), ("clothes_female", "Female")):
            preset = clothes.get(origin[field])
            if not preset:
                fail(origin, f"{field}: preset {origin[field]} does not exist")
            if preset[1] != gender:
                fail(origin, f"{field}: {origin[field]} is {preset[1]}, not {gender}")
        basic = origin.get("quality_basic", origin["quality"])
        for level in (origin["quality"], basic):
            if level not in QUALITY_HEALTH:
                fail(origin, f"quality and quality_basic must be one of {list(QUALITY_HEALTH)}")
        weapon = origin.get("weapon")
        if weapon and weapon not in weapons:
            fail(origin, f"weapon: preset {weapon} does not exist")
        for skill, level in origin.get("skills", {}).items():
            if skill not in known_skills:
                fail(origin, f"skills: {skill} does not exist")
            if not 2 <= level <= MAX_LEVEL:
                fail(origin, f"skills: {skill} must be from 2 to {MAX_LEVEL}")
        for item in origin.get("items", {}):
            if item not in known_items:
                fail(origin, f"items: {item} does not exist")
        resolved.append({
            "origin": origin,
            "clothes": clothes[origin["clothes"]][0],
            "clothes_female": clothes[origin["clothes_female"]][0],
            "weapon": weapons[weapon][0] if weapon else None,
            "wear": pieces(clothes[origin["clothes"]][2], origin, names),
            "wear_female": pieces(clothes[origin["clothes_female"]][2], origin, names),
            "weapons": (weapons[weapon][1] if weapon else []) + [known_items[item] for item in for_all],
            "weapon_quality": basic,
            "xp": {skill: xp_for_level(level) for skill, level in origin.get("skills", {}).items()},
            "items": [(known_items[item], item, amount) for item, amount in origin.get("items", {}).items()],
        })
    return resolved, keys.index(data["default"]) + 1


def wield_token(origin):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"medieval_life/ml_wield_{origin['key']}"))


def write_lua(mod_dir, resolved, default):
    blocks = []
    for r in resolved:
        origin = r["origin"]
        lines = [f'		key = "{origin["key"]}",',
                 f'		money = {origin["money"] * 10},',
                 f'		clothes = "{r["clothes"]}", -- {origin["clothes"]}',
                 f'		clothes_female = "{r["clothes_female"]}", -- {origin["clothes_female"]}']
        if r["weapon"]:
            lines.append(f'		weapon = "{r["weapon"]}", -- {origin["weapon"]}')
        xp = ", ".join(f"{skill} = {amount}" for skill, amount in r["xp"].items())
        lines.append(f'		xp = {{ {xp} }},')
        lines.append(f'		weapon_health = {QUALITY_HEALTH[r["weapon_quality"]]},')
        if r["weapons"]:
            lines.append(f'		wield_token = "{wield_token(origin)}",')
        if "steady_job" in origin:
            lines.append(f'		steady_job = "{origin["steady_job"]}",')
        lines.append("		wear = {")
        lines += [f'			{{ "{guid}", {health} }},' for guid, health in r["wear"]]
        lines.append("		},")
        lines.append("		wear_female = {")
        lines += [f'			{{ "{guid}", {health} }},' for guid, health in r["wear_female"]]
        lines.append("		},")
        lines.append("		weapons = {")
        lines += [f'			"{guid}",' for guid in r["weapons"]]
        lines.append("		},")
        lines.append("		items = {")
        lines += [f'			{{ "{guid}", {amount} }}, -- {name}' for guid, name, amount in r["items"]]
        lines.append("		},")
        blocks.append("	{\n" + "\n".join(lines) + "\n	},\n")
    path = mod_dir / "data/Scripts/MedievalLife/origins_data.lua"
    path.write_bytes(f'''-- Generated by tools/generate_origins.py from mod/medieval_life/origins.toml. Edit that file, not this one.
-- The position of each origin is what saved games keep.
MedievalLife.ORIGIN_DEFAULT = {default}
MedievalLife.ORIGINS = {{
{"".join(blocks)}}}
'''.encode("utf-8"))


def edit(path, change):
    raw = path.read_bytes().decode("utf-8")
    crlf = "\r\n" in raw
    text = change(raw.replace("\r\n", "\n"))
    path.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))


def write_selector(mod_dir, resolved):
    tabs = "\t" * 12

    def options(gender):
        return "".join(f'''{tabs}<Sequence EndType="GoTo" GoToDecision="dec_origin_{gender}" ExitScript="MedievalLife.Selector.SetOrigin({i})" Name="seq_origin_{gender}_{i}">
{tabs}	<UiPrompt StringName="ui_ml_origin_{i}" />
{tabs}	<Elements>
{tabs}		<Response Role="HENRY" />
{tabs}	</Elements>
{tabs}</Sequence>
''' for i in range(1, len(resolved) + 1))

    def change(text):
        for gender in GENDERS:
            text = re.sub(rf'\t*<Sequence [^>]*Name="seq_origin_{gender}_\d+">.*?</Sequence>\n', "", text, flags=re.S)
            marker = f'{tabs}<Sequence EndType="Decision" Name="seq_origin_{gender}_choose">\n'
            if text.count(marker) != 1:
                raise SystemExit(f"ml_selector.xml: cannot find seq_origin_{gender}_choose")
            text = text.replace(marker, options(gender) + marker)
        return text

    edit(mod_dir / "data/Quests/medieval_life/trosecko/ml_new_life/ml_selector.xml", change)


def write_items(mod_dir, resolved):
    def change(text):
        text = re.sub(r'\t\t<MiscItem [^\n]*Name="ml_wield_[a-z_]+" />\n', "", text)
        template = re.search(r'\t\t<MiscItem [^\n]*Name="ml_open_shops" />\n', text).group(0)
        rows = "".join(re.sub(r' Id="[^"]+"', f' Id="{wield_token(r["origin"])}"', template).replace('Name="ml_open_shops"', f'Name="ml_wield_{r["origin"]["key"]}"')
                       for r in resolved if r["weapons"])
        if text.count(WIELD_MARK) != 1:
            raise SystemExit("item__medieval_life.xml: cannot find the marker of the weapon tokens")
        return text.replace(WIELD_MARK, WIELD_MARK + rows)

    edit(mod_dir / "data/Libs/Tables/item/item__medieval_life.xml", change)


def write_quest(mod_dir, resolved):
    """Only Skald fills the weapon slot."""
    nodes = []
    for i, r in enumerate(resolved, 1):
        if not r["weapons"]:
            continue
        nodes.append(f'''				<Function Name="token_descriptor_{i}" PositionY="{i * 400}" PositionX="-600" MethodName="wh::entitymodule::CreateItemClassDescriptor" DeclaringType="wh::entitymodule">
					<Constant Name="ItemClass" Value="{wield_token(r["origin"])}" />
					<Constant Name="Amount" Value="1" />
				</Function>
				<ItemDescriptorTrigger Name="token_{i}" PositionY="{i * 400}" PositionX="-300">
					<Edge From="henry.Inventory" To="Inventory" />
					<Edge From="token_descriptor_{i}.ItemDescriptor" To="ItemDescriptor" />
					<Edge From="always_on.State" To="IsActive" />
				</ItemDescriptorTrigger>
				<State Name="chosen_{i}" PositionY="{i * 400}" PositionX="0" TypeT="bool">
					<Constant Name="DefaultValue" Value="false" />
					<Edge From="token_{i}.OnAcquire" To="SetTrue" />
				</State>
				<If Name="if_chosen_{i}" PositionY="{i * 400}" PositionX="300">
					<Edge From="chosen_{i}.State" To="Condition" />
					<Edge From="life_started" To="Exec" />
				</If>
''')
        for j, guid in enumerate(r["weapons"], 1):
            nodes.append(f'''				<EventFunction Name="reward_{i}_{j}" PositionY="{i * 400 + j * 100}" PositionX="600" MethodName="wh::entitymodule::CreatePlayerReward" DeclaringType="wh::entitymodule">
					<Constant Name="ItemClass" Value="{guid}" />
					<Constant Name="ShowUINotification" Value="false" />
					<Constant Name="Quality" Value="{r["weapon_quality"]}" />
					<Constant Name="Health" Value="1" />
					<Constant Name="Condition" Value="1" />
					<Edge From="if_chosen_{i}.True" To="Exec" />
				</EventFunction>
				<MemberFunction Name="equip_{i}_{j}" PositionY="{i * 400 + j * 100}" PositionX="900" MethodName="EquipPlayersItem" DeclaringType="wh::entitymodule::EquipmentManager">
					<Edge From="reward_{i}_{j}.OnExec" To="Exec" />
					<Edge From="new_life.EquipmentManager" To="Manager" />
					<Edge From="reward_{i}_{j}.ItemDescriptor" To="ItemDescriptor" />
				</MemberFunction>
				<Timer Name="timer_{i}_{j}" PositionY="{i * 400 + j * 100}" PositionX="1200">
					<Constant Name="Duration" Value="{WIELD_AGAIN}" />
					<Constant Name="TimeType" Value="GameTime" />
					<Edge From="reward_{i}_{j}.OnExec" To="SetRunning" />
				</Timer>
				<Function Name="weapon_descriptor_{i}_{j}" PositionY="{i * 400 + j * 100}" PositionX="1500" MethodName="wh::entitymodule::CreateItemClassDescriptor" DeclaringType="wh::entitymodule">
					<Constant Name="ItemClass" Value="{guid}" />
					<Constant Name="Amount" Value="1" />
				</Function>
				<MemberFunction Name="equip_again_{i}_{j}" PositionY="{i * 400 + j * 100}" PositionX="1800" MethodName="EquipPlayersItem" DeclaringType="wh::entitymodule::EquipmentManager">
					<Edge From="timer_{i}_{j}.OnFinished" To="Exec" />
					<Edge From="new_life.EquipmentManager" To="Manager" />
					<Edge From="weapon_descriptor_{i}_{j}.ItemDescriptor" To="ItemDescriptor" />
				</MemberFunction>
''')
    path = mod_dir / "data/Quests/medieval_life/trosecko/ml_weapons.xml"
    path.write_bytes(f'''<?xml version="1.0" encoding="utf-8"?>
<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="brambora">
	<!-- Generated by tools/generate_origins.py from mod/medieval_life/origins.toml. Edit that file, not this one.
	     A token only reaches Skald on the inventory of Henry, so the origin comes before the switch, and the weapon when it
	     ends. It is equipped twice: the second time the player is back in control, in case it is not taken under the black
	     screen. See Life.Begin. -->
	<Skald>
		<Gameplay Name="ml_weapons">
			<Ports>
				<Port Name="life_started" Direction="In" Type="trigger" />
			</Ports>
			<Nodes>
				<ObjectProperties Name="henry" PositionY="0" PositionX="-900" DeclaringType="wh::rpgmodule::I_Soul">
					<Asset Name="I_Soul" Alias="player" />
				</ObjectProperties>
				<ObjectProperties Name="new_life" PositionY="200" PositionX="-900" DeclaringType="wh::rpgmodule::I_Soul">
					<Asset Name="I_Soul" Alias="new_life" />
				</ObjectProperties>
				<State Name="always_on" PositionY="0" PositionX="-600" TypeT="bool">
					<Constant Name="DefaultValue" Value="true" />
				</State>
{"".join(nodes)}			</Nodes>
			<Assets>
				<SoulAsset Name="player" SharedSoulGuids="4c2dcffb-dea1-6263-72d7-b39f4db2d8b5" />
				<SoulAsset Name="new_life" SharedSoulGuids="e9f088ff-48e3-5fa1-b733-80504a56d1dc" />
			</Assets>
			<Text Text="ml_weapons" />
		</Gameplay>
	</Skald>
</Database>
'''.encode("utf-8"))


def write_text(mod_dir, resolved):
    for folder, field in LANGUAGES:
        def change(text):
            text = re.sub(r"  <Row><Cell>ui_ml_origin_\d+</Cell>[^\n]*\n", "", text)
            rows = "".join(f"  <Row><Cell>ui_ml_origin_{i}</Cell><Cell>ui_ml_origin_{i}</Cell><Cell>{r['origin'][field]}</Cell></Row>\n"
                           for i, r in enumerate(resolved, 1))
            marker = "  <Row><Cell>ui_ml_origin_choose</Cell>"
            if text.count(marker) != 1:
                raise SystemExit(f"{folder}: cannot find ui_ml_origin_choose")
            return text.replace(marker, rows + marker)

        edit(mod_dir / "localization" / folder / "text__medieval_life.xml", change)


def main(mod_dir):
    data = tomllib.loads((mod_dir / "origins.toml").read_text("utf-8"))
    resolved, default = resolve(data)
    jobs = tomllib.loads((mod_dir / "jobs.toml").read_text("utf-8"))
    steady = {site["key"] for site in jobs["site"] if site.get("steady")}
    for r in resolved:
        if r["origin"].get("steady_job", next(iter(steady))) not in steady:
            fail(r["origin"], f"steady_job: {r['origin']['steady_job']} is not a site with steady = true")
    write_lua(mod_dir, resolved, default)
    write_selector(mod_dir, resolved)
    write_items(mod_dir, resolved)
    write_quest(mod_dir, resolved)
    write_text(mod_dir, resolved)
    print(f"{len(resolved)} origins, the default is number {default}")


if __name__ == "__main__":
    main((ROOT / sys.argv[1]).resolve())

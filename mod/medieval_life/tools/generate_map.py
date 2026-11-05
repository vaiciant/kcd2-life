"""Generates what the mod needs for the map of the new life.

- Quests/.../ml_clear_map.xml: one SetPOIDiscoveryStatus node per point type. The types come from
  the game tables, by their label: points of interest, camps, hunting spots and nests go to Unknown,
  and shops to Discovered. That gives 5 Survival XP per point to whoever is playing, so the shops are opened
  with their own token, before the switch, with Henry, and the hidden ones after. Fast travel is not touched: that node is not saved and hides the shops.
- Scripts/MedievalLife/map_points.lua: the fast travel points and the marks that come back on load,
  taken from the level files, so the map removes those the character does not know.
- Quests/medieval_life/ml_map_beds.xml: the beds and homes of Henry, off the compass while the new character plays, and
  back when Henry plays. Each one hears its token; the tokens are in item__medieval_life.xml.

The order is that of what the saved game keeps: a new point goes at the end of its list.

Usage: python -I mod/medieval_life/tools/generate_map.py mod/medieval_life
"""
import os
import pathlib
import re
import sys
import uuid
import zipfile

# The repository: this file is in mod/medieval_life/tools/.
ROOT = pathlib.Path(__file__).resolve().parents[3]
VANILLA = ROOT / "game_files/Tables.pak/Libs/Tables/rpg"
# KCD2_GAME, or the game in the default Steam library, or in the maintainer's.
GAME_PLACES = (r"C:\Program Files (x86)\Steam\steamapps\common\KingdomComeDeliverance2", r"E:\SteamLibrary\steamapps\common\KingdomComeDeliverance2")
GAME = pathlib.Path(os.environ.get("KCD2_GAME") or next((p for p in GAME_PLACES if os.path.isfile(os.path.join(p, "Data", "Tables.pak"))), GAME_PLACES[0]))
LEVELS = (("trosky", "trosecko"), ("kuttenberg", "kutnohorsko"))
HIDDEN = re.compile(r"ui_maplegend_(general_poi|camp|camp_enemy|nest|hunting_spot.*)$")
NOT_SHOPS = {"bed", "bedplayer", "home", "wolfStone", "fasttravel", "fasttravel_level", "fasttravel_sedlec", "fasttravel_vezak", "fasttravel_vidlak"}
EXTRA_SHOPS = {"laundry", "millerKrejzl"}
NEST_LABEL = "ui_maplegend_nest"
# The beds of the game on the map. Henry's, his own and the rented ones, show there for the new character too, who
# can never own one of the game: the map takes them all off for the new life. The mod marks its own beds.
BED_TYPES = {"bed", "bedplayer", "home", "vineyardsBed"}
# The smart object type of a bed, and the end of the id of its mark: "BED POI" in bytes.
BED_SMART_OBJECT = "425d4fdf-8dcd-4a2b-fdc5-cbb1b5d25b89"
BED_MARK_SUFFIX = "-4245-4420504f4900"
# The beds and homes of the player: the game makes their marks when one becomes Henry's, so only Henry has them.
# The compass shows them by their discovery, which the map filter does not touch. Those of the levels, the straw
# beds, stay as they are.
OWNED_BED_TYPES = ("bedplayer", "home")
EXPECTED_HIDDEN, EXPECTED_SHOPS, EXPECTED_POINTS, EXPECTED_MARKS = 62, 45, 42, 381
# The tick is one second: on horseback the real distance can be skipped.
MARK_RANGE_MARGIN = 10


def guid(name):
    """As tools/generate_orders.py names its tokens."""
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"medieval_life/{name}"))


BEDS_HIDE_TOKEN, BEDS_SHOW_TOKEN = guid("ml_hide_beds"), guid("ml_show_beds")


def poi_rows():
    rows = []
    for name in ("poi_type.xml", "poi_type__system.xml"):
        for row in re.findall(r"<poi_type [^>]*>", (VANILLA / name).read_text("utf-8", errors="replace")):
            rows.append(dict(re.findall(r'(\w+)="([^"]*)"', row)))
    return rows


def hidden_types(rows):
    return sorted((r["poi_type_name"], r["poi_type_id"]) for r in rows if HIDDEN.match(r["label"]))


def shop_types(rows):
    """What the game discovers with the location, without what belongs to Henry, plus what the list is missing."""
    return sorted((r["poi_type_name"], r["poi_type_id"]) for r in rows
                  if (r["discoverable_by_location"] == "true" and r["poi_type_name"] not in NOT_SHOPS) or r["poi_type_name"] in EXTRA_SHOPS)


def node(prefix, name, guid, status, row, trigger):
    return (f'				<Function Name="{prefix}_{name}" PositionY="{row * 120}" PositionX="{0 if prefix == "hide" else 600}" MethodName="wh::rpgmodule::SetPOIDiscoveryStatus" DeclaringType="wh::rpgmodule">\n'
            f'					<Constant Name="POIType" Value="{guid}" />\n'
            f'					<Constant Name="Status" Value="{status}" />\n'
            f'					<Edge From="{trigger}" To="Exec" />\n'
            '				</Function>\n')


def write_module(mod_dir, hidden, shops):
    nodes = "".join(node("hide", n, g, "Unknown", i, "life_started") for i, (n, g) in enumerate(hidden))
    nodes += "".join(node("show", n, g, "Discovered", i, "open_shops") for i, (n, g) in enumerate(shops))
    path = mod_dir / "data/Quests/medieval_life/trosecko/ml_clear_map.xml"
    path.write_bytes(f'''<?xml version="1.0" encoding="utf-8"?>
<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="brambora">
	<!-- Generated by tools/generate_map.py. The new character must not see what Henry discovered: points of interest,
	     camps, hunting spots and nests go back to unknown when the switch ends, and visiting them discovers them again.
	     Every shop shows from the start: they open with their own token, before the switch, because each one gives Survival
	     experience to whoever is playing. Fast travel stays out of this: see Scripts/MedievalLife/fast_travel.lua. -->
	<Skald>
		<Gameplay Name="ml_clear_map">
			<Ports>
				<Port Name="open_shops" Direction="In" Type="trigger" />
				<Port Name="life_started" Direction="In" Type="trigger" />
			</Ports>
			<Nodes>
{nodes}			</Nodes>
			<Text Text="ml_clear_map" />
		</Gameplay>
	</Skald>
</Database>
'''.encode("utf-8"))


def write_beds_module(mod_dir, rows):
    types = sorted((r["poi_type_name"], r["poi_type_id"]) for r in rows if r["poi_type_name"] in OWNED_BED_TYPES)
    assert len(types) == len(OWNED_BED_TYPES), types
    nodes = "".join(node("hide", n, g, "Unknown", i, "hide_token.OnAcquire") for i, (n, g) in enumerate(types))
    nodes += "".join(node("show", n, g, "Discovered", i, "show_token.OnAcquire") for i, (n, g) in enumerate(types))
    path = mod_dir / "data/Quests/medieval_life/ml_map_beds.xml"
    path.write_bytes(f'''<?xml version="1.0" encoding="utf-8"?>
<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="brambora">
	<!-- Generated by tools/generate_map.py. The beds and homes of Henry show on the compass by their discovery: while the
	     new character plays, they go back to unknown, with a token in the inventory of the new character, on every load
	     and when the life begins (bed_marker.lua). When Henry plays again, a token in his inventory discovers them. It
	     hangs from the project to reach every map. -->
	<Skald>
		<Gameplay Name="ml_map_beds">
			<Nodes>
				<ObjectProperties Name="henry" PositionY="0" PositionX="-900" DeclaringType="wh::rpgmodule::I_Soul">
					<Asset Name="I_Soul" Alias="player" />
				</ObjectProperties>
				<ObjectProperties Name="new_life" PositionY="200" PositionX="-900" DeclaringType="wh::rpgmodule::I_Soul">
					<Asset Name="I_Soul" Alias="new_life" />
				</ObjectProperties>
				<State Name="always_on" PositionY="-150" PositionX="-900" TypeT="bool">
					<Constant Name="DefaultValue" Value="true" />
				</State>
				<Function Name="hide_descriptor" PositionY="200" PositionX="-600" MethodName="wh::entitymodule::CreateItemClassDescriptor" DeclaringType="wh::entitymodule">
					<Constant Name="ItemClass" Value="{BEDS_HIDE_TOKEN}" />
					<Constant Name="Amount" Value="1" />
				</Function>
				<ItemDescriptorTrigger Name="hide_token" PositionY="200" PositionX="-300">
					<Edge From="new_life.Inventory" To="Inventory" />
					<Edge From="hide_descriptor.ItemDescriptor" To="ItemDescriptor" />
					<Edge From="always_on.State" To="IsActive" />
				</ItemDescriptorTrigger>
				<Function Name="show_descriptor" PositionY="500" PositionX="-600" MethodName="wh::entitymodule::CreateItemClassDescriptor" DeclaringType="wh::entitymodule">
					<Constant Name="ItemClass" Value="{BEDS_SHOW_TOKEN}" />
					<Constant Name="Amount" Value="1" />
				</Function>
				<ItemDescriptorTrigger Name="show_token" PositionY="500" PositionX="-300">
					<Edge From="henry.Inventory" To="Inventory" />
					<Edge From="show_descriptor.ItemDescriptor" To="ItemDescriptor" />
					<Edge From="always_on.State" To="IsActive" />
				</ItemDescriptorTrigger>
{nodes}			</Nodes>
			<Assets>
				<SoulAsset Name="player" SharedSoulGuids="4c2dcffb-dea1-6263-72d7-b39f4db2d8b5" />
				<SoulAsset Name="new_life" SharedSoulGuids="e9f088ff-48e3-5fa1-b733-80504a56d1dc" />
			</Assets>
			<Text Text="ml_map_beds" />
		</Gameplay>
	</Skald>
</Database>
'''.encode("utf-8"))


def read_entry(pak, info):
    try:
        return pak.read(info)
    except zipfile.BadZipFile:
        # Many entries store the name with a backslash, and zipfile rejects them.
        info.orig_filename = info.filename.replace("/", "\\")
        return pak.read(info)


def level_marks():
    """The marks of whdata_0 carry the id the map uses, which is not in the layers of the level."""
    for region, level in LEVELS:
        pak = zipfile.ZipFile(GAME / "Data/Levels" / level / "level.pak")
        text = read_entry(pak, pak.getinfo("whdata_0")).decode("utf-8", errors="replace")
        for mark in re.findall(r"<Mark>(.*?)</Mark>", text, re.S):
            data = dict(re.findall(r"<(\w+)>([^<]*)</\1>", mark))
            x, y = data["Position"].split(",")[:2]
            yield region, data, float(x), float(y), int(float(data["DiscoveryDistance"]))


def fast_travel_points():
    points = []
    for region, data, x, y, reach in level_marks():
        if data.get("FastTravelQuestion"):
            name = re.sub(r"^ui_fasttravel_|_question$", "", data["FastTravelQuestion"])
            points.append((region, name, data["Id"], x, y, reach))
    return sorted(points, key=lambda p: (p[0] != "trosky", p[1], p[2]))


def returning_marks(rows):
    """What is hidden and comes back on load: everything but the nests, which carry another flag in their marks."""
    types = {r["poi_type_id"] for r in rows if HIDDEN.match(r["label"]) and r["label"] != NEST_LABEL}
    marks = [(region, data["Id"], x, y, reach + MARK_RANGE_MARGIN)
             for region, data, x, y, reach in level_marks() if data.get("POITypeId") in types]
    return sorted(marks, key=lambda m: (m[0] != "trosky", m[1]))


def bed_marks(rows):
    """The marks of the beds and homes of the levels, by region, with where they are: those of whdata_0, and those the
    game makes when a bed becomes the player's, as when Henry rents one. The id of the mark of a bed is the
    EntityGuid of its StanceSmartObject and BED_MARK_SUFFIX, as in whdata_0."""
    types = {r["poi_type_id"] for r in rows if r["poi_type_name"] in BED_TYPES}
    found = {region: {} for region, _ in LEVELS}
    for region, data, x, y, _ in level_marks():
        if data.get("POITypeId") in types:
            found[region][data["Id"]] = (x, y)
    for region, level in LEVELS:
        pak = zipfile.ZipFile(GAME / "Data/Levels" / level / "level.pak")
        for info in pak.infolist():
            if not info.filename.lower().endswith(".xml"):
                continue
            text = read_entry(pak, info).decode("utf-8", errors="replace")
            for entity in re.finditer(r'<Entity [^>]*EntityClass="StanceSmartObject"[^>]*>(.*?)</Entity>', text, re.S):
                if BED_SMART_OBJECT not in entity.group(1):
                    continue
                head = entity.group(0)[:entity.group(0).index(">") + 1]
                guid = re.search(r'EntityGuid="([0-9a-f-]{18})"', head)
                pos = re.search(r'Pos="([^"]+)"', head)
                if guid and pos:
                    x, y = (float(n) for n in pos.group(1).split(",")[:2])
                    found[region].setdefault(guid.group(1) + BED_MARK_SUFFIX, (x, y))
    return {region: sorted(marks.items()) for region, marks in found.items()}


def write_points(mod_dir, points, marks, beds):
    rows = "".join(f'	{{ id = "{mark_id}", name = "{name}", region = "{region}", x = {x:.1f}, y = {y:.1f}, range = {reach} }},\n'
                   for region, name, mark_id, x, y, reach in points)
    mark_rows = "".join(f'	{{ id = "{mark_id}", region = "{region}", x = {x:.1f}, y = {y:.1f}, range = {reach} }},\n'
                        for region, mark_id, x, y, reach in marks)
    bed_rows = "".join(f'\t{region} = {{\n' + "".join(f'\t\t{{ "{i}", {x:.1f}, {y:.1f} }},\n' for i, (x, y) in marks) + '\t},\n'
                       for region, marks in beds.items())
    path = mod_dir / "data/Scripts/MedievalLife/map_points.lua"
    path.write_bytes(f'''-- Generated by tools/generate_map.py: map points of the game, from its level files.
-- id is the marker on the map, and range how close counts as having been there.
-- The order matters: it is what saved games keep.
MedievalLife.FAST_TRAVEL_POINTS = {{
{rows}}}

-- What the game brings back on every load: see map_marks.lua.
MedievalLife.MAP_MARKS = {{
{mark_rows}}}
-- The marks of the beds of the game, by region, with where they are: the map and the compass take them off for the new
-- life, but the one of the bed rented with the mod (fast_travel.lua and bed_marker.lua).
MedievalLife.MAP_BEDS = {{
{bed_rows}}}
-- The tokens of ml_map_beds.xml: the beds and homes of Henry off the compass, and back.
MedievalLife.MAP_BEDS_TOKENS = {{ hide = "{BEDS_HIDE_TOKEN}", show = "{BEDS_SHOW_TOKEN}" }}
'''.encode("utf-8"))


def main(mod_dir):
    rows = poi_rows()
    hidden, shops = hidden_types(rows), shop_types(rows)
    assert (len(hidden), len(shops)) == (EXPECTED_HIDDEN, EXPECTED_SHOPS), (len(hidden), len(shops))
    write_module(mod_dir, hidden, shops)
    items = (mod_dir / "data/Libs/Tables/item/item__medieval_life.xml").read_text("utf-8")
    assert all(f' Id="{token}"' in items for token in (BEDS_HIDE_TOKEN, BEDS_SHOW_TOKEN)), "item__medieval_life.xml: the bed tokens are missing"
    write_beds_module(mod_dir, rows)
    points = fast_travel_points()
    assert len(points) == EXPECTED_POINTS, len(points)
    marks = returning_marks(rows)
    assert len(marks) == EXPECTED_MARKS, len(marks)
    beds = bed_marks(rows)
    write_points(mod_dir, points, marks, beds)
    print(f"{len(hidden)} hidden types, {len(shops)} shops, {len(points)} fast travel points, {len(marks)} marks, "
          f"beds {', '.join(f'{r} {len(i)}' for r, i in beds.items())}")


if __name__ == "__main__":
    main((ROOT / sys.argv[1]).resolve())

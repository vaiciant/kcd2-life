"""Generates the mod's own alchemy recipes.

The game stores somewhere which recipes a player knows, and there is no way to erase them.
That is why the vanilla recipes are hidden and copies are made with new numbers, which nobody knows:

- minigame/AlchemyRecipe.xml replaces the vanilla table. Each vanilla recipe stays hidden with DlcId 8 ("Unpublished")
  and emptied: the game compares each brew with every recipe, and the identical original would win over the copy.
  The copies have RecipeId + 9000;
- perk__<mod>.xml and perk_recipe__<mod>.xml: a new perk for each vanilla recipe perk;
- item__<mod>.xml: each recipe document teaches the copy;
- Libs/UI/Textures/Books: the book looks up its images by recipe number, so they are copied from the game.
  They are not versioned (.gitignore).

Usage: python -I mod/medieval_life/tools/generate_recipes.py mod/medieval_life
"""
import os
import pathlib
import re
import struct
import sys
import uuid
import zipfile
import zlib

# The repository: this file is in mod/medieval_life/tools/.
ROOT = pathlib.Path(__file__).resolve().parents[3]
VANILLA = ROOT / "game_files/Tables.pak/Libs/Tables"
# KCD2_GAME, or the game in the default Steam library, or in the maintainer's.
GAME_PLACES = (r"C:\Program Files (x86)\Steam\steamapps\common\KingdomComeDeliverance2", r"E:\SteamLibrary\steamapps\common\KingdomComeDeliverance2")
GAME = pathlib.Path(os.environ.get("KCD2_GAME") or next((p for p in GAME_PLACES if os.path.isfile(os.path.join(p, "Data", "Tables.pak"))), GAME_PLACES[0]))
OFFSET = 9000
HIDDEN_DLC = 8
# The ml_state token of the mod: it is not an herb, nobody can put it in the cauldron, so the emptied recipes never match.
DUMMY_INGREDIENT = "80a945ff-02d8-51ab-80e9-dbd93dc2ffe4"
DB_OPEN = '<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="barbora" xsi:noNamespaceSchemaLocation="{xsd}">\n'
RECIPE_ROW = r'[ \t]*<AlchemyRecipe RecipeId="(\d+)".*?</AlchemyRecipe>\r?\n?'


def write_table(path, xsd, root, comment, body):
    path.parent.mkdir(exist_ok=True)
    path.write_text(
        '<?xml version="1.0" encoding="us-ascii"?>\n'
        f"<!-- {comment} -->\n" + DB_OPEN.format(xsd=xsd) + f'\t<{root} version="1">\n' + body + f"\t</{root}>\n</database>\n",
        "ascii", newline="\n")


def replace_block(path, closing_tag, body):
    """Puts the generated rows between markers, without touching what is written by hand in the rest of the file."""
    raw = path.read_bytes().decode("utf-8")
    crlf = "\r\n" in raw
    text = re.sub(r"\t\t<!-- generated recipes: start -->.*?<!-- generated recipes: end -->\n", "", raw.replace("\r\n", "\n"), flags=re.S)
    block = "\t\t<!-- generated recipes: start -->\n" + body + "\t\t<!-- generated recipes: end -->\n"
    assert text.count(closing_tag) == 1, closing_tag
    text = text.replace(closing_tag, block + closing_tag)
    path.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))


def hidden_recipe(row):
    """Vanilla row without real ingredients: it keeps the number, the texts and the products."""
    tag = re.search(r"<AlchemyRecipe [^>]*>", row)[0]
    tag = re.sub(r' DlcId="\d+"', "", tag)[:-1] + f' DlcId="{HIDDEN_DLC}">'
    products = re.search(r"<Products>.*?</Products>", row, flags=re.S)[0]
    return (f"\t\t{tag}\n"
            "\t\t\t<Ingredients>\n"
            f'\t\t\t\t<AlchemyIngredient IngredientItemId="{DUMMY_INGREDIENT}" Quantity="1" />\n'
            "\t\t\t</Ingredients>\n"
            f"\t\t\t{products}\n"
            "\t\t\t<Steps>\n"
            f'\t\t\t\t<AlchemyRecipeStep StepId="1" StepType="Trivial" Condition="IngredientCount (\'{DUMMY_INGREDIENT}\')&gt;=1" />\n'
            "\t\t\t</Steps>\n"
            "\t\t</AlchemyRecipe>\n")


def copy_textures(mod_dir, recipes):
    """The entries of the game .pak use mixed slashes and zipfile rejects them, so they are read by hand."""
    pak_path = GAME / "Data/IPL_GameData.pak"
    copied = 0
    with zipfile.ZipFile(pak_path) as pak, open(pak_path, "rb") as raw:
        entries = {info.filename.replace("\\", "/").lower(): info for info in pak.infolist()}
        for kind in ("Recipes", "Products"):
            for recipe in recipes:
                info = entries.get(f"libs/ui/textures/books/{kind}/{recipe}_ui.dds".lower())
                if info is None:
                    continue
                raw.seek(info.header_offset)
                name_len, extra_len = struct.unpack("<HH", raw.read(30)[26:30])
                raw.seek(info.header_offset + 30 + name_len + extra_len)
                data = raw.read(info.compress_size)
                target = mod_dir / f"data/Libs/UI/Textures/Books/{kind}/{OFFSET + recipe}_ui.dds"
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(zlib.decompress(data, -15) if info.compress_type == 8 else data)
                copied += 1
    return copied


def main(mod_dir):
    modid = mod_dir.name
    tables = mod_dir / "data/Libs/Tables"

    source = (VANILLA / "minigame/AlchemyRecipe.xml").read_text("utf-8", errors="replace")
    recipes, hidden, copies = [], "", ""
    for match in re.finditer(RECIPE_ROW, source, flags=re.S):
        recipe = int(match[1])
        recipes.append(recipe)
        row = match[0].replace("\r\n", "\n")
        hidden += hidden_recipe(row)
        copy = row.replace(f'RecipeId="{recipe}"', f'RecipeId="{OFFSET + recipe}"', 1)
        copies += copy if copy.endswith("\n") else copy + "\n"
    (tables / f"minigame/AlchemyRecipe__{modid}.xml").unlink(missing_ok=True)
    write_table(tables / "minigame/AlchemyRecipe.xml", "../database.xsd", "AlchemyRecipes",
                "Generated by tools/generate_recipes.py. Replaces the vanilla table: vanilla recipes are emptied and hidden, and nobody knows the copies.",
                hidden + copies)

    pairs = re.findall(r'perk_id="([0-9a-f-]+)" recipe_id="(\d+)"', (VANILLA / "rpg/perk_recipe.xml").read_text("utf-8"))
    perks = [(str(uuid.uuid5(uuid.NAMESPACE_URL, "medieval_life-alch-" + perk)), int(recipe)) for perk, recipe in pairs]
    write_table(tables / f"rpg/perk_recipe__{modid}.xml", "../database.xsd", "perk_recipes",
                "Generated by tools/generate_recipes.py. Each copy depends on a new perk.",
                "".join(f'\t\t<perk_recipe perk_id="{perk}" recipe_id="{OFFSET + recipe}" />\n' for perk, recipe in perks))
    replace_block(tables / f"rpg/perk__{modid}.xml", "\t</perks>\n", "".join(
        f'\t\t<perk autolearnable="false" perk_id="{perk}" perk_name="ml alch recipe {OFFSET + recipe} {n}" visibility="0" />\n'
        for n, (perk, recipe) in enumerate(perks)))

    documents = ""
    for path in sorted((VANILLA / "item").glob("item*.xml")):
        for match in re.finditer(r'<Document [^>]*RecipeId="(\d+)"[^>]*>', path.read_text("utf-8", errors="replace")):
            item = re.search(r' Id="([0-9a-f-]+)"', match[0])[1]
            documents += f'\t\t<Document Id="{item}" RecipeId="{OFFSET + int(match[1])}" />\n'
    replace_block(tables / f"item/item__{modid}.xml", "\t</ItemClasses>\n", documents)

    print(f"recipes {len(recipes)}, perks {len(perks)}, documents {documents.count('<Document')}, "
          f"textures {copy_textures(mod_dir, recipes)}")


if __name__ == "__main__":
    main((ROOT / sys.argv[1]).resolve())

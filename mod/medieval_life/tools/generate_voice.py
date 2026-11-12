"""The setting Voice of KCD2 Life: with it off, the new character says the lines of the mod's dialogs as text only,
with no voice and no lip sync.

In those dialogs the new character speaks lines that Henry recorded in the game, as "I'm looking for work". Skald has no
condition on a single line, only on a sequence. So each sequence where the new character says a recorded line gets a
twin right after it: the same option and the same lines, with each recorded one swapped for a copy of its text under a
key of the mod, ml_text_<key>, which has no recording and shows as a subtitle with no voice. The global variable
ml_text_only, which settings.lua sets on every tick, picks one of the two. A twin of a sequence that ends in a decision
of its own goes to that decision with GoTo, as the game does between its sequences.

The texts of the copies come from the game's localization (text_ui_dialog.xml), in English and Spanish.

It runs at the end of generate_jobs.py and generate_orders.py, which write parts of these dialogs, and on its own:
    python -I mod/medieval_life/tools/generate_voice.py mod/medieval_life
It is idempotent: it takes out the twins and the conditions it added before, and puts them again.
"""
import os
import pathlib
import re
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
GAME_PLACES = (r"C:\Program Files (x86)\Steam\steamapps\common\KingdomComeDeliverance2", r"E:\SteamLibrary\steamapps\common\KingdomComeDeliverance2")
GAME = pathlib.Path(os.environ.get("KCD2_GAME") or next((p for p in GAME_PLACES if os.path.isfile(os.path.join(p, "Data", "Tables.pak"))), GAME_PLACES[0]))
LANGUAGES = (("English_xml", "English_xml.pak"), ("Spanish_xml", "Spanish_xml.pak"))
GAME_TEXTS = "text_ui_dialog.xml"

# The dialogs of the new character. The copies of the game's rent dialogs are for Henry only, and keep their voice.
DIALOGS = (
    "data/Quests/medieval_life/trosecko/ml_work/zavodniPodkovy/ml_work_dialog.xml",
    "data/Quests/medieval_life/trosecko/ml_work/nebakovObrana/ml_casual_dialog.xml",
    "data/Quests/medieval_life/trosecko/ml_work/nebakovObrana/ml_order_dialog.xml",
)
VARIABLE = "ml_text_only"
VOICE = f"gvar('{VARIABLE}') == 0"
TEXT = f"gvar('{VARIABLE}') == 1"
AND = " &amp; "
TWIN = "_text"
PREFIX = "ml_text_"
# The roles of the new character in these dialogs.
ROLES = ("HENRY",)


def edit(path, change):
    raw = path.read_bytes().decode("utf-8")
    crlf = "\r\n" in raw
    text = change(raw.replace("\r\n", "\n"))
    path.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))


def strip(text):
    """Takes out what an earlier run added."""
    text = re.sub(r'\n[\t ]*<Sequence [^>]*Name="[^"]*' + TWIN + r'"[^>]*>.*?</Sequence>', "", text, flags=re.S)
    text = re.sub(r'EntryCondition="\(([^"]*)\)' + re.escape(AND + VOICE) + '"', r'EntryCondition="\1"', text)
    text = text.replace(f' EntryCondition="{VOICE}"', "")
    return text


def spoken(response):
    """The key of the line a response says, not of its stage directions."""
    body = re.sub(r"<Parenthetical>.*?</Parenthetical>", "", response, flags=re.S)
    found = re.search(r'<Text StringName="([^"]+)"', body)
    return found and found.group(1)


def recorded(key):
    return key and not key.startswith("ml_")


def with_condition(tag, condition):
    found = re.search(r'EntryCondition="([^"]*)"', tag)
    if found:
        return tag.replace(found.group(0), f'EntryCondition="({found.group(1)}){AND}{condition}"', 1)
    return tag.replace("<Sequence ", f'<Sequence EntryCondition="{condition}" ', 1)


def sequences(text):
    """(open start, open end, close start, close end) of every sequence, nested ones too."""
    spans, stack = [], []
    for tag in re.finditer(r"<Sequence\b[^>]*>|</Sequence>", text):
        if tag.group(0).startswith("</"):
            start, end = stack.pop()
            spans.append((start, end, tag.start(), tag.end()))
        elif not tag.group(0).endswith("/>"):
            stack.append((tag.start(), tag.end()))
    return spans


def twins(text, keys):
    edits = []
    for start, open_end, close_start, close_end in sequences(text):
        inner = text[open_end:close_start]
        nested = re.search(r"<Decision\b", inner)
        own = inner[:nested.start()] if nested else inner
        lines = [m for m in re.finditer(r'<Response Role="([^"]+)"[^>]*?(?<!/)>.*?</Response>', own, flags=re.S)
                 if m.group(1) in ROLES and recorded(spoken(m.group(0)))]
        if not lines:
            continue
        tag = text[start:open_end]
        twin_tag = re.sub(r'Name="([^"]+)"', lambda m: f'Name="{m.group(1)}{TWIN}"', tag, count=1)
        twin_tag = with_condition(twin_tag, TEXT)
        if 'EndType="Decision"' in twin_tag:
            target = nested and re.match(r'<Decision\b[^>]*Name="([^"]+)"', inner[nested.start():])
            if not target:
                continue
            twin_tag = twin_tag.replace('EndType="Decision"', f'EndType="GoTo" GoToDecision="{target.group(1)}"', 1)
        body = own
        for line in reversed(lines):
            key = spoken(line.group(0))
            keys.add(key)
            # The stage directions have keys of their own, so the key of the line is there only once.
            changed = line.group(0).replace(f'StringName="{key}"', f'StringName="{PREFIX}{key}"', 1)
            body = body[:line.start()] + changed + body[line.end():]
        indent = text[text.rfind("\n", 0, start) + 1:start]
        twin = "\n" + indent + twin_tag + body.rstrip() + "\n" + indent + "</Sequence>"
        edits.append((start, open_end, with_condition(tag, VOICE)))
        edits.append((close_end, close_end, twin))
    for begin, end, new in sorted(edits, key=lambda e: e[0], reverse=True):
        text = text[:begin] + new + text[end:]
    return text, len(edits) // 2


def game_texts(keys):
    texts = {}
    for folder, pak in LANGUAGES:
        with zipfile.ZipFile(GAME / "Localization" / pak) as z:
            raw = z.read(GAME_TEXTS).decode("utf-8-sig")
        found = {}
        for key in keys:
            row = re.search(r"<Row><Cell>" + re.escape(key) + r"</Cell><Cell>[^<]*</Cell><Cell>([^<]*)</Cell></Row>", raw)
            if not row:
                raise SystemExit(f"{pak}: no text for {key} in {GAME_TEXTS}")
            found[key] = row.group(1)
        texts[folder] = found
    return texts


def write_texts(mod_dir, texts):
    for folder, found in texts.items():
        lines = "".join(f"  <Row><Cell>{PREFIX}{k}</Cell><Cell>{PREFIX}{k}</Cell><Cell>{v}</Cell></Row>\n"
                        for k, v in sorted(found.items()))

        def change(text):
            text = re.sub(r"  <Row><Cell>" + PREFIX + r"[^<]*</Cell>[^\n]*\n", "", text)
            if text.count("</Table>") != 1:
                raise SystemExit(f"{folder}: cannot find the end of the table")
            return text.replace("</Table>", lines + "</Table>")

        edit(mod_dir / "localization" / folder / "text__medieval_life.xml", change)


def main(mod_dir):
    keys, count = set(), 0
    for dialog in DIALOGS:
        def change(text):
            nonlocal count
            text, made = twins(strip(text), keys)
            count += made
            return text
        edit(mod_dir / dialog, change)
    write_texts(mod_dir, game_texts(keys))
    print(f"voice: {count} sequences with a text-only twin, {len(keys)} recorded lines copied as text")


if __name__ == "__main__":
    main((ROOT / sys.argv[1]).resolve())

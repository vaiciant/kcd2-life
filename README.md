# KCD2 Life (`medieval_life`)

**Requires [KCD2 Female Framework](https://github.com/vaiciant/kcd2-female-framework) and [KCD2 Male Framework](https://github.com/vaiciant/kcd2-male-framework).**

KCD2 Life turns *Kingdom Come: Deliverance II* (PC, game version 1.5) into a life in medieval Bohemia. Henry goes back to Rattay, and you stay behind as a nobody, with a life of your own. Find work, keep yourself fed, build a name across the Trosky region, and stay on the right side of the law.

> **From the pillory on, in any save.** The new life is there once Henry has been through the pillory in Troskowitz,
> early in the story: you do not need to finish the game. Add the mods to the save you are playing, with no new game.
> In that save, Henry's alchemy recipes are hidden while the mods are installed: the new character must start with none,
> and the game has no way to erase the recipes a player knows. Removing the mods gives them back. In a new game, Henry's
> own playthrough works with no problems. Keep a save from before the new life: it is the safest way back to Henry,
> since nobody has tested whether what the new character does can break one of his quests.

## A new life

- **A new start.** In Troskowitz, a wayfarer by the tavern wall offers a new life, from 08:00 to 20:00. Henry waits in that save, and you can play him again with `ml_switch`.
- **First steps.** Once the new life begins, five short notes in the game's tutorial window, in the voice of the world, tell you what you can do: sleep in any bed to save, work, run errands, and get a first haircut for free at any barber, such as Fiala in Zhelejov.
- **Who you are.** Choose a man or a woman, then go through the faces on the pillory stage with *Next Czech*, *Next Hungarian* or *Next Romani*. Every face is one of the game's common folk, never a lord or a character of the story. Type a name, or draw one from the names of the time and of that people.
- **From scratch.** Attributes start at 0 and skills at 1, and you know no alchemy recipes: you learn them as Henry did, from recipe pages and perks. Your clothes, weapon and money come from your origin, and everyone gets a torch:

  | Origin | Weapon | Money |
  |---|---|---|
  | Peasant family | Mace | 15 groschen |
  | Innkeeper family | Hunting sword | 40 groschen, and the steady job at the tavern |
  | Burgher family | Sword | 300 groschen |

- **A fresh map.** The places Henry found are hidden again, and so are his beds and homes on the map. The compass can still show one of his beds. The new character has no dog.
- **Kuttenberg** opens to the new character as it does to Henry: the coachman by Slatejov takes you there once Henry's story has reached the city. Before that, the game crashes while loading the city, so the mod does not open the road early.
- **A calendar of your own.** Your life starts on 1 June 1403, and the book of trades keeps the date. Months last 7 days, so a month is a week of work. With the optional [settings](#settings), you can switch to 14-day months or the real calendar.

## Work across the Trosky region

Every town and village of the region has work: its farms, shops, taverns and trades, and the people who run them.

- **Casual work.** Talk to the owner or the foreman between 08:00 and 18:00, or in the hours they keep in the game: the butcher of Troskowitz from 11:00, the scribe from 09:00 to 15:00, the greengrocer of Slatego from 10:00, and the farm of Křenový from 09:00. Out of hours, they tell you when they work. In hours, choose how many to work from what is left of the day. You need at least 2 hours, and a reputation of 35 with their people. Each hour pays 1.8 groschen and trains the skills of the trade, and costs hunger and energy, twice what the game takes on its own. The [settings](#settings) change all three. A day of 6 hours or more comes with a meal.
- **A steady job.** Some places hire you for a shift every day: 6 days of work and 1 off, with a meal per shift and a bed by your workplace. You need a reputation of 50. Arriving late two working days in a row, missing a shift, or arriving drunk or naked is a fault. Three faults within 14 days and you are dismissed. Leaving the region ends the job too.
- **The book of trades.** Your record of work: name, birth date (1382 to 1385), parents, the date of your new life, where you worked and for how long, and your errands. Lose it and a new one costs 5 groschen, with an empty record.
- **A bed for the night.** The seven places of the region that rent a bed in the game, the taverns of Troskowitz and Tachov, the inn of Zhelejov, the smithy of Tachov, the mill of Lower Semine and the huntsmen of Vidlak and Nebakov, rent one to the new character too, in the talk about work: 5 groschen a night, or 20 for the room at Zhelejov, and a week for the price of five nights. It is the same bed, yours until 10:00 of the last morning, and the map and the compass show where it is. A notice says until when, and another when it is over. With Realish Economy, a night costs 1 groschen, and 10 at Zhelejov. The game's own offer, such as "Can I spend the night here?", shows only while Henry plays: it gives the bed to him.
- **Every bed saves the game,** even a stranger's. The new life also saves once it starts, and shows the date of its first day.
- **A stash of your own.** In the Trosky region, every chest of the player opens the new character's own stash, also the camp of The KCD2 Camping Mod and the tent of Mercenaries. Henry's stash waits for him, and comes back with `ml_switch`. In Kuttenberg, where the mod has no work yet, the stash is still Henry's.

## Errands

Every business asks for errands on its own day of the week, and never farther than the next town. Each errand is a quest in the journal, with its marker on the map, and a paper slip in your inventory says what is due. With little reading skill, the slip's letters come out jumbled.

| Kind | What you do | Pay |
|---|---|---|
| Delivery | Take goods from the business to someone else | 1.5 groschen in the same town, 10 in the next town |
| Pickup | Fetch an order from someone else and bring it back | Half as much again, since you go there and come back: 2.3 groschen in the same town, 15 in the next town |
| Shopping | Take the money and buy the goods yourself | Whatever you save: the money always beats the price at a shop where your reputation is 50 |

- **Reputation.** Deliveries need a reputation of 40 with the business, pickups 50 and shopping 65. Each errand done raises it a little.
- **Trust.** A business offers pickups after 5 deliveries, and shopping after 15 errands of either kind. Working for it counts too: pickups after 50 hours as its steady employee and shopping after 80, or twice as many casual hours, 100 and 160. Each failure doubles what you need, with no limit, and the owner tells you to work more for them to win their trust back.
- **With a job.** Your employer gives errands too, like any other business.
- **Hours.** A business gives errands, takes them in and hands over a pickup only in its working hours, the same as its work. A pickup is not given in the last hour before the place you fetch it from closes. When an errand is due tomorrow or the day after, the owner says so as they hand it over. Out of hours, the owner tells you when they work.
- **Failing.** An errand runs out after 12 hours of the working day of the place it ends at: the clock stops while that place is closed, and the slip says when it is due. The business loses 10 points of reputation with you, you owe the value of the goods, and it gives you no work until you pay.
- **Theft.** Three unpaid slips in one town and the town's guards hear of it, wherever you are. When you come near its authorities, they stop you: the fine is 200 groschen plus what you owe.

The numbers above are the defaults. If errands are too hard for you, the [settings](#settings) change every one of them.

## Settings

With JerryYOJ's optional [Mod Configuration Menu](https://www.nexusmods.com/kingdomcomedeliverance2/mods/1423), KCD2 Life has its own page in the game's menu. Each save keeps its own settings, and they apply at once.

| Setting | Default | Range | What it changes |
|---|---|---|---|
| Calendar: days per month | 7 | 7, 14 or the real calendar | How long a month lasts. It can always go up, and go down only if today fits in the shorter month |
| Work: pay | 100% | 25% to 300% | The wage of casual work and of the steady job |
| Work: experience | 100% | 25% to 300% | The experience an hour of work gives |
| Work: hunger and tiredness | 100% | 0% to 200% | What an hour of work costs: 100% is twice what the game takes, 50% the same as the game |
| Errands: pay | 100% | 25% to 300% | What deliveries and pickups pay, and what you keep when shopping |
| Errands: time to do it | 12 h | 12 to 72 h | Hours of the working day of the place the errand ends at |
| Errands: days between errands | 7 | 2 to 7 | How often each business asks for each kind of errand |
| Errands: trust needed | 100% | 0% to 200% | The deliveries or hours of work before pickups and shopping. At 0%, every business trusts you from the start |
| Errands: reputation needed | 100% | 0% to 150% | The reputation each kind of errand asks for |
| Errands: reputation lost | 10 | 0 to 20 | Points a business takes off when one of its errands runs out |
| Errands: unpaid errands before the guard | 3 | 0 to 10 | Unpaid slips in one town before its guards hear of it. 0: never |

With the pay changed, the summary after work, the terms of the steady job, the errand offers and the slips say the new amounts. An errand offer says them in a second line: the dialog cannot put a number inside a line, so each amount the settings can give has a line of its own.

## How it works

- **A character of its own.** The new life is a second playable soul, `ml_player`, switched to with `SwitchPlayer`, as the game does with Godwin. Henry stays in the save, untouched.
- **Looks from the frameworks.** KCD2 Life only calls them: KCD2 Female Framework for a woman, KCD2 Male Framework for a man. They put the head and the body on `ml_player`, and the women's clothes fit through the female framework.
- **Its own Skald project.** `Quests/medieval_life.xml` holds the offer, the selector, the work, the steady job and the errands. It edits no vanilla quest, and NPCs get its dialogs through STORM roles (`addRole`), which join their menus. The only dialogs of the game it replaces are the four of the room rental, copied from your game when the mod is built, so that their options show only to Henry.
- **Data, not code.** Jobs, errands and origins live in `jobs.toml`, `orders.toml` and `origins.toml`. The tools write the Skald graphs, the items, the texts and the Lua tables from them.
- **Saves.** The mod's values live in a saved entity of the game's own class. The amount of the game's keyring says whether that entity is current, after a load or a region change. No new entity classes go into your saves.

## Requirements

- *Kingdom Come: Deliverance II* 1.5.
- [KCD2 Female Framework](https://github.com/vaiciant/kcd2-female-framework) and [KCD2 Male Framework](https://github.com/vaiciant/kcd2-male-framework).
- Optional: [Mod Configuration Menu](https://www.nexusmods.com/kingdomcomedeliverance2/mods/1423), for the [settings](#settings).

Without both frameworks, the mod starts nothing, and a notice in the game says which one is missing.

## Installing

Subscribe on the Steam Workshop, or download the three mods from Nexus Mods and put their folders in the game's `Mods` folder. Nothing else: no launch options and no tools.

**When.** Save with Henry next to the wayfarer by the tavern wall in Troskowitz, between 08:00 and 20:00, quit, install the mods, load that save and talk to him. From the moment the mods are installed, Henry's alchemy recipes are hidden, and they come back when the mods are removed.

## Compatibility

KCD2 Life works with the game alone, and is built to clash with as few mods as possible: it adds its own Skald project and patch tables (`*__medieval_life.xml`), and no entity classes to your saves. It has been played together with 47 other mods, among them The KCD2 Camping Mod, Mercenaries and Realish Economy: [TESTED_MODS.md](mod/medieval_life/TESTED_MODS.md) lists them. Others should work too. What can clash:

| What the mod does | Clashes with |
|---|---|
| Replaces the whole table `Libs/Tables/minigame/AlchemyRecipe.xml`: the game's recipes are hidden and the mod's copies take their place, so Henry does not see his recipes while the mod is installed | A mod that changes the game's own recipes, or replaces that table too. Mods that add new recipes with a table patch, such as ldpotions, work: the new character learns their recipes as Henry would |
| Replaces the four dialogs of the game's room rental, in `Quests/Final/Barbora/utils/roomrenting/` | A mod that replaces those dialogs too. Realish Economy changes the rental itself, `roomrent.xml`, and not its dialogs: they work together |

- **Realish Economy.** It makes the game's prices about a quarter. KCD2 Life finds it by itself and pays and charges a quarter too: the wages, the pay of errands, the money to buy, the debts, the money of the origins, the book of trades and the beds for rent. The offers, the terms of the steady job and the summary after work say those amounts.
- **The Nutrition Mod.** Work moves the clock by itself, so after it KCD2 Life ends the buffs of food and drink of that mod that would have run out in those hours.
- **Stashes.** Each region has one master chest for the player, and every chest of the player opens it. Before a switch, the one who stops playing takes what is in it, and the one who plays puts back what they took: so each one has a stash of their own. Mods whose chests open that master chest, such as The KCD2 Camping Mod and Mercenaries, follow it.
- **Mercenaries.** Starting a new life, `ml_switch` and `ml_uninstall` pay off the whole company first, as its own `merc_dismiss` does, and break its camp: men hired by one character would follow the other. Each one starts with none.

The faces, the barber and the clothing come from the two frameworks, and their own pages list what can clash with them.

**Playing Henry again.** `ml_switch yes` switches between Henry and the new character, under a black screen, and saves: the new life waits while Henry plays, and the mod stays quiet. It is a way out if the new character took one of Henry's quests and it broke the life. Use it with care: switching can break your KCD2 Life save.

**Removing it.** In the Trosky region, run `ml_uninstall yes` in the console. Under a black screen, it closes the mod's quests in the journal, the steady job and its bed, and the errands with their slips and debts. Then it switches the game back to Henry with `SwitchPlayer`, brings Mutt back and saves. Henry plays on with his own skills, inventory and map, and the mod stays off in that save. To remove the mods, quit and take them out: Henry gets his recipes back. What the new character did in the world stays, as it would for Henry. A save from before the new life is never touched, and it is the safest way back to Henry's story: nobody has tested whether what the new character did can break one of his quests. Loading a save of the new life with the mods removed also gives Henry back, as the game alone would.

## Roadmap

These are plans, not promises.

**0.2.0,** which takes longer:

- **Bigger mods:** played and tested with larger mods, beyond the 47 of [TESTED_MODS.md](mod/medieval_life/TESTED_MODS.md).
- **Kuttenberg:** work, businesses, errands and a life in the city.
- **Crime and bandits:** a life outside the law, with crime, bandits, fences and survival.

**Later:**

- **Careers:** higher posts and better pay, earned with the record in your book of trades.
- **Older faces,** with a choice of age.
- **Daily objectives** of the steady job in the journal.
- **Voices** for the people who hand you goods.
- **Allegiance:** swear loyalty to a lord, such as von Bergow or Jan Žižka.
- **Rank and property:** a house first, and with time a keep and a village to run.
- **War:** campaigns, sieges and raids.

## Developer mode

Players see three commands: `ml_status`, which writes the state of the mod in the console, `ml_switch`, to play Henry or the new character, and `ml_uninstall`, to remove it. The mod also has 40 test commands, which move the clock, give money, force an errand, go to a work site and so on. They stay hidden until developer mode is on:

- `ml_developer` in the console turns it on until the game closes;
- launching the game with `-devmode` turns it on by itself.

| Commands | What they test |
|---|---|
| `ml_goto <place>`, `ml_pos`, `ml_time <hour>`, `ml_days <n>` | Going to a work site or a town, the position, the clock and the calendar |
| `ml_money <n>`, `ml_beer`, `ml_schnapps`, `ml_eat`, `ml_needs` | Money, drink, food, and hunger and tiredness |
| `ml_job`, `ml_job_fault`, `ml_bed`, `ml_bed_remove`, `ml_compass` | The steady job and the employee's bed |
| `ml_orders`, `ml_order_force <business>`, `ml_order_expire`, `ml_order_trust` | Errands |
| `ml_rep`, `ml_rep_*`, `ml_crime_test`, `ml_crime_forget` | Reputation and theft |
| `ml_xp`, `ml_look_refresh`, `ml_w_dress`, `ml_w_gear`, `ml_w_shop` | Experience, the look, and women's clothes |
| `ml_tutorials`, `ml_sites`, `ml_stash`, `ml_rent` | The notes of the first steps, again, every work site with where its NPC is, whose things the master chest holds, and the bed rented for the night, with whether its prompt can be used |
| `ml_rent_bed stance`, `game` or `basic` | How a rented high bed, as in Zhelejov, is built, and the bed again with it |
| `ml_freeze` | Meant to stop the character's animation for videos and pictures. It does not stop it yet |
| `ml_lua <code>` | Runs Lua. It needs `-devmode` |

The pattern is short, if you want it for your own mod. The public commands register when the file loads. The test commands wait in a table, and one function registers them when developer mode turns on:

```lua
local function register(name, body, help)
	System.AddCCommand(name, body, help)
end

register("mymod_developer", "MyMod.Developer()", "Turns developer mode on until the game closes")

MyMod.DEVELOPER = {
	{ "mymod_money", "MyMod.Money(%line)", "Gives that many groschen" },
}

function MyMod.Developer()
	if MyMod.developer then
		return
	end
	MyMod.developer = true
	for _, command in ipairs(MyMod.DEVELOPER) do
		register(command[1], command[2], command[3])
	end
end

if System.IsDevModeEnable() then
	MyMod.Developer()
end
```

The commands live in `Scripts/MedievalLife/commands.lua`.

## Building from source

The faces and their meshes come from the frameworks, which build them from your own copy of the game. To build this mod, with Python 3.11 or later, from the root of the repository:

```bash
python -I tools/extract_game.py
python -I tools/install_mod.py mod/medieval_life
```

`extract_game.py` copies the game tables that the tools read from your game into `game_files/`, which git ignores: run it once, and again after a game update. `install_mod.py` first regenerates what comes from `origins.toml`, `jobs.toml` and `orders.toml`, and the recipes with the pictures of their pages, with the tools in `mod/medieval_life/tools`, then packs the mod and copies it to the game. The game must be closed. `generate_jobs.py` also copies the game's four dialogs of room rental from your game, so they are not in the repository.

## License

Free for any use, also in closed or paid work. The only condition: credit KCD2 Life where people can see it, like a line in your mod's description or credits. You do not need to include the license or publish your source. It does not cover the game's files or anything derived from them, such as the pictures of the recipes. See [LICENSE](LICENSE).

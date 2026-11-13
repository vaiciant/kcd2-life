# KCD2 Life: changelog

Every release is listed here, as it went out on Steam Workshop, Nexus Mods and GitHub. The builds made while working on one are not listed.

## 0.1.4

Errands follow Henry's story and who is still alive. Use it with KCD2 Female Framework and KCD2 Male Framework 0.5.0.

### New

- **Closed businesses in the book of trades.** A business the story has closed, or whose person is dead, says "Closed." instead of its days. What you owe it stays written.
- **An errand to someone who dies is called off.** You owe nothing, lose no reputation or trust, and keep what you carry.

### Fixes

- **Errands to closed places.** A business no longer sends you to Trosky castle while the story keeps it closed, or to the manor of Semine without its people.
- **Errands to the dead.** No errand goes to a business whose person is dead.

## 0.1.3

The book of trades keeps track of errands, the talks of work come first, and the work clock is steadier. A crash when opening a book after working is gone. Use it with KCD2 Female Framework and KCD2 Male Framework 0.4.0.

### New

- **Errands in the book of trades.** Its second page lists the businesses you know in the region you are in, town by town in the order you came to them: their hours, once you have talked to their people, and in how many days the next delivery and the next pickup or shopping come, once you have asked them for errands, worked there or taken one. What you do not know yet shows as "?", and so do pickups and shopping until the business trusts you with them. A slip says the hours of both businesses.
- **Each book keeps its own record.** Lose it and a new one starts empty; find it again and all of it is there.
- **The talks of work come first.** With an employer, work, the steady job, errands, pickup or shopping and the beds come before the game's own options, right after those of quests.
- **Voice** in Mod Configuration Menu, under Dialogs: off, the new character's lines in those talks show only as text at the bottom of the screen, with no voice and no lips moving.
- **More work settings:** the reputation an hour of work gives, a tenth of a point by default, up to 80; and the reputation needed for work by the hour, 35, and for a steady job, 50.
- **Going to work.** Agreeing turns the screen black with what you go to do, and you stay still from that moment. Then the clock opens and turns smoothly, with your hunger and tiredness going down.
- **Bigger meals.** A shift gives two bread rolls, three plums, two parsnips, an egg and water. A long day of work by the hour gives two pretzels, three peaches, three leeks, an egg and water, not fresh.
- **Rest.** The bed of the steady job is a good one now, and work tires you less: one and a half times what the game takes, while hunger stays at twice. A shift and a long night's sleep come out about even.
- **The notes of the first steps** all come at the start, a second apart, and wait while the inventory or a book is open.
- **Immersive Eating.** Reading the book of trades or a slip no longer plays its eating or drinking animation.

### Fixes

- **The game could crash when opening a book after working.** The work clock pressed the confirm button of the game's wait window, which left the game in a broken state. The clock now only shows the window. Opening the book is lighter too: its pages are ready before it opens.
- **The clock's numbers** no longer climb while you work.
- **The innkeeper of Troskowitz** talks about work with the new character even while she is angry with Henry.

## 0.1.2

Henry's prologue with the mods installed.

- **Henry's first recipes.** In Henry's own game, he keeps the two recipes he knows from the start, chamomile decoction and Saviour schnapps, so the prologue at Bozhena's can be finished. Before, the mod hid them with the rest of the game's recipes. The new character still starts with none.
- **License:** asking for donations or Patreon support for a mod that uses KCD2 Life is fine, as long as nothing in it is only for those who pay. Warhorse's rules do not allow selling KCD2 mods.

## 0.1.1

Settings for work and errands, the rented beds, and horses.

- **Settings.** In Mod Configuration Menu, next to the calendar, and each save keeps its own:
  - **Work:** pay, experience, and how hungry and tired it makes you.
  - **Errands:** pay, time to do one, days between errands, the trust and reputation they need, the reputation a failure costs, and how many unpaid errands bring the guards, or never.
  - With the pay changed, the summary after work, the terms of the steady job, the errand offers and the slips say the new amounts. An errand offer says its pay in a second line.
  - With the time of an errand longer than two days, the owner says you have a few days, and the slip says in how many.
- **The inn of Zhelejov.** Its rented room has a high bed, and you can now sit and sleep in it. Before, its prompt showed and nothing happened.
- **Nobody minds you by your rented bed.** Within 5 metres of it, while it is yours, nobody reacts to you being there, as by the bed of a steady job: the innkeeper of Zhelejov threw the new character out on waking up. It lasts through a sleep that goes past the end of the rental, and ends with it. Stealing is still a crime.
- **Horses.** The new character can buy a horse from the horse traders with their own money, and gets its saddle and bridle. Before, the trader asked about Henry: he said you already had a horse, Henry's, and counted Henry's money.
- **Summaries** of work write their amounts without trailing zeros: "+9 g.", not "+9.0 g.".
- **Kuttenberg:** the README and the Workshop page now say that it opens to the new character once Henry's story has reached it, as for Henry.
- **Known:** the inventory of the new character still shows Mutt. The game has no way to undo the bond with the player's dog, so the README and the Workshop page say it.
- **Developer mode:** `ml_settings` shows and changes the settings; `ml_rent` says whether the prompts of the rented bed can be used, and why not; `ml_rent_bed` chooses how a rented high bed is built.

## 0.1.0

The first release.

- **A new life.** After the pillory, a wayfarer in Troskowitz offers a new life: a man or a woman of the common folk, with a face, a name and a family of peasants, innkeepers or burghers. Attributes start at 0, skills at 1, with no recipes, and the map is hidden again.
- **First steps.** Five short notes tell the new character how to get by.
- **Work across the Trosky region.** Casual work by the hour in every town and village, in each place's own hours, and a steady job with a shift, a meal and a bed. The book of trades keeps the record.
- **Errands.** Every business asks for deliveries, pickups and shopping on its own day of the week, with a slip, a deadline in working hours, trust to earn, debts and the guards for those who steal.
- **A calendar of its own,** from 1 June 1403, with 7-day months, or 14-day months or the real calendar with Mod Configuration Menu.
- **A bed for the night,** or for a week at the price of five nights, at the seven places of the region that rent one.
- **Every bed saves the game.**
- **A stash of its own** in the Trosky region, also in the chests of The KCD2 Camping Mod and Mercenaries. Henry's waits for him.
- **Back to Henry.** `ml_switch` plays Henry or the new character, and `ml_uninstall` hands the game back to Henry before removing the mods.
- **Realish Economy.** With it installed, the mod pays and charges a quarter, like its prices.
- **Mercenaries.** Starting a new life and switching characters pay off the whole company first.

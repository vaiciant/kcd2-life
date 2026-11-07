# KCD2 Life: changelog

Every release is listed here, as it went out on Steam Workshop, Nexus Mods and GitHub. The builds made while working on one are not listed.

## 0.1.1

Settings for work and errands, and the rented beds.

- **Settings.** In Mod Configuration Menu, next to the calendar, and each save keeps its own:
  - **Work:** pay, experience, and how hungry and tired it makes you.
  - **Errands:** pay, time to do one, days between errands, the trust and reputation they need, the reputation a failure costs, and how many unpaid errands bring the guards, or never.
  - With the pay changed, the summary after work, the terms of the steady job, the errand offers and the slips say the new amounts. An errand offer says its pay in a second line.
  - With the time of an errand longer than two days, the owner says you have a few days, and the slip says in how many.
- **The inn of Zhelejov.** Its rented room has a high bed, and you can now sit and sleep in it. Before, its prompt showed and nothing happened.
- **Nobody minds you by your rented bed.** Within 5 metres of it, while it is yours, nobody reacts to you being there, as by the bed of a steady job: the innkeeper of Zhelejov threw the new character out on waking up. It lasts through a sleep that goes past the end of the rental, and ends with it. Stealing is still a crime.
- **Summaries** of work write their amounts without trailing zeros: "+9 g.", not "+9.0 g.".
- **Kuttenberg:** the README and the Workshop page now say that it opens to the new character once Henry's story has reached it, as for Henry.
- **Developer mode:** `ml_settings` shows and changes the settings; `ml_rent` says whether the prompts of the rented bed can be used, and why not; `ml_rent_bed` chooses how a rented high bed is built.

## 0.1.0

The first release.

- **A new life.** After the pillory, a wayfarer in Troskowitz offers a new life: a man or a woman of the common folk, with a face, a name and a family of peasants, innkeepers or burghers. Attributes start at 0, skills at 1, with no recipes, and the map is hidden again.
- **First steps.** Five short notes, in the voice of the world, tell the new character how to get by.
- **Work across the Trosky region.** Casual work by the hour in every town and village, in each place's own hours, and a steady job with a shift, a meal and a bed. The book of trades keeps the record.
- **Errands.** Every business asks for deliveries, pickups and shopping on its own day of the week, with a slip, a deadline in working hours, trust to earn, debts and the guards for those who steal.
- **A calendar of its own,** from 1 June 1403, with 7-day months, or 14-day months or the real calendar with Mod Configuration Menu.
- **A bed for the night,** or for a week at the price of five nights, at the seven places of the region that rent one.
- **Every bed saves the game.**
- **A stash of its own** in the Trosky region, also in the chests of The KCD2 Camping Mod and Mercenaries. Henry's waits for him.
- **Back to Henry.** `ml_switch` plays Henry or the new character, and `ml_uninstall` hands the game back to Henry before removing the mods.
- **Realish Economy.** With it installed, the mod pays and charges a quarter, like its prices.
- **Mercenaries.** Starting a new life and switching characters pay off the whole company first.

# Feature backlog

A plain-text backlog for the daily routine to read, since the "Tap & Hatch Alpha — Design Doc"
Claude Docs page isn't reachable from automated Claude Code sessions (the Claude Docs connector
isn't available inside cloud/routine sessions, only in regular claude.ai chats).

Add features under **To add**. When the routine implements one, it moves the line to **Shipped**
in the same commit.

This list mirrors the "Features to add" table in the design doc. Whenever one changes, update the
other to match (a session without the Claude Docs connector updates this file and says the doc
needs the same change). Priority: **Now** before launch, **Next** after, **Later** eventually.
Effort: S = a day or less, M = a few days, L = a week or more.

## To add

### Now

- **Launch setup** (S): real pass and product ids, item icons, game icon, thumbnails and description. Why: Robux items don't work in live servers until the ids are set.
- **Badges** (S): Roblox badges for first hatch, each area, first rebirth, a Secret pet and a full index. Why: cheap goals that show on player profiles.
- **Analytics** (S): AnalyticsService funnel (join, first hatch, area 2, first rebirth) and economy events. Why: prices and pacing can be tuned from real data.
- **First-session tutorial** (M): short prompts to tap, hatch, equip, grab a clover and open Upgrades. Why: players decide whether to stay in the first few minutes.
- **Index rewards** (S): a permanent bonus for discovering every pet in an area. Why: gives rare hunting a clear finish line.
- **Music and ambience** (S, partly done): area music with crossfades and a Music on/off setting are shipped; still to add are ambient sounds per area and a volume slider. Why: the game has effects but little atmosphere.

### Next

- **Trading** (L): two-player trade window, both confirm, short countdown, locked pets excluded, logged. Why: the biggest social feature in pet games.
- **Server events** (M): a giant chest the whole server taps open together, rewards by contribution. Why: brings players to one spot and to each other.
- **More areas** (M each): areas 6 to 8 with new eggs, pets and themes after Cosmic Void. Why: late-game players run out of goals.
- **Pet abilities** (M): some pets gain a perk, such as auto-collecting clovers, faster hatching or bonus gems. Why: pets matter beyond one power number.
- **Pet set bonuses** (M): pets belong to sets (by area, family or element); equipping 2, 4 or a full set unlocks stacking bonuses, like Diablo item sets: more coins, more luck, then a unique perk. Why: rewards building a team instead of just equipping the strongest pets, and gives older pets a use.
- **Clover streaks** (S): grabbing clovers in quick succession builds a streak that multiplies Luck XP, up to a cap; a few seconds without a clover resets it. Why: makes the luck track active and skill-based instead of just walking around.
- **Rebirth raises the luck cap** (M): the Luck level cap starts lower and grows with each rebirth; clovers collected at the cap are wasted, so capping out is the signal to rebirth. Why: links the two core tracks (coins and luck) and gives rebirth a clear purpose beyond a coin multiplier.
- **Weekly quests** (S): three bigger weekly goals alongside the daily quests. Why: a reason to come back across the week.
- **Offline earnings** (S): coins for time away at a reduced rate, capped at a few hours. Why: rewards returning without punishing breaks.
- **Hatch pity** (S): a guaranteed Rare-or-better after a set number of misses, shown on the egg. Why: fairer luck and fewer frustrated players.
- **Rebirth shop** (M): rebirth tokens spent on permanent perks, such as storage or auto-collect. Why: deepens the long-term loop.

### Later

- **Clans** (L): groups with shared goals and a clan leaderboard. Why: long-term social retention.
- **Gift passes** (M): buy a pass for another player in the server. Why: social spending without pressure.
- **Inspect players** (S): click a player to see their team and index progress. Why: status and showing off.
- **Low-detail mode** (S): a setting that hides decorations, particles and other pets. Why: smoother play on low-end phones.
- **Translation** (M): localization tables for UI text, starting with the most common languages. Why: reaches non-English players.
- **Live codes** (S): codes stored in a DataStore and edited from the admin panel. Why: new codes without publishing an update.
- **Save rollback** (M): admin command to restore a player's earlier save version. Why: fixes lost-progress reports.
- **Seasonal areas** (L): themed areas that return each year; their pets stay earnable in later years. Why: events without permanent fear of missing out.

## Known bugs

Noted to fix later; not features.

- **Material not displaying properly**: the Golden tier's `PetGold` MaterialVariant doesn't show correctly on repainted custom pet models (see `CustomModels.paintPart`).

## Shipped

- **Tiered hatches**: each hatch rolls the pet, its tier and its level (1 to 10) separately, luck improves all three, and pets have levels that multiply their power.

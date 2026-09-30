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
- **First-session tutorial** (M): short prompts to tap, hatch, equip, grab a clover and open Upgrades. Why: players decide whether to stay in the first few minutes.
- **Music and ambience** (S, partly done): area music with crossfades and a Music on/off setting are shipped; still to add are ambient sounds per area and a volume slider. Why: the game has effects but little atmosphere.

### Next

- **Trading** (L): two-player trade window, both confirm, short countdown, locked pets excluded, logged. Why: the biggest social feature in pet games.
- **Server events** (M): a giant chest the whole server taps open together, rewards by contribution. Why: brings players to one spot and to each other.
- **More areas** (M each): areas 6 to 8 with new eggs, pets and themes after Cosmic Void. Why: late-game players run out of goals.
- **Pet abilities** (M): some pets gain a perk, such as auto-collecting clovers, faster hatching or bonus gems. Why: pets matter beyond one power number.
- **Pet set bonuses** (M): pets belong to sets (by area, family or element); equipping 2, 4 or a full set unlocks stacking bonuses, like Diablo item sets: more coins, more luck, then a unique perk. Why: rewards building a team instead of just equipping the strongest pets, and gives older pets a use.
- **Rebirth raises the luck cap** (M): the Luck level cap starts lower and grows with each rebirth; clovers collected at the cap are wasted, so capping out is the signal to rebirth. Why: links the two core tracks (coins and luck) and gives rebirth a clear purpose beyond a coin multiplier.
- **Rebirth shop** (M): rebirth tokens spent on permanent perks, such as storage or auto-collect. Why: deepens the long-term loop.

### Later

- **Clans** (L): groups with shared goals and a clan leaderboard. Why: long-term social retention.
- **Gift passes** (M): buy a pass for another player in the server. Why: social spending without pressure.
- **Inspect players** (S): click a player to see their team and index progress. Why: status and showing off.
- **Translation** (M): localization tables for UI text, starting with the most common languages. Why: reaches non-English players.
- **Live codes** (S): codes stored in a DataStore and edited from the admin panel. Why: new codes without publishing an update.
- **Save rollback** (M): admin command to restore a player's earlier save version. Why: fixes lost-progress reports.
- **Seasonal areas** (L): themed areas that return each year; their pets stay earnable in later years. Why: events without permanent fear of missing out.

## Known bugs

Noted to fix later; not features.

- **Material not displaying properly**: the Golden tier's `PetGold` MaterialVariant doesn't show correctly on repainted custom pet models (see `CustomModels.paintPart`).
- **Hatch pity is shared across all eggs**: one counter (`HatchPity`) covers every egg, so a player can build up misses on the cheap Meadow egg and spend the guaranteed Rare-or-better on an expensive egg. It should be one counter per egg.
- **Clover streaks do nothing early in the Meadow**: clovers there give 1 Luck XP and the streak bonus is rounded (`WorldService.collectOrb`), so the first 6 clovers in a streak still give 1 XP before it jumps to 2. Use random rounding or fractional XP so every step counts.
- **Unclaimed weekly quests are lost**: a finished but unclaimed weekly quest disappears when the week refreshes (`RewardService.fillWeekly`). Claim finished quests automatically on refresh.
- **README is out of date**: it doesn't describe index rewards, hatch pity, clover streaks, weekly quests or offline earnings.

## Shipped

- **Low-detail mode**: a ⚙️ Settings toggle that hides map decorations (tagged `Decor`) and pet sparkles for smoother play on low-end phones; other players' pets already have their own toggle.
- **Tiered hatches**: each hatch rolls the pet, its tier and its level (1 to 10) separately, luck improves all three, and pets have levels that multiply their power.
- **Index rewards**: discovering every pet in an area's egg completes that area's Pet Index for a permanent +15% coin bonus, stacking per area; shown in 🐾 Pets and 📊 Stats, with a toast when an area completes.
- **Hatch pity**: an egg guarantees a Rare-or-better pet once 40 hatches pass without one, resetting the counter; progress ("Pity: N to guaranteed Rare+") shows on every egg's odds board, and a toast fires when the guarantee kicks in.
- **Clover streaks**: grabbing clovers within 2.5 seconds of the last one builds a streak that multiplies Luck XP by up to 2x; a longer gap resets it to normal.
- **Weekly quests**: three bigger goals (6x the daily goal, 5x the gems) alongside the daily Quests, refreshed every 7 days; shown in a new section of the 📜 Quests window with a countdown to the next refresh.
- **Offline earnings**: coins for time away, at 15% of your active earning rate, capped at 3 hours and skipped for disconnects under 2 minutes. They wait in a 💤 Offline window (menu button with a badge) that opens on join, shows how long you were away, and has a Collect button; it also explains the rules and estimates a full stretch away. Uncollected coins carry over up to the cap.
- **Analytics**: a `AnalyticsService` logs a first-session funnel (join, first hatch, area 2, first rebirth, each once per visit) and economy events for coins and gems spent on eggs, areas, upgrades and rebirth and gems earned from rebirth. Upgrade spending is logged too; Robux purchases are not yet.

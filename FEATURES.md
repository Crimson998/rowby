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
- **First-session tutorial** (M): short prompts to tap, hatch, equip, grab a clover and open Upgrades. Why: players decide whether to stay in the first few minutes.
- **Music and ambience** (S, partly done): area music with crossfades, a Music on/off setting and a music volume control are shipped; still to add are ambient sounds per area. Why: the game has effects but little atmosphere.

### Next

- **Trading** (L): two-player trade window, both confirm, short countdown, locked pets excluded, logged. Why: the biggest social feature in pet games.
- **Server events** (M): a giant chest the whole server taps open together, rewards by contribution. Why: brings players to one spot and to each other.
- **More areas** (M each): areas 6 to 8 with new eggs, pets and themes after Cosmic Void. Why: late-game players run out of goals.
- **Pet abilities** (M): some pets gain a perk, such as auto-collecting clovers, faster hatching or bonus gems. Why: pets matter beyond one power number.
- **Rebirth shop** (M): rebirth tokens spent on permanent perks, such as storage or auto-collect. Why: deepens the long-term loop.

### Later

- **Clans** (L): groups with shared goals and a clan leaderboard. Why: long-term social retention.
- **Gift passes** (M): buy a pass for another player in the server. Why: social spending without pressure.
- **Translation** (M): localization tables for UI text, starting with the most common languages. Why: reaches non-English players.
- **Save rollback** (M): admin command to restore a player's earlier save version. Why: fixes lost-progress reports.
- **Seasonal areas** (L): themed areas that return each year; their pets stay earnable in later years. Why: events without permanent fear of missing out.

## Known bugs

Noted to fix later; not features.

- **Material not displaying properly**: the Golden tier's `PetGold` MaterialVariant doesn't show correctly on repainted custom pet models (see `CustomModels.paintPart`).

## Shipped

- **Pet set bonuses**: each area's egg is a set; equipping 2, 3, 4 or 5 different pets from it (copies count once) unlocks the best step in `Config.SetBonuses` (coins at every step, luck from 4 pieces), with different sets adding together (`Formula.setProgress`, `Formula.setBonus`). Shown in 📊 Stats (coin and luck rows) and the 🐾 Pets inventory line. Per-family or element sets and a unique perk at the top step are not done yet.
- **Music volume**: a ⚙️ Settings row with - / + buttons sets music volume in 10% steps (`Settings.MusicVolume`, 0 to 1, validated in `SettingsService`), scaling `Config.Music.Volume`.
- **README brought up to date**: it now covers index rewards, hatch pity, clover streaks, weekly quests and offline earnings.
- **Rebirth raises the luck cap**: Luck level is capped at 30 plus 15 per rebirth with no upper limit (`Config.Luck`); at the cap clovers give no XP, the 🍀 HUD shows "(cap)", and the 📊 Stats and 🔁 Rebirth windows show the next cap. Rebirth resets Luck XP to 0, so each run climbs again to a higher cap. Saves already above their cap keep their XP but play at the cap until they rebirth.
- **Inspect players**: a 👥 Players window lists everyone in the server; tapping a name shows their equipped team (tier, level, rarity), rebirths, furthest area, eggs hatched and pet index progress (`SocialService` `InspectPlayer`, rate limited).
- **Live codes**: codes kept in a DataStore (`LiveCodes`), refreshed every minute on every server and managed from the 🛠 admin panel (add or update with gems and 2x coin/luck boost minutes, remove, list); built-in `Config.Codes` still work and win on a name clash. Rewards are validated and clamped (`Rewards.sanitize`).
- **Low-detail mode**: a ⚙️ Settings toggle that hides map decorations (tagged `Decor`, with their collision turned off locally so they don't become invisible walls) and pet sparkles for smoother play on low-end phones; other players' pets already have their own toggle.
- **Tiered hatches**: each hatch rolls the pet, its tier and its level (1 to 10) separately, luck improves all three, and pets have levels that multiply their power.
- **Index rewards**: discovering every pet in an area's egg completes that area's Pet Index for a permanent +15% coin bonus, stacking per area; shown in 🐾 Pets and 📊 Stats, with a toast when an area completes.
- **Hatch pity**: an egg guarantees a Rare-or-better pet once 40 hatches pass without one, resetting the counter; progress ("Pity: N to guaranteed Rare+") shows on every egg's odds board, and a toast fires when the guarantee kicks in.
- **Clover streaks**: grabbing clovers within 2.5 seconds of the last one builds a streak that multiplies Luck XP by up to 2x; a longer gap resets it to normal.
- **Weekly quests**: three bigger goals (6x the daily goal, 5x the gems) alongside the daily Quests, refreshed every 7 days; shown in a new section of the 📜 Quests window with a countdown to the next refresh.
- **Offline earnings**: coins for time away, at 15% of your active earning rate, capped at 3 hours and skipped for disconnects under 2 minutes. They wait in a 💤 Offline window (menu button with a badge) that opens on join, shows how long you were away, and has a Collect button; it also explains the rules and estimates a full stretch away. Uncollected coins carry over up to the cap.
- **Analytics**: `AnalyticsService` logs a first-session funnel (join, first hatch, area 2, first rebirth, each once per visit) and economy events: coins and gems spent on eggs, areas, upgrades and rebirth, and every gem source (quests, weekly quests, pet discoveries, rebirth and codes as Gameplay; daily rewards and gifts as TimedReward; gem packs bought with Robux as IAP), via a `DataService.onGems` hook so new gem sources are logged automatically. View it on the Creator Hub under Analytics → Funnels and Economy.
- **Badges**: a `BadgeService` awards Roblox badges for first hatch, each area (2 to 5), first rebirth, a Secret pet and a full Pet Index (hatchable pets only, so the paid Starter Pup is never required). Ids go in `Config.Badges` (0 = not created yet, skipped); the badges themselves still need creating on the Creator Dashboard.
- **Per-egg hatch pity**: pity is now counted separately for each egg (`EggPity`), so misses on a cheap egg no longer carry to an expensive one; each egg's odds board shows its own progress. Old shared pity progress resets.
- **Clover streak rounding**: streak-boosted Luck XP uses random rounding, so every streak step counts even when clovers give 1 XP.
- **Weekly quests auto-claim**: finished but unclaimed weekly quests pay their gems (with a toast) when the week refreshes instead of disappearing.

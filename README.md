# 🥚 Tap & Hatch 🐾

A Roblox pet simulator: tap for coins, pick up clovers to level your luck, hatch eggs for pets
that multiply your coins, unlock new areas, rebirth for permanent boosts, and do it again. The Robux shop sells small, fairly
priced items.

The whole game is code: the map, UI and pet models are all built from scripts, so the repo has
no binary place file. You build the place with [Rojo](https://rojo.space).

## Quick start

1. Install the tools with [Rokit](https://github.com/rojo-rbx/rokit): `rokit install`
   (this gives you Rojo, Selene and StyLua at the versions in `rokit.toml`).
2. Build a place file: `rojo build -o TapAndHatch.rbxlx`
3. Open `TapAndHatch.rbxlx` in Roblox Studio and press **Play**.

To edit live, run `rojo serve` and connect the Rojo Studio plugin instead of step 2 (see
[Working in Studio alongside the code](#working-in-studio-alongside-the-code)).

Saving in Studio needs **Game Settings → Security → Enable Studio Access to API Services**.
Without it the game still runs; your progress just resets when you stop (you'll see a warning in
Output).

## Going live with Robux

Every item starts with id `0`, which lets you test purchases for free in Studio (buying grants
the item right away). To sell for real:

1. Publish the place, then on the Creator Dashboard create the passes and developer products
   listed in [`src/shared/Products.luau`](src/shared/Products.luau).
2. Paste each id into its `Id` field, and keep `Price` matching the dashboard (it's only what
   the shop shows).

| Game pass | Price | What it does |
| --- | --- | --- |
| 👑 VIP | 199 | +25% coins, +1 pet slot, gold `[VIP]` chat tag |
| 🪙 2x Coins | 149 | Doubles all coins |
| 🤖 Auto Tapper | 99 | Taps 5×/second while you play |
| 🥚 Triple Hatch | 129 | Hatch 3 eggs at once (R at any egg) |
| 🐾 +3 Pet Slots | 99 | Equip 3 more pets |
| 🍀 Lucky Eggs | 149 | +25% luck (the odds shown on eggs include it) |

| Developer product | Price | Gives |
| --- | --- | --- |
| 🎁 Starter Pack (once) | 49 | 250 gems, 30 min 2x Coins, exclusive Starter Pup |
| ⚡ 2x Coins · 15 min | 25 | Coin boost |
| 🍀 2x Luck · 15 min | 25 | Luck boost |
| 🪙 / 💰 / 🏦 Coin packs | 19 / 69 / 179 | 10 min / 50 min / 3 h of your current earnings |
| 💎 Gem packs | 19 / 79 / 199 | 100 / 550 / 1,600 gems |

Purchases are handled the way Roblox recommends: a receipt is only confirmed after the grant is
saved, and receipt ids are recorded so a retried receipt is never granted twice.

### Built-in policy compliance

- **Odds disclosure.** Every egg shows the exact chance of each pet, calculated by the same
  function that rolls the hatch, including the player's own luck.
- **Paid random items.** Coins can be bought with Robux and coins buy eggs, so eggs count as
  paid random items. Players whose region restricts those (checked with `PolicyService`) don't
  see coin packs or luck items, and the server refuses to sell them.
- **No real-money trading.** There's no pet trading.

## What brings players back

| Loop | Hook |
| --- | --- |
| Tap → coins → upgrades | Tapping is the only way to earn coins; numbers climb every second and early upgrades are cheap |
| Clovers → Luck level | 🍀 clovers on the ground give Luck XP (more in later areas, 10× for golden Lucky Clovers). Every Luck level adds +2% luck, forever |
| Eggs → pets | Rarity reveals, a NEW! badge, a gem bonus for every new pet, server-wide shout-outs for Legendary and up |
| Pet Index | A collection book with silhouettes of pets you haven't found yet |
| Pet tiers | Combine 5 copies into the next tier: ⭐ Golden ×3 → 💎 Diamond ×8 → 💚 Emerald ×20 → 🌀 Void ×50 power, one at a time or all at once |
| Easy pet management | Duplicates stack into one card (×12), 🔒 lock favourites, one-click Equip Best / Craft All / Delete Weak, auto-delete chosen rarities on hatch, 150 storage |
| Quality of life | Free Auto Hatch at any egg, Full / Fast / Off hatch animation, Max-buy upgrades, open all gifts at once, ⚙️ Settings for sounds and other players' pets |
| Areas | Five themed areas, each with a new egg and a bigger multiplier |
| Rebirth | Trade coins for a permanent multiplier plus gems |
| Stats | The 📊 window (or the luck meter under your coins) breaks down your luck and coins per tap, plus lifetime totals |
| Goal tracker | Always shows the next target with a progress bar; a guide beam points to it once you can afford it |
| Daily streak | A 7-day reward cycle that grows each day |
| Playtime gifts | 8 gifts per session, then the round restarts |
| Quests | 3 at a time for gems, scaled to your progress |
| Social | +10% coins per friend in the server (up to +50%), global leaderboards, codes |
| Premium | Roblox Premium members get +10% coins (their playtime is what earns you Premium Payouts) |

Pacing (from an economy simulation run while tuning, active player, no purchases): second area in
~3 min, third in ~20 min, first rebirth around 20 min, fourth area in ~1.5–2 h, fifth as a
multi-session goal.

### How luck works

Luck multiplies the drop weight of Rare-and-better pets, and the odds shown on every egg
already include it. It adds up from four sources:

```
luck = (1 + Luck level × 2% + Egg Luck upgrade × 10% + Lucky Eggs pass 25%) × 2 if a 2x Luck boost is active
```

Reaching Luck level L takes `20 × L^1.6` Luck XP in total, so level 10 is about 800 clovers'
worth and level 50 about 10,400 (max level 200). Clovers give 1 Luck XP in the Meadow up to 5 in
the Cosmic Void. Luck is never reset by rebirth. Tune it in `Config.Luck`, `Config.Orbs` and each
area's `CloverValue`.

## Working in Studio alongside the code

Scripts live in `src/` and Studio content lives in `assets/`. Rojo copies both into Studio, and
anything that isn't in one of those folders is lost the next time the place is rebuilt.

**Setup (once):** clone the repo (GitHub Desktop is easiest), run `rokit install` and
`rojo plugin install`, then run `rojo serve` and press **Connect** in the Rojo plugin in Studio.

**See the map while editing.** The map is built when the game starts, so edit mode starts
empty. Paste this into the Command Bar (View → Command Bar) to show a locked preview, and run it
again to hide it:

```lua
print(require(game.ServerScriptService.Server.MapBuilder).togglePreview())
```

The preview is only a guide: it's deleted when the game runs and edits to it aren't kept.

**Where your Studio work goes:**

| You built | Put it in (Studio) | Save it as (repo) |
| --- | --- | --- |
| Map pieces: buildings, obstacles, decorations | `Workspace > StudioBuilds` | `assets/Workspace/<Name>.rbxm` |
| Your own screens and buttons (ScreenGuis) | `StarterGui > StudioGui` | `assets/StarterGui/<Name>.rbxm` |
| Things your scripts clone on the server | `ServerStorage > StudioAssets` | `assets/ServerStorage/<Name>.rbxm` |
| Things clients need (effects, sounds) | `ReplicatedStorage > StudioAssets` | `assets/ReplicatedStorage/<Name>.rbxm` |
| Pet or egg models | `ReplicatedStorage > PetModels` / `EggModels` | `assets/PetModels/<PetId>.rbxm` (see below) |

To save: group your work into one Model (Ctrl+G) or Folder, right-click it → **Save to File…**,
and save it into the matching `assets/` folder. The file name becomes its name in the game, and
saving again overwrites it. Rojo leaves anything you add in Studio alone, so nothing disappears
while you work. It's only included in builds once it's saved to a file.

**Scripts:** edit them in the `src/` files (VS Code works well), not inside Studio, because Rojo
overwrites Studio script edits. Scripts inside your saved `.rbxm` models are fine (except in pet
and egg models, which have scripts removed).

**Handing off to Claude (or a teammate):** commit and push in GitHub Desktop, then describe what
you changed and what you want next. They pull first, so your work is kept, and you click
**Pull origin** afterwards to get their changes; with `rojo serve` running, Studio updates live.

## Using your own pet and egg models

Every pet and egg has a generated look, so the game works with no art at all. To swap in your
own, add a model named after the pet's id from [`Pets.luau`](src/shared/Pets.luau) (e.g.
`Doggy`, `CandyDragon`) or the egg's id from [`Eggs.luau`](src/shared/Eggs.luau) (e.g. `Meadow`).
Anything you don't replace keeps its generated look.

| Replace | Put the model in | Named |
| --- | --- | --- |
| A pet | `ReplicatedStorage > PetModels` | the pet id, e.g. `Doggy` |
| A pet's tier versions (optional) | `ReplicatedStorage > PetModels` | `Doggy_Golden`, `Doggy_Diamond`, `Doggy_Emerald`, `Doggy_Void` (otherwise the normal model is repainted in the tier's colours) |
| An egg (world stand and hatch animation) | `ReplicatedStorage > EggModels` | the egg id, e.g. `Meadow` |

**If you edit in Studio only:** build the place once, then drag your models into those folders in
Studio and publish from there. Don't rebuild with Rojo afterwards, or the build replaces your
Studio changes.

**If you use Rojo:** in Studio, right-click the model → **Save to File…** and save it as
`assets/PetModels/Doggy.rbxm` (or `assets/EggModels/Meadow.rbxm`). The file name becomes the
model name, and every `rojo build` includes it.

What the game does with your model:

- **Size:** it's scaled so its largest side is about 2.6 studs for pets and 7 studs for world
  eggs. Add a boolean attribute `KeepScale` = true to the model to keep your own size.
- **Facing:** the pet faces the way the model's pivot faces (its front / LookVector). If a pet
  walks backwards, rotate the model's pivot in Studio (Model tab → Edit Pivot).
- **Safety:** scripts inside the model are deleted, so free Toolbox models can't run code.
- **Typos:** the server warns in Output about any model whose name doesn't match a pet or egg id.

To add a brand-new pet, add an entry to `Pets.luau`, add it to an egg in `Eggs.luau`, then
give it a model the same way.

## 🛠 Admin panel

For testing and debugging. It appears as a red **🛠 Admin** button on the right (or press **F2**)
for admins only: everyone in Studio, the place owner (for group games, members at rank 254+), and
any user ids added to `Config.Admins.UserIds`. Every command is checked again on the server.

It can give coins, gems and any pet at any tier; set luck level, boosts, areas, rebirths and
upgrades; make the daily reward, gifts and quests ready; switch game passes on or off for the
session; teleport between areas; simulate thousands of hatches to check the odds without spending
anything; show server info (save size, memory, whether data is saving); save now; and reset your
own data to a new player's (real purchases are kept).

## Tuning

All the numbers live in data modules, so balancing never means touching gameplay code:

- [`Config.luau`](src/shared/Config.luau): admins, pet tiers, rebirth curve, clovers, luck levels, bonuses, daily rewards, gifts,
  codes, rarities, sounds
- [`Pets.luau`](src/shared/Pets.luau): every pet (generated looks come from colours and features;
  see above to use real models)
- [`Eggs.luau`](src/shared/Eggs.luau): prices and drop weights
- [`Zones.luau`](src/shared/Zones.luau): areas, unlock costs, multipliers, lighting
- [`Upgrades.luau`](src/shared/Upgrades.luau): coin and gem upgrades
- [`Products.luau`](src/shared/Products.luau): Robux catalog

## Project layout

```
src/shared/     ReplicatedStorage.Shared    data + formulas used by server and client
assets/         your Studio work saved as .rbxm: map pieces, UI, pet and egg models
src/server/     ServerScriptService.Server  services (data, world, pets, economy, rewards, shop…)
                                            and MapBuilder (the map, with an edit-mode preview)
src/client/     StarterPlayerScripts.Client UI, pet rendering, world effects, input
tests/          Luau unit tests for the shared rules (odds, formatting, streaks, catalog)
```

The server is authoritative for everything. The client only asks (`Action` remote) and
displays. Taps are rate limited, clover pickups and hatches are distance checked, and player data
uses session locking so two servers can never save the same player.

## Checks

```sh
stylua --check src tests      # formatting
selene src                    # lint
python3 tests/run.py luau     # unit tests (needs the Luau CLI)
rojo build -o TapAndHatch.rbxlx
```

CI runs all of these plus a `luau-lsp` type check on every push and uploads the built place as
an artifact.

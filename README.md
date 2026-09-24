# 🥚 Tap & Hatch 🐾

A Roblox pet simulator: tap for coins, hatch eggs for pets that multiply your coins, unlock
new areas, rebirth for permanent boosts, and do it again. The Robux shop sells small, fairly
priced items.

The whole game is code: the map, UI and pet models are all built from scripts, so the repo has
no binary place file. You build the place with [Rojo](https://rojo.space).

## Quick start

1. Install the tools with [Rokit](https://github.com/rojo-rbx/rokit): `rokit install`
   (this gives you Rojo, Selene and StyLua at the versions in `rokit.toml`).
2. Build a place file: `rojo build -o TapAndHatch.rbxlx`
3. Open `TapAndHatch.rbxlx` in Roblox Studio and press **Play**.

To edit live, run `rojo serve` and connect the Rojo Studio plugin instead of step 2.

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
| Tap → coins → upgrades | Numbers climb every second; cheap early upgrades |
| Eggs → pets | Rarity reveals, a NEW! badge, a gem bonus for every new pet, server-wide shout-outs for Legendary and up |
| Pet Index | A collection book with silhouettes of pets you haven't found yet |
| Golden pets | Combine 5 copies into a pet with 3× power |
| Areas | Five themed areas, each with a new egg and a bigger multiplier |
| Rebirth | Trade coins for a permanent multiplier plus gems |
| Goal tracker | Always shows the next target with a progress bar; a guide beam points to it once you can afford it |
| Daily streak | A 7-day reward cycle that grows each day |
| Playtime gifts | 8 gifts per session, then the round restarts |
| Quests | 3 at a time for gems, scaled to your progress |
| Social | +10% coins per friend in the server (up to +50%), global leaderboards, codes |
| Premium | Roblox Premium members get +10% coins (their playtime is what earns you Premium Payouts) |

Pacing (from an economy simulation run while tuning, active player, no purchases): second area in
~3 min, third in ~20 min, first rebirth around 20 min, fourth area in ~1.5–2 h, fifth as a
multi-session goal.

## Using your own pet and egg models

Every pet and egg has a generated look, so the game works with no art at all. To swap in your
own, add a model named after the pet's id from [`Pets.luau`](src/shared/Pets.luau) (e.g.
`Doggy`, `CandyDragon`) or the egg's id from [`Eggs.luau`](src/shared/Eggs.luau) (e.g. `Meadow`).
Anything you don't replace keeps its generated look.

| Replace | Put the model in | Named |
| --- | --- | --- |
| A pet | `ReplicatedStorage > PetModels` | the pet id, e.g. `Doggy` |
| A pet's golden version (optional) | `ReplicatedStorage > PetModels` | `Doggy_Golden` (otherwise the normal model is painted gold) |
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

## Tuning

All the numbers live in data modules, so balancing never means touching gameplay code:

- [`Config.luau`](src/shared/Config.luau): rebirth curve, orbs, bonuses, daily rewards, gifts,
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
assets/         ReplicatedStorage.PetModels / EggModels  your own .rbxm models (optional)
src/server/     ServerScriptService.Server  services (data, world, pets, economy, rewards, shop…)
src/client/     StarterPlayerScripts.Client UI, pet rendering, world effects, input
tests/          Luau unit tests for the shared rules (odds, formatting, streaks, catalog)
```

The server is authoritative for everything. The client only asks (`Action` remote) and
displays. Taps are rate limited, orb pickups and hatches are distance checked, and player data
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

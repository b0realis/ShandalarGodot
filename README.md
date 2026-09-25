# ShandalarGodot

<p align="center">
  <img src="branding/logo-360.png" alt="ShandalarGodot" width="240">
</p>

> This project is a love letter to MicroProse MTG: to preserve that special
> 90s Shandalar feeling — the feel of playing early Magic, up to Fourth
> Edition, Alliances, and maybe Fifth — while still going for
> quality-of-life improvements, a modern spin on the gameplay, and the
> tools to go with it.
>
> The key is in the limitations. A specific, finite spell library is
> something you can get creative with, instead of losing time to an
> ever-widening card pool and its obsolescence. It can be fun, it can be
> creative, and — would you believe it? — it can even be relaxing. :)
>
> All the best to the players, and to the community for its help with the
> development. Good luck and good health to all!
>
> — b0realis

An open-source, from-scratch remake of MicroProse's 1997 *Magic: The
Gathering*, built in GDScript with Godot. Early Magic, a modern rules
engine, and the freedom to keep the game alive.

## Screenshots

<p align="center">
  <img src="branding/screenshots/main-menu.png" alt="ShandalarGodot main menu" width="960">
  <br>
  <em>The main menu with the optional original-game skin.</em>
</p>

<p align="center">
  <img src="branding/screenshots/duel-spell-chain.png" alt="A spell chain during a ShandalarGodot duel" width="960">
  <br>
  <em>A spell chain in progress during a duel.</em>
</p>

## Play — 0.40.3

**Duels, deck building, optional expansions, Booster Draft and LAN play.**

Download **[Shandalar 0.40.3](https://github.com/b0realis/ShandalarGodot/releases/tag/v0.40.3)**
for **Windows, Linux, Apple Silicon/Intel Mac, Raspberry Pi 5 ARM64 and web**.
Choose a standalone or original-skin package; the release includes launch
instructions, a separate skin download and SHA-256 checksums. You can also
run the source with Godot 4.7 (below): `main` carries **0.40.11**, the next
release in the making.

Play with an **897-card early-Magic core**, historic decks, four computer
opponents, local hotseat, Gauntlet, sealed decks and best-of matches with
sideboarding. Optional `Pack-1-DotP-complete.zip` finishes the eight set
checklists: its title-screen `1-tDotP` button can enable 373 additional set
entries, for **1,270 set entries / 901 unique rules identities**. The Deck Builder
supports large cards, live filters and keyboard browsing, **AutoDeck**, which
builds a deck from a set, a dealt pool or a pasted list to your wishes —
colours up to five, a gold deck, the rarity from pauper to rares only, classic
or non-classic lands, the Power Nine on or off — and a Stats window that audits
the mana base. The duel's keys are rebindable
under Options, Controls, and a controller's face buttons play beside the mouse.
Further optional packs
add **Fallen Empires, Ice Age, Homelands, Alliances, Portal and Portal Second Age**, with engine and AI support.
Adventure and public Internet matchmaking remain future work.

Card artwork and constructed pack ZIPs are intentionally not release downloads.
Every platform package includes the Python builders and
[construction instructions](docs/card-art-and-packs.md); no source checkout is needed.

## LAN play and Booster Draft

The desktop release includes local-network duels and
[random-draw knockout tournaments](docs/sgmanalink-tournaments.md), including
up to **20 players**, configurable match lengths and deck policies, an
organiser's Master Panel, graphical advancement and final standings.
[Computer seats](docs/sgmanalink-computer-players.md) use the same four local
opponents and separate Unfair challenge; choose how many to add to a tournament.
Tables are open by default — the Game Browser lists every duel on the network
by name, with its deck rule (bring your own or the host's assigned deck), and
joins with a click; switch on **Invitation only** to admit only the players you
send the invitation to. Use matching builds and enabled card catalogues on all
participants.
Internet play, permanent accounts and MElo are parked for now.

The game also includes an in-game [Booster Draft](docs/booster-draft.md): choose
sets/cards, open random packs, and build against a countdown with automatic saves.
Find it under Options; no command-line launcher is needed.

## Philosophy

**The limitation is the feature.** Preserve the finite early-Magic pool
and the 1997 feeling. Optional additions should leave that core intact.

**Port, don't invent.** The original game's decisions guide the remake;
quality-of-life changes and rules simplifications are explicit. The
[source history](Provenance.md) and [fidelity ledger](docs/simplified-cards.md)
keep those choices open to inspection.

**Strong play. Fair information.** Apprentice, Magician, Sorcerer and Wizard
are **non-cheating** opponents. They study their own deck, plan spells and
mana, and analyse combat without reading your hidden hand, secret library
order or future draws. Stronger difficulty means stronger analysis, never
free resources or special rules. See the [fair-play contract](docs/fair-play.md).

The separate, opt-in **Unfair — sees your hand** challenge gives Wizard
knowledge of your current hand. It is off by default, unrated, and not a
fifth standard difficulty; it still gets no future draws or rule exceptions.

**Open and testable.** The rules engine runs without graphics, every card
has its own documented implementation, and changes are checked through
regression tests and reproducible simulations. Godot keeps the project
independent and the source accessible.

Latest local verification ([The default has a name](docs/ROADMAP.md#2026-09-25--the-default-has-a-name-04011)):
**7,728 GUT tests / 344,783 assertions**, plus **299 Python tests**
(one platform-specific skip). The same gate runs on GitHub Actions for
every push and pull request.

## Art and skins

The game is playable with its built-in appearance. Choose a `-with-skin`
release for the original look and sounds, or add `original_skin.zip`
separately. Import packs through **Options → Skin**; on desktop they can
also live in `skin/` beside the game.

**Card pictures are not included in the repository or release downloads.**
Packages from 0.32.0 on for **all platforms** include the construction tools
and their required metadata in `tools/`, `cards/data/` and
`packaging/card_packs/`; no source checkout is needed. Older 0.20.0 downloads
do not include the numbered-pack builders. Use Python 3.10+ and run these
commands from the extracted game folder (Windows: use `py -3` for `python3`):

```sh
python3 tools/fetch_card_art.py --out cache/cardart
python3 tools/mtg_assets.py --from-cardart cache/cardart --out skin/cardart.zip
```

Run the ZIP command only after the download succeeds. This creates the base
card pictures. Numbered packs include their own set artwork; for example:

```sh
python3 tools/pack_3_ice_age.py fetch-art
python3 tools/pack_3_ice_age.py build cardpacks/Pack-3-Ice_Age.zip
python3 tools/pack_3_ice_age.py verify cardpacks/Pack-3-Ice_Age.zip
```

The [card artwork and pack guide](docs/card-art-and-packs.md) gives complete
commands for **Pack 1 (1-tDotP), Fallen Empires, Ice Age, Homelands,
Alliances, Portal and Second Age**, cache locations and platform-specific installation details.
It also ships as `CARD-ART-AND-PACKS.md` and is included in each package's README.

On desktop, keep `original_skin.zip` and `cardart.zip` in **`skin/`**, and
the exact-name `Pack-*.zip` files in **`cardpacks/`**, both beside the game
executable (beside `Shandalar.app` on Mac, never inside it). **Leave ZIPs
zipped.** Use **Options → Card Packs → Rescan**, then enable the packs.
The separate `packaging/card_packs/` directory is builder metadata, not an
installation folder. Completed packs and card art are never bundled in releases.

Web can import/fetch the skin and base cardart ZIPs into browser storage;
this build has no browser installation path for numbered gameplay packs.
Its included Python tools run on your computer and can build packs for desktop.

To rebuild the original skin from your own game installation:

```sh
python3 tools/mtg_assets.py --install /path/to/game
```

The importer reads your installation without changing it. See the
[player-files guide](docs/player-files.md) for pack locations and the
[skin catalogue](docs/skin-catalogue.txt) for creating your own skin.
Card pictures stay personal—do not include them in a public web build.

## DeckLab CLI

The desktop releases include a headless deck-analysis tool: run
computer-versus-computer duels in parallel, compare matchups or gauntlets,
and study win rates, confidence intervals, charts and CSV/JSON reports.
Seeded runs make it useful for experimenting with decks and comparing ideas.

Run `./deck_lab.sh --help` on Linux/macOS or `.\deck_lab.bat --help`
on Windows. `--procs` and `--jobs` control parallel workers;
`--no-elo` keeps experiments out of the ratings ledger.
The [DeckLab manual](DeckLab/README.md) has examples and all options.

## Post-0.20.0 roadmap

Work completed or planned after the 0.20.0 release:

- [ ] **Adventure** — the Shandalar world, quests and campaign.
- [ ] **SGManalink** — tournament-integrated booster opening and drafting.
  LAN duels, tournaments and the timed standalone draft builder are already
  available on `main`.
- [ ] **Commander mode** — dedicated rules and deck-building support.
- [x] **Cardpacks foundation + Pack 1** — optional, toggleable packs separate
  from the core pool; its [four-card mechanics/AI audit](docs/pack-1-mechanics.md)
  is complete.
- [x] **Pack 2 — Fallen Empires** — 102 additional card names (187 printings),
  a separate [Python construction tool and mechanics audit](docs/pack-2-fallen-empires.md),
  and live **Extras** filters in the Deck Builder. Build packs locally;
  generated ZIPs and card artwork are not distributed.
- [x] **Pack 3 — Ice Age** — 373 names (383 printings), including
  346 new identities and 27 reprints. The separate
  [construction script](tools/pack_3_ice_age.py), local artwork ZIP, Extras
  filter and [engine/AI integration audit](docs/pack-3-mechanics-audit.md)
  are implemented. All new identities have handlers; two digital adaptations
  are documented in Help and the simplified-card ledger. Build locally:
  `python3 tools/pack_3_ice_age.py fetch-art`, then
  `python3 tools/pack_3_ice_age.py`. ZIPs and downloaded artwork stay local.
- [x] **Pack 4 — Homelands** — 115 new names (140 printings), a dedicated
  [Python builder](tools/pack_4_homelands.py), local artwork, gold globe emblem,
  matching Extras medallions, expanded Help and an
  [engine/AI audit](docs/pack-4-homelands.md). Build locally with
  `python3 tools/pack_4_homelands.py fetch-art`, then
  `python3 tools/pack_4_homelands.py`. The ZIP and artwork stay local.
- [x] **Pack 5 — Alliances** — 144 new names (199 printings), a separate
  [Python builder](tools/pack_5_alliances.py), gold banner emblem, matching
  Extras medallions, expanded Help and [engine/AI integration](docs/pack-5-alliances.md).
  Build locally with `python3 tools/pack_5_alliances.py fetch-art`, then
  `python3 tools/pack_5_alliances.py`. Included in 0.32.0;
  generated packs and card pictures are not distributed.
- [x] **Pack 6 — Portal & Second Age** — 318 distinct names across 380
  original English printings, including 290 new identities. Two welcoming
  sets, large-symbol land previews, independent Extras filters and matching
  stone medallions. Saved decks remember artwork choices. Includes the five
  Second Age theme decks, both original starters and illustrated Help.
  See the [pack guide](docs/pack-6-portal.md). Build locally with
  `python3 tools/pack_6_portal.py fetch-art`, then
  `python3 tools/pack_6_portal.py`. Requires 0.40.9 or later; rebuild older Pack 6 ZIPs.
  ZIPs and downloaded art stay local.
- [ ] **Internet play and community MElo (Magic Elo)** — parked until
  resources allow. No authentication or ranking service is required for LAN play.

Experienced multiplayer, networking and backend developers are especially
welcome to help improve LAN play and explore those longer-term ideas.

With all six packs enabled: **2,359 set entries · 1,898 unique cards**.
Want to add another set? Follow the [card-pack authoring guide](docs/adding-card-packs.md).

See the [development roadmap](docs/ROADMAP.md#major-features-for-the-future)
for the longer record.

## Build and contribute

Use **Godot 4.7.2** for source development; export templates are needed to
build releases. Start with [DEVELOPMENT.md](DEVELOPMENT.md) and
[CONTRIBUTING.md](CONTRIBUTING.md) for setup and the test workflow.

```sh
godot -e --path .
./run_tests.sh              # the whole suite in one Godot
SHARDS=4 ./run_tests.sh     # the same suite over four
```

Explore the [architecture](docs/ARCHITECTURE.md),
[code map](docs/CODE_MAP.md), [card-authoring guide](docs/adding-cards.md)
and [cross-platform build guide](docs/release-builds.md).
Bug reports are welcome—include your platform, version, decks and duel seed
when possible.

## Thanks

Thank you to **Godot and GUT**, **MicroProse**, the **Shandalar and Manalink
community**, **[SlightlyMagic](https://www.slightlymagic.net/)** and **The Dojo**;
to **Ben Prew** and the [s30](https://github.com/benprew/s30),
[mage-go](https://github.com/benprew/mage-go) and
[mp_pic_tools](https://github.com/benprew/mp_pic_tools) contributors;
to [Forge](https://github.com/Card-Forge/forge), Scryfall, the artists, and
everyone who tested, documented or preserved this game.

Have fun, build something unexpected, and enjoy the duels.
**All the best, good luck and good health to every player!**

## Licence

Code and project-created assets: **[GPL-3.0](LICENSE)**.
Third-party components and fonts retain their own licences; see the
[asset inventory](game/art/README.md) and [provenance](Provenance.md).

## Legal

*Magic: The Gathering* is a trademark of Wizards of the Coast LLC.
This is an unaffiliated, non-commercial fan project. The original skin and
card pictures are separate from the source-code licence and remain the
property of their respective owners.

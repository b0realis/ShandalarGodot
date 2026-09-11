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
Gathering* ("Shandalar") in **GDScript** on the latest stable **Godot 4.7** —
chosen deliberately for its community size and full engine independence.

At its core is a modular MTG rules engine written for this project: pure
GDScript, no scene dependencies, fully headless-testable, with **every card
in its own documented file** so new cards and whole sets can be added without
touching engine code.

## Philosophy

The paragraph above is the brief, and **the limitation is the feature**: a
closed pool of about 900 early cards is not a shortfall to grow out of, it
is the thing being preserved. Everything below is how the brief becomes
code.

**Port, don't invent.** Where the 1997 game made a decision, that decision
wins. Its own string tables, its manual, its help file and its data files are
the authority, and they are consulted before anything is designed. When the
original is silent, the modern rules decide; when both are silent, the choice
is labelled as ours and says so at the site.

**Provenance is a first-class fact, not a footnote.** Every source is ranked
in [`Provenance.md`](Provenance.md) — Tier 1 the original's own files, Tier 2
decompilations, Tier 3 community reimplementations — and behaviour is marked
`[1997]`, `[s30]` or `[QoL]` where it lives. In a mixed tree, file dates
decide authorship. A negative finding is a finding: "the 1997 shell played no
music" is recorded so nobody has to derive it twice.

**Every shortcut is written down.** A rules simplification carries a
`SIMPLIFIED` marker at the site *and* a row in
[`docs/simplified-cards.md`](docs/simplified-cards.md), and a test pins the
marker and the ledger to each other so the two cannot drift. There are nine
such rows today. Fidelity you cannot audit is fidelity you cannot trust.

**The engine stays pure.** `engine/` and `cards/` are RefCounted only — no
nodes, no scenes, no input, no `game/`. All state moves through one mutation
surface. That is what makes the whole rules layer testable headless in
seconds, and what lets a headless AI-vs-AI harness measure a change in
thousands of games.

**Claims are measured, not asserted.** An AI change ships with a
before-and-after over thousands of simulated games against a null run at the
same seed, or it does not ship. Several plausible improvements have been
measured and thrown away.

**The 1997 art belongs to whoever owns their copy.** No original asset is
distributed here. The game reads art off the filesystem at runtime and is
fully playable with none of it, because every skinned path has a drawn
fallback of the same geometry.

## Status

**M1 — engine core: done.** Turn structure, priority, the stack, casting,
mana (including restricted mana and cost modifiers), activated / triggered /
static abilities, auras, a CR 613 layered continuous-effects pipeline,
combat (flying, reach, vigilance, trample, first strike, banding, rampage),
protection, regeneration, prevention, poison, phasing, copying, tokens,
control changes, ante, and state-based actions.

**M2 — duel screen: shipped.** **M3 — card pool: complete** — all **897**
cards of the eight 1997 sets, one documented file each, no stubs left.
**M4 — AI: attacking, blocking and casting audited and measured.**
**317 decks** ported with their provenance recorded.

Verified by **6058 tests / ~155 854 assertions** across 352 scripts, running
headless, plus a duel soak that plays whole games through the live UI.
Adventure mode (M5) is next — see [docs/ROADMAP.md](docs/ROADMAP.md).

## Quick start

```sh
# Run the test suite (headless; uses the pinned Godot in ../tools/godot)
./run_tests.sh

# Play whole duels through the live screen under Xvfb
./duel_soak.sh

# Open in the editor (Godot 4.7+)
godot -e --path .
```

## Play in the browser / on a tablet

```sh
./build_release.sh --web                                        # -> ../shandalar-build/web/
python3 -m http.server --directory ../shandalar-build/web 8000  # then open http://localhost:8000/
```

Any static host will do — the web build runs without threads, so there
are no COOP/COEP headers to arrange. On a touchscreen the game types the
mouse for your finger: tap clicks, hold and lift right-clicks, drag drags,
a swipe scrolls a list; *Options → Touch controls* is Auto / On / Off. The
table is landscape; a phone held upright gets a small picture. So far
this has been checked in a desktop browser pretending to be a tablet,
not on a real one.

The browser wears the art the same way the desktop does — as **two
zips** mounted in place: `original_skin.zip` (the 1997 material) and
`cardart.zip` (the card pictures). Choose either in *Options → Skin* or
drop it on the page, and the game keeps it (in the browser's own
storage, across visits); or serve the skin zip beside the page as
`skin/original_skin.zip` and the game fetches it once if it lacks a
skin — `./build_release.sh --web --skin` places it there, plain `--web`
never does. Whether the 1997 graphics are hosted anywhere is the
owner's call, not the build's; the card art is never hosted (`--web
--skin --cardart` puts `skin/cardart.zip` beside the page for a serve
on your own machine only — see below).

## The art, and how to reconstruct it

The repository carries **no 1997 assets and no card art**. Everything needed
to rebuild both is here; the art itself is yours, not ours. Neither step is
required to play — with no art at all, panels, buttons, cards and portraits
fall back to drawn equivalents of the same geometry, and nothing is
unreachable.

### 1. The 1997 art, from your own copy of the game

```sh
python3 tools/mtg_assets.py                          # what it needs, in full
python3 tools/mtg_assets.py --check   /path/to/game  # looks, writes nothing
python3 tools/mtg_assets.py --install /path/to/game  # imports, writes a zip
```

`--check` reports on seven groups of files separately — shell art, card
frames and mana symbols, portraits, fonts, sounds, the card database and the
coin-toss movies — so a partial install tells you exactly which parts stay
drawn. `--install` writes one archive whose inner folder is `skin/` — a
**skin zip**, which the game mounts as it is — the same shape as the
`original_skin.zip` a release offers as its own download beside the
game: put it beside the executable
as `skin/original_skin.zip`, choose it in *Options → Skin* (it is kept in
the game's `skins/` folder under its own name and worn from then on), or
drop it onto the running game's window — a tar.gz at any of these doors
(`skin/original_skin.tar.gz` beside the executable too) is repacked into
a zip of its name once, since only a zip can be mounted.
Nothing is unpacked. Would you rather have loose files? `tools/import_original.py --source /path/to/game`
fills the **skin folder** (`user://original_skin/`) instead, and *Use the
skin folder instead of the zip* on the same screen wears it alone.

*Options → Skin* shows every place the game reads for you by its path —
the skin zip, the skin folder, the card folder, the portraits folder and
the music folder — with what is in each; a face or a tune of your own is
**added** to the 1997 ones, never put in their place. Each place is a key
in `settings.cfg` (`skin_zip`, `skin_folder`, `cardpacks_folder`,
`portraits_folder`, `music_folder` under `[options]`), so any of them can
live wherever you like; the screen names the file.

The packaged build ships that zip, and the card art's (below), beside
`skin/SKIN.txt`, a generated catalogue (`docs/skin-catalogue.txt`,
`tools/skin_catalogue.py`) of every picture, font, sound, tune, movie and
portrait the game wears — format, dimensions, sheet grids and names — so
a skin can be drawn from scratch and checked with
`python3 tools/skin_catalogue.py --check my_skin.zip`. The catalogue's
*To draw your own* says how a zip is put together: a `skin/` folder at
the top, the files under the names listed, and whatever is missing the
game draws for itself.

It **reads your install and never writes to it.** A genuine 1997 install is
the best source: its raw `.SPR` and `.PIC` files hold seventy portraits, five
of which exist in no community conversion. Manalink 3.0 installs and s30
checkouts also work, and several `--install` flags can be combined.

The decoders are **standard library only** — `.PIC` (LZW + RLE), `.SPR`, and
an AVI header parser — so a bare Python 3 is enough. Two exceptions, both
optional and both announced rather than fatal: the coin-toss movies are
Microsoft Video 1 (CRAM) and are transcoded to sprite sheets with **ffmpeg**
or **gst-launch-1.0**, whichever you have; and Pillow is needed by exactly
one *fallback* path (cutting a community-converted portrait sheet).

The source movies travel in the archive beside the sheets they produced, so
the conversion can always be redone without the disc:

```sh
python3 tools/mtg_assets.py --transcode-movies /path/to/the/game/skin
```

### 2. Card art for the 897 cards, from Scryfall

```sh
python3 tools/fetch_card_art.py --out assets/cardart/
python3 tools/mtg_assets.py --from-cardart assets/cardart/ --out cardart.zip
```

Python 3 and a network connection, nothing else. It is deliberately polite to
the API, **skips what it already has** so an interrupted run just carries on,
and prints what it could not fetch rather than stopping. Run beside a shipped
binary — where `cards/data/` lives inside the `.pck` and cannot be opened as
a file — it asks Scryfall for the pool instead, one paged search per set.
The second line zips the folder as `skin/cardart/<card_name>.jpg` — a
**card pack**, kept apart from the skin zip because it is twice the size
and on another licence; it goes beside the executable as
`skin/cardart.zip`, or through the same *Options → Skin* row and drop
into the **card folder** (`user://cardpacks/`), where every zip is worn —
one per card set, as many as you like, the first to hold a picture
winning. **The card pack is never a release file and never hosted** —
the pictures are Scryfall's, on their own licence — so a release ships
these two scripts and nothing they fetch; `build_release.sh --package`
writes the pack to `../shandalar-build/local/` for play on this
machine, and the game zip that goes up carries no art at all.

### 3. Everything else

| To rebuild | Run | Needs |
|---|---|---|
| Card data (`cards/data/*.json`) | `tools/fetch_cards.py` | network — but it is committed, so you don't need it |
| Auto-generated cards and stubs | `tools/gen_cards.py` | the data above |
| Frozen set packages | `tools/build_card_packs.py` | network, or `--offline` |
| The Linux 64 build | `./build_release.sh` | Godot 4.7 + export templates; copy `export_presets.cfg.example` first |
| The web build | `./build_release.sh --web` | the same, plus the `web_nothreads` templates |

The 897 card implementations are **authored, not generated** — `gen_cards.py`
emits stubs, and the hand-written rules files are the project itself.

`docs/setup.txt` maps every path the built game reads or writes, and ships
beside the binary so players read the same file you edit.

## Getting oriented

| Read | To learn |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | The design: two-layer rule, one mutation surface, how everything fits |
| [docs/CODE_MAP.md](docs/CODE_MAP.md) | Where every file is and what's in it |
| [docs/adding-cards.md](docs/adding-cards.md) | How to add a card or a set (the most common contribution) |
| [docs/mechanics.md](docs/mechanics.md) | Every mechanic the engine implements, its CR rule and the class behind it |
| [Provenance.md](Provenance.md) | Every source, which outranks which, and the traps in reading them |
| [docs/simplified-cards.md](docs/simplified-cards.md) | The fidelity ledger: every card that deviates from its printed text |
| [docs/ai-difficulty.md](docs/ai-difficulty.md) | The four opponents: what the AI at each difficulty can and cannot do |
| [DeckLab/README.md](DeckLab/README.md) | The headless AI-vs-AI deck testing harness |

A taste of what a card looks like (`cards/sets/2ed/lightning_bolt.gd`):

```gdscript
extends CardScript
## Lightning Bolt — {R} — Instant (Alpha, common)
## Oracle: Lightning Bolt deals 3 damage to any target.

func build() -> CardData:
    return CardData.new("Lightning Bolt", "{R}", Mtg.CardType.INSTANT) \
        .spell(DamageEffect.new(3).any_target()) \
        .oracle("Lightning Bolt deals 3 damage to any target.")
```

## Thanks

This project stands on nearly thirty years of other people's work, most of it
given away for free.

**The Godot Engine team**, hugely and first. Godot made this possible in the
most literal sense: a genuinely free engine, with no runtime fee, no seat, no
licence server and no company able to change the terms afterwards — which is
exactly what a project that intends to still be here in ten years needs. Its
headless mode is why an entire rules engine and 6058 tests run in seconds in
a terminal; its Compatibility renderer is why a 1997 game's look runs on the
kind of machine people actually have; and GDScript is why a card is a
readable twenty-line file instead of a build system. Thank you for building
it in the open and giving it away.

**MicroProse**, for the 1997 game itself — a design good enough that people
are still taking it apart and rebuilding it three decades later. Its string
tables, manual and help file are quoted throughout this code as the authority
they are.

**The Shandalar and Manalink community**, who kept the game alive long after
its publisher stopped: the patchers, the DLL replacements, the people who
made a 1997 Windows program run on machines it was never built for, and who
documented what they found instead of keeping it.

**[SlightlyMagic](https://www.slightlymagic.net/)**, the forum that has been
the home of that work for years — Manalink development, card databases,
format documentation and the long threads where the file formats in
`Provenance.md` were originally worked out in public.

**The Dojo**, and the 1990s deck-building and strategy writing it collected.
Decks of that era survive because that community wrote them down; a good part
of the 317 decks here trace back to lists it preserved.

**Ben Prew and the 30th-anniversary authors** —
[s30](https://github.com/benprew/s30), its rules engine
[mage-go](https://github.com/benprew/mage-go), and
[mp_pic_tools](https://github.com/benprew/mp_pic_tools), whose `.PIC`/`.SPR`
decoding made the original's raw art readable at all.

**The Forge team** — [Forge](https://github.com/Card-Forge/forge), the open
Magic engine whose AI was read for what a competent player does at the
table (`docs/forge/`).

And everyone who converted, catalogued or simply archived a file so that
somebody later could find it.

## Licence

**GNU General Public License, version 3** — see [LICENSE](LICENSE).

Copyleft, so this stays free: anyone may use, study, change and share it,
and anything built on it carries the same freedoms forward. Version 3
because it is the current one, with the patent and anti-tivoisation terms
version 2 predates.

## Legal

*Magic: The Gathering* is a trademark of Wizards of the Coast LLC. This is an
unaffiliated, non-commercial fan project. Card names and rules text are used
under Wizards' Fan Content Policy, which requires that this stay
non-commercial.

### What travels with this source, and what does not

**Not this: no card image, no 1997 file, and no third party's restyle of
a 1997 file.** No artwork, font, sound, tune or movie owned by Wizards of
the Coast or by MicroProse is distributed here, and none ever will be —
nor is anybody else's redrawing of one, which is a separate promise and a
deliberate one. The game reads all of that off the player's own copy of
the 1997 game at runtime, where the player put it
(`tools/import_original.py`, `docs/player-files.md`); with none of it
present the game is complete and plays in a look of its own.

**This: twelve files, of exactly two kinds,** listed here one by one
because "some assets ship" is not a thing to leave vague. Each kind is
ours to hand on for a different reason, and the two reasons are not
interchangeable: what this project MADE, and what somebody else GAVE
AWAY under a licence that permits redistribution. There was a third kind
until 2026-09-09 — one sound, under a stranger's licence — and it is gone
because the sound was replaced with one of our own (`Provenance.md`, the row for `game/deck_builder/stone_grind.wav`).

**One — nine pictures and one sound, every one of them ours,** under
this project's own GPL-3.0.

| file | what it is |
|---|---|
| `game/art/set_icon_arn.png` | Arabian Nights, a scimitar |
| `game/art/set_icon_atq.png` | Antiquities, an anvil |
| `game/art/set_icon_leg.png` | Legends, a broken column |
| `game/art/set_icon_drk.png` | The Dark, a crescent moon |
| `game/art/set_icon_4ed.png` | Fourth Edition, a Roman `IV` |
| `game/art/set_icon_past.png` | Astral, a comet trailing sparks |
| `game/art/damage_marker.png` | the dagger a wounded creature wears |
| `game/icon.png` | the window and taskbar icon (`branding/logo.png` is its master) |
| `game/boot_splash.png` | the picture shown while the game loads |
| `game/deck_builder/stone_grind.wav` | the Deck Builder's filter-button cue, a quarter of a second of stone |

The seven in `game/art/` are drawn from scratch by
`tools/draw_our_art.gd` — polygons and arcs in code, no source file of
any kind — so the same command reproduces them byte for byte on a
machine that has never seen the 1997 game. The sound is made the same
way: noise, a filter and an envelope, generated rather than recorded.
`game/art/README.md` records each one's SHA-256;
`tests/ui/test_our_art.gd` holds the list to the folder, so a file that
arrived from anywhere else fails the suite.

**Two — one typeface, ours to pass on because its authors said so.**

| file | what it is |
|---|---|
| `game/art/fonts/Spectral-Regular.ttf` | Spectral Regular 2.005 (Production Type), the face the rules text, the duel log and the dialogs are set in when no skin is imported |
| `game/art/fonts/OFL.txt` | the SIL Open Font Licence 1.1 it is given away under, which travels with it into every build |

Fetched on 2026-09-09 from the family's own upstream, Google Fonts'
`ofl/spectral` directory, and hashed into `game/art/README.md` before it
entered the checkout. The OFL is a redistribution licence — that is what
it is for — and the licence file ships beside the font wherever the font
goes, which is what the OFL asks and what
`tests/ui/test_our_art.gd` asserts.

It is a FLOOR and not a replacement. `MPlantin`, the face the 1997 game
actually sets its rules text in, is Monotype's and is not here and never
will be; a player who imports their own copy of the original still gets
MPlantin, because the loader looks in every skin directory before it
looks at ours (`GameSkin.font`). Spectral is what a player who has
imported nothing reads instead of Godot's default sans.

**The sound, in detail, because it used to be somebody else's.**

| file | what it is | source | licence | SHA-256 |
|---|---|---|---|---|
| `game/deck_builder/stone_grind.wav` | the Deck Builder's filter-button cue: 0.250 s, 22 050 Hz, mono, 16-bit PCM, 11 068 B | ours — generated, not recorded | ours (GPL-3.0) | `4e61a797760ae9ccfd550073c0ca6233b094c5f2128ad9bd21d256ee9644da6e` |

It is the only sound in the game that did not come out of the 1997
install, which is why it ships inside the pack rather than being read
off the player's own copy (`game/deck_builder/deck_audio.gd`). It is
noise, a filter and an envelope, generated to simulate the sound of stone
scraping on stone.

`game/art/README.md` is the one inventory behind the tables above: it
carries the source and the SHA-256 of every row above except
`game/icon.png` and `game/boot_splash.png`, which are this project's own
and predate it. `tests/ui/test_our_art.gd` holds that inventory to the
files — a shipped asset that quietly stops shipping, or one that appears
with nothing said about where it came from, fails the suite.

Everything else the game needs it draws for itself, in code, at runtime.

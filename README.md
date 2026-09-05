# ShandalarGodot

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

Verified by **4241 tests / ~93 000 assertions** across 242 scripts, running
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
drawn. `--install` writes one archive whose inner folder is `skin/`, so it
unzips straight next to the executable.

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
```

Python 3 and a network connection, nothing else. It is deliberately polite to
the API, **skips what it already has** so an interrupted run just carries on,
and prints what it could not fetch rather than stopping. Run beside a shipped
binary — where `cards/data/` lives inside the `.pck` and cannot be opened as
a file — it asks Scryfall for the pool instead, one paged search per set.

### 3. Everything else

| To rebuild | Run | Needs |
|---|---|---|
| Card data (`cards/data/*.json`) | `tools/fetch_cards.py` | network — but it is committed, so you don't need it |
| Auto-generated cards and stubs | `tools/gen_cards.py` | the data above |
| Frozen set packages | `tools/build_card_packs.py` | network, or `--offline` |
| The Linux 64 build | `./build_release.sh` | Godot 4.7 + export templates; copy `export_presets.cfg.example` first |

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
headless mode is why an entire rules engine and 4241 tests run in seconds in
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
unaffiliated, non-commercial fan project. No card images, artwork, fonts,
sounds or other Wizards-owned or MicroProse-owned assets are distributed with
this source. Card names and rules text are used under Wizards' Fan Content
Policy, which requires that this stay non-commercial.

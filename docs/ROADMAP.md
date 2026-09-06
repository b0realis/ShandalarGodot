# Roadmap

The plan of record, and the honest list of what v0.1 simplifies. Every
simplification is also marked `SIMPLIFIED:` at the exact code site it
replaces, so `grep -rn "SIMPLIFIED:" engine/` always tells the truth.

## STATE AS OF 2026-09-02 — read this before the milestone sections below

The sections that follow are kept as the historical record, so several of
them describe a much smaller project than the one in the tree. Current
numbers:

| | |
|---|---|
| Card pool | **897 implemented, `cards/todo/` EMPTY** — M3 complete |
| Test suite | **4469 tests, 0 failing, 259 scripts** (129 349 asserts, ~290 s, the 2026-09-06 gate), `./run_tests.sh` exit 0 — and exit 0 MEANS something, see the review bullet below |
| Fidelity ledger | **6 live rows over 7 card files** (53 over 84 on the morning of 2026-09-02, 88 over 128 the day before), pinned to the `SIMPLIFIED` markers by `tests/test_simplified_ledger.gd` |
| Duel to-do | **cleared** (`docs/duel-todo.md`) |
| Rules forks | **7** in `engine/rules_options.gd`, all defaulting modern — and the fifth-edition side is now audited AS A SET, which is how its one HIGH defect was found |
| Modes | Magic Battle, Deck Builder, **Gauntlet** (the fourth 1997 mode, built 2026-09-02) |

**What moved on 2026-09-02.** A second day of concurrent passes; each has
its own section below.

- **The Gauntlet** — the mode this project never had, built in four slices
  from `docs/gauntlet-design.md`, which was written from Tier 1 strings
  plus the first survey of the Tier 2 decompilation.
- **AI sideboarding** — designed on 2026-09-01, built 2026-09-02, and it
  unblocked `--best-of` and `--sideboard` in the Deck Lab. The experiment
  the design named came back **emphatically non-zero**: Black-Red Raiders
  +13.2 match points, Blue Skies −13.1, and Black-Red against Blue Skies
  moving 18.3% → 53.3% on four Red Elemental Blasts. **The best deck is
  the one sideboarding costs most**, which is what a healthy sideboard
  format looks like.
- **The fifth-edition ruleset, audited as a whole for the first time** —
  and it found a HIGH defect no single-fork test could see: mana burn was
  charged AFTER the phase-end lethal check, both firing on the same
  boundary, so a player burned from 3 to −2 lived through a whole extra
  phase. Neither fork was wrong alone.
- **The AI uses its cards** (2026-09-02). The pilot activated four ability
  shapes it had special cases for and cast every instant at sorcery
  speed; a Rod of Ruin, an Icy Manipulator, a Jayemdae Tome sat idle,
  Fireball was always X-max, Wrath came down on a board it was winning,
  Dark Ritual was cast into an empty hand, the all-in attack ignored the
  blocks, and first strike and regeneration were invisible to combat.
  Now: `EffectIntent` reads every effect list by class (one table for the
  card-local ones), one scorer prices every activated ability at three
  moments (our main, their upkeep, their end step as the mana sink), X is
  sized to the job, removal and draw are HELD for their combat and their
  end step with the mana reserved, and combat reads first strike, shields
  and trample on both sides. A/B against the old pilot over 1000 games:
  **65.5% as Wizard, 55.9% as Apprentice**, profiles still ordered, 0
  stalls; 35 tests in `tests/ai/test_ai_capabilities.gd`, one per fixed
  weakness (DeckLab/README.md has the before/after matrix). The switches
  were already wired end to end (setup screen `AI difficulty:` picker and
  `Sideboard between duels` box, Lab `--profile-a/-b` and `--sideboard
  on|off`); they explain themselves on hover now and the Lab's help no
  longer claims the AI cannot sideboard. Tried and reverted on the same
  seeds: firing held burn at the face to dodge a cleanup discard (−0.6
  points on two seeds — a seven-card hand is usually spare lands).
- **One-to-many blocks** (CR 509.1b) — the last hole in combat. Building
  it exposed a latent bug: damage requests were built per BAND rather
  than per blocker, so a creature blocking two attackers would have
  struck twice.
- **The territory background selector** — all fifteen `Terr_*` grounds
  imported (ten manifest rows that had never been written, not the
  "Manalink-only art" the docs claimed), with a fallback that paints all
  fifteen with no skin at all.
- **Audio rebuilt** — a voice pool instead of one player, the music map
  (twenty overworld tracks, not one), and five cue defects including
  every creature announcing itself twice and every permanent arriving
  sounding like a creature.
- **Set badges on the title screen**, and the HIGH cost-record defect
  fixed, and a human can finally click an ability as a target.
- **Two code reviews, and what they found.** The exit-134 every run had
  ended in for weeks, written off as GL teardown, was our own static
  card table destroyed after the card scripts it points into — the
  `Lifecycle` autoload now drops it first, and `run_tests.sh` requires
  exit 0. The second review then caught the SAME shape once more:
  `DeckFilter`'s static facts table was keyed by the `CardData` objects
  themselves, so every run that had opened the Deck Builder (the
  windowed game included) still aborted on Exit; it is keyed by
  instance id now, and holds nothing. Two reference cycles went with
  it: the undo journal kept a pointer back to the game it journals (a
  game with a search open never freed), and Al-abara's Carpet bound the
  game itself into the shield it leaves on the player (a duel that
  ended with the Carpet unfurled leaked whole — the Carpet's filter
  holds a `WeakRef` now, and uses the shield list's own `all_turn` flag
  instead of re-arming). Smaller: `sim_results/` carries a `.gdignore`
  now and the Deck Lab writes one into any run directory inside the
  project — `deck_lab.sh`'s warm-up `--import` pass had been reading
  every run's `matchups.csv` as a translation table and had written 333
  `.translation` resources beside them. Also from the reviews: the undo
  journal covers resolution, damage and death (it covered neither
  before, whatever its doc said — 32 tests pin the move menu now); the
  Gauntlet refuses your own illegal deck in the original's words instead
  of silently playing White Knights; the ledger and the markers are
  pinned to each other by a test, which found two unmarked cards; and
  the Options sliders write the settings file once per drag rather than
  once per pixel.
- **Ten whole duels through the live screen** (2026-09-02). The duel
  to-do list was empty and every test passed, but nothing had ever
  watched an entire duel play out through `DuelScreen` itself — the
  coin toss, the opening hands, every spell flight and arrow, the
  end-of-duel window — with the engine's errors counted. A probe did
  (AI vs AI under Xvfb, every shipped deck on each side, ten seeds,
  every duel to a winner) and found two things the suite could not:
  `SpellFlight` re-routing a spell already in flight freed the old
  ghost under its live tween, and Godot FINISHES a tween whose target
  is gone, so the landing lambda fired on a freed capture — 37 errors
  in three duels; the stale tween is killed now and the landing looks
  its ghost up by instance id. And `CoinToss.run` set an explicit
  `size` on a full-rect node, which Godot warns about once per duel;
  the assignment was redundant (the anchors preset had already resized
  it) and is gone. Ten duels now finish with zero errors and zero
  warnings. The probe is now `./duel_soak.sh` (`tools/duel_soak.gd`),
  and since later that day it also plays seat 0 as a HUMAN seat driven
  by a clicker that goes through the screen's own input paths — the
  targeting cursor, the prompts, the hand window — so those are soaked
  too, as a fuzzer rather than a player. Still not proven by it: a
  human choosing WELL; that is what the tests and the screenshot tour
  are for.
- **The 1997 decks, ported** (2026-09-02, `docs/decks-1997.md`). Every
  deck group the mtg.wiki preconstructed-decks page lists, transcribed
  from named sources and never invented: the **55** enemy decks of the
  base game (s30's tomls, `Decks.zip`'s 1997 prefix and mage-go agree
  55/55; the colour-keyed `.v` sections folded into one sideboard), the
  **55** *Spells of the Ancients* enemy decks (`Program/decks/*.dck`), the
  **25** *Duels of the Planeswalkers* enemy variants the wiki has (no
  local copy exists), the 22 "Play Deck" folder decks by designer
  (**5** Coyote Tex, **8** Kevin Bane, **9** other), and a separate
  **community** group of **13** period decks (The Deck, Necro, Sligh,
  Turbo Stasis, Señor Stompy, the eight Pro Tour Collector Set decks) —
  170 files under `decks/1997/<group>/` and `decks/community/`, each
  declaring its heading and citing its source with its tier. Found on
  the way: `../shandalar-src/Decks.zip` is a **2016 Manalink** file whose
  every deck is the 1997 list followed by an appended modern deck
  (`Provenance.md`). Every MicroProse deck is proxy-free; every community
  deck carries proxies (73 Ice Age / Fallen Empires / Homelands /
  Alliances names — the proxied-card table is in the doc, the snapshot
  in `tests/unit/test_decks_1997.gd`), so the gauntlet's default roster
  is the strict-loadable subset **[QoL]**, the pickers and the Deck
  Builder's Load list carry a heading per group, and the Deck Lab's
  `--group` reaches into the subfolders while its default field stays
  the five starters. No card was implemented for this.
- **The non-MicroProse decks, widened and split** (2026-09-02, later;
  `docs/decks-1997.md`). The owner's follow-ups: "13 decks is thin", and
  file them three ways. Now **76 tournament** lists in
  `decks/tournament/` (Worlds 1994–97, Pro Tour New York and Dallas 1996
  with the Collector Set eight, PT Dallas Type I Classic, Origins 1995,
  Sorcerer's Open 1995, Finnish Nationals 1996, plus four Old School
  community-event winners filed by the tie-break rule and flagged as not
  DCI-sanctioned), **64 community** decks in `decks/community/` (the
  five archetype lists, eight dated versions of Weissman's The Deck
  1994–97, the 1993–96 combo and aggro lists Menendian dates, and Abe
  Sargent's 39 re-tuned Shandalar enemy decks from his 2009 *Kitchen
  Table* series — every one proxy-free, each naming the original it
  re-tunes), and **15 extended community** lists in
  `decks/extended_community/` (Old School 93/94 archetype references
  2014–18, Comer's 1997 Re-Animator). 312 ported files in all; a deck
  went in only with a citable list, and the doc lists what was looked
  for and not shipped (sideboard-only and partial pages, limited events,
  1998+, the Old School archetypes with no text list, reddit blocked,
  the forum's "not verbatim" lists). `DeckGroups` has `TOURNAMENT` and
  `EXTENDED_COMMUNITY` headings, `--group tournament` /
  `extended_community` in the Deck Lab, a count pin and a proxy snapshot
  per group in `tests/unit/test_decks_1997.gd`; the gauntlet's default
  roster is now **216** — the 54 proxy-free non-MicroProse decks are
  dealt. mtg.wiki's event pages, Menendian's *Old School Magic* and
  Sargent's series are registered as Tier-web in `Provenance.md`. No card
  was implemented; `cards/` and `engine/` untouched.

**What moved on 2026-09-01**, in one line each:

- **§6.8, the damage-prevention window** — the largest 1997 rules
  structure the project lacked, built as the seventh `RulesOptions` fork,
  with the damage marker and an AI heuristic so it is a ruleset rather
  than a one-sided buff. Measured: no effect on the shipped gauntlet
  (which holds one Fog and two regenerators between five decks) and
  **±12-14 points** on decks built from the cards it is about.
- **The card pool finished** — 59 stubs graduated plus Nalathni Dragon,
  and the pool DEFINITION was found to be one category short (DragonCon
  promos), not merely one card.
- **The era-correct restricted list** — the modern Vintage list was
  missing **eleven** cards that were restricted in the 1990s and have
  been unrestricted since. See the section below.
- **Proxies and deck import**, with the boundary that a proxy can never
  reach `MtgGame`.
- **A third of the fidelity ledger lifted**, after finding that ~21 rows
  rested on a premise that stopped being true when §1.3 shipped.
- **A general code review** — 13 fixes including a `CardRegistry` data
  race that segfaulted an 8-thread probe, and the Deck Lab scoring draws
  as wins for deck B.

**Three separate times that day, a green test was found pinning a defect
as correct** (Ydwen Efreet, Glyph of Reincarnation, Personal
Incarnation). A passing suite is not evidence of correctness when the
test was written from the same misreading as the code — when lifting a
simplification or fixing a card, check whether an existing test is
holding the old behaviour in place.

## The audio pass (2026-09-03) — music, the phase cue, and the sfx audit

Three defects from the owner's playtest, quoted in the files that fix
them. What landed, and what is deliberately still open.

**A — the music.** *"Music in the duel is wrong — now it is repeating a
short sample."* It was: `Dueltune.wav` — **ten** seconds (22 050 Hz 16-bit
stereo, 10.08 s) with `LOOP_FORWARD` patched onto it, so a ten-minute
duel is sixty repeats of one bar and sixty clicks. The original has **twenty-seven** loopable beds, not one
(`Dueltune`, `LocMus0..19`, `Tmplmus1`, five castle themes); twenty were
in the manifest and one of them played. Now [MusicLibrary] lists all of
them plus whatever the player drops into `user://music/`, and
[MusicPlayer] plays them through an `AudioStreamPlaylist` — whole tracks,
looped as a set, crossfaded so the seam cannot click, capped at eight
resident (27 tracks are 76 MB of PCM), with the shuffle and the place in
it held `static` so a duel ending does not restart the music. The choice
— shuffle, the 1997 single bed, or one named track — is one `Settings`
key with the Options screen as its only view.

**B — the phase cue, which turned out to be no cue at all.** The first
reading of the playtest was *"phases should have a typical phase sound"*,
and a `GameAudio.play_phase()` over the original's own `EndPhase.wav`
(`WAV_ENDPHASE = 4`, `defs.h:2186`) was built and then removed the same
day, because the owner settled it the other way:

> *"The changing phases or combat phases have no sound by themselves.
> Card action and other actions that happen in phases have sound
> effects."*

**So a phase change is SILENT, and the rule for the whole audio layer is
that every sound must be traceable to an ACTION** — a card cast, a land
tapped, a creature attacking or dying, damage landing, the coin, a
button — and never to the clock. `EndPhase.wav` is therefore deliberately
NOT imported (`tools/import_original.py`, the `sfx_phase` note; the
reasoning is in `game/audio.gd` under "NOT A PHASE CUE") so that nothing
can quietly grow one back. Two existing cues break the new rule and are
in the table below.

**C — the sfx audit.** One cue was provably wrong and is fixed:
`sfx_button` was importing `autoplay/Button.wav`, the CD AutoPlay shell's
1 732-byte blip, because the importer's index was keyed by bare filename
and a 1997 install holds three files called `Button.wav`. Candidates now
name their directory and the walk is sorted, so the answer is the same on
every machine. The rest of the map re-checked clean against
`shandalar-src/src/defs.h:2179` and its call sites.

### Still open, and why (the honest list)

| Item | What is uncertain | What would settle it |
|---|---|---|
| **The untap step sweeps `Untap.wav`** | `DuelAudio.cue_for` answers `BECAME_UNTAPPED` with `sfx_untap`, and the untap STEP fires that once per permanent (coalesced to one sound). Nobody did anything: this is a phase making a noise by itself, which the owner's ruling forbids. The same event also covers an effect-driven untap (Candelabra, Tawnos's Coffin), which IS an action, and the event carries no cause to tell them apart. | One line in `game/duel/duel_audio.gd` — return `""` for `BECAME_UNTAPPED` — plus the matching row in `tests/ui/test_duel_sound.gd`. Costs the (rare) effect-untap cue; `WAV_UNTAP` has no call site in Manalink's C anyway, so nothing is lost that was sourced. **A `game/duel/` file: the duel-screen agent applies it.** |
| **`EndTurn.wav` fired off the turn COUNTER** — *fixed the same day by the duel-screen pass* | `duel_screen.gd` played `sfx_end_turn` whenever `game.turn_number` changed: the clock, not an action, and the only cue in that file that was not something a player or a card DID. | Removed. `EndTurn.wav` is now imported and unplayed; the original's only known call site is `ai.c:588`, where the **AI ends its turn** — a seat performing the pass — so a future pass could re-hang it there, on the ACTION, and nowhere else. |
| **`DIES` plays `Buried.wav`** | s30 uses **`Kill.wav`** for creature death — proved by decoding its `creature_death.ogg` to 75 776 bytes of PCM, which is `Kill.wav`'s data length exactly. Neither `WAV_BURIED = 1` nor `WAV_KILL = 25` has a call site in Manalink's C; both are the exe's. The 1997 glossary says **bury** = "to the graveyard, no regeneration" (p. 163), which fits a creature dying, but so does *kill*. The enum is alphabetical, so its order says nothing. | The Tier 2 decompilation, which is not in this tree: find `play_sound_effect(1)` vs `(25)` near the graveyard path. **Do not change it on s30's word alone** — that is Tier 3 against a plausible reading of the filenames. |
| **`Cancel.wav` is never played** | `deckdll.cpp:2040-2056` loads `DuelSounds\cancel.wav` into slot 5 beside `button.wav` in slot 4, so the original has a distinct CANCEL click and we play the button one everywhere. | A call site in `game/duel/duel_screen.gd`'s cancel paths, plus a `sfx_cancel.wav` manifest row. Needs the duel screen, which was another agent's file on 2026-09-03. |
| **A forced discard is silent** | `sfx_discard` fires only on the confirmed hand-size discard. Hymn to Tourach and Mind Twist make no sound; the original plays `WAV_DISCARD` from `functions.c:14861` and `unlimited.c:2722` too. | An engine `CARD_DISCARDED` event, or a `MtgGame` hook the screen can hear. |
| **`sfx_lose` in an AI-vs-AI demo** | `_play_sfx("sfx_win" if _is_human(winner) else "sfx_lose")` — with no human seat every demo duel ends on the LOSE sting. | A third branch, or silence, in the duel screen. |
| **Five imported-or-namable cues with no event** | `Destroy` (which `deck.c:1158` records is the *exile* sound "despite its name"), `Kill`, `Regen`, `Sacrfice`, `ManaBurn`, `Control`, `ChangeC`/`ChangeT`, `FastFX`, and `Counter` (imported, "a counter was ADDED to a card") | Engine events we do not dispatch. `ManaBurn` is the closest — mana burn is already a rules fork. |
| **Which mastering is 1997's** | Three gain stagings of the duel sounds exist locally and none is dated 1997 (`Provenance.md`, "The audio"). The importer takes the folder the player's own game reads and prints the date. | Nothing local. A sealed CD would. |

## The Showcase's mana symbols (2026-09-04) — the braces become glyphs

From the owner's playtest:

> *"Enhance card text in the large card. The text has special symbols
> `{R}`, `{B}` etc. for mana and `{T}` for tap. Can we replace these in the
> text with actual mana and tapping symbols when rendering large beautiful
> cards? Can it be done?"*

**It can, and the 1997 game already did — its own card database is the
proof.** `../shandalar-xp/MagicTG/Master.csv` (Tier 1, 1997-08-14) stores
the rules text with the symbols pipe-escaped INSIDE the sentence
(`0230,Sol Ring,Artifact,Mark Tedin,|T: to add |2 to pool - Interrupt`),
and 204 of its 338 tagged rows carry `|T` — tap is never part of a mana
cost, so those can only have been drawn in the rules-text body. `Magic.exe`
imports `DrawManaText`/`CalcDrawManaText` from `DrawCardLib.dll` by name;
`Duel.hlp` sets tap and black-mana glyphs inline in its own quoted card
text. Full evidence and geometry: `docs/duel-screen-design.md`, "THE MANA
SYMBOLS IN THE RULES TEXT".

The rules box is now a `ManaText` (`game/duel/mana_text.gd`) built on a
`TextParagraph`, so the measurement and the render are the same object —
which is what let the whole fitting ladder survive. **The pool sweep did
not regress**: 688 of 897 cards read at the full ported size unexpanded
where the braces managed 685, 812 with `Expand` where they managed 810, the
same seven cards clip unexpanded (as the original clips), and not one card
loses a line with `Expand` on. Symbols are 3/4 of the line box in an 85%
advance cell (the 1997 DLL's own numbers), so they step down with the
ladder; a run of them is atomic, as it was in 1997; and with no imported
skin every token falls back to its literal braces, per token, so the game
is still complete with no 1997 files at all.

**Left undone, deliberately.** `MiniCard` and the Deck Builder's card list
show oracle text only as `tooltip_text`, and a Godot tooltip is a string —
symbols there need a custom tooltip Control, which is a separate piece of
work and was not worth bundling into this pass. The Deck Builder's Showcase
needed nothing: it IS a `CardPreview`.

## The AI targeting audit (2026-09-04) — whose permanent, and what state

Two lines from the owner's playtest, and both were the same routine:

> *"I noticed an opponent casting Psychic Venom on its own land. This
> should be looked into. If no other effect benefits you losing life,
> this is just plain wrong. I also observed it using Twiddle randomly —
> you should use it to your advantage."*

**The cause, in one function.** `AiPlayer._pick_for_spec` shops the
opponent's battlefield for a HARMFUL effect and our own for a HELPFUL one,
and `_is_harmful` decided which. For an aura it could not decide anything:
**an aura has no spell effects** — everything it does lives in a
StaticAbility's or a TriggeredAbility's Callable, which the reader cannot
look inside — so the function answered from a four-name list inlined in
itself (`"Weakness", "Paralyze", "Warp Artifact", "Wanderlust"`). The
pool holds **77 auras**. The other **73 counted as helpful and were aimed
at the AI's own board.** Psychic Venom on its own Island is one of them;
so were Cursed Land, Evil Presence, Erosion, Backfire, Feedback, Blight,
Brainwash, Curse Artifact, Artifact Possession, Takklemaggot, Spirit
Shackle, Power Leak, Creature Bond, Phantasmal Terrain, Venarian Gold,
Demonic Torment, Kudzu, Tangle Kelp, Imprison and Earthbind. **Relic Bind
was worse than mis-aimed: its own spec says "enchant artifact an opponent
controls", so the AI shopped its own side, found nothing legal, and never
cast the card in any game.**

The aim is now DATA, in one place — `EffectIntent.aura_aim` /
`AURA_HOSTILE` — with three structural signals first (a card that already
says it steals, reanimates or grants protection needs no row) and a
friendly default. `tests/ai/test_ai_targeting_2026_09_04.gd` walks the
whole registry, so an aura added tomorrow cannot slip in unclassified the
way those 73 did. Three rows are judgement calls and carry their reason in
the table: Creature Bond (a Fling we cannot plan, a Lava Axe we can),
Gaseous Form (blanking their best creature beats walling one of ours) and
Immolation (+2/-2 aimed at our own board can KILL what it enchants). The
named EXCEPTIONS — punishers that belong at home — are Unstable Mutation
(a +3/+3 loan the 1997 blue decks put on their own Merfolk), Living
Artifact and Cocoon.

**The tap policy.** `Twiddle` is the other half. A tap has no value of its
own: the same cast is a blow-out or a wasted card depending on WHOSE
permanent it hits and WHAT STATE that permanent is in. The AI already knew
this for repeatable ABILITIES (`_ability_option`'s tap arm and
`_best_tap_victim` — their best untapped creature, at their upkeep or
before our own attack, never at the mana sink because it untaps before it
matters) and knew none of it for a tap SPELL, which went through the
generic picker and aimed at the enemy's most valuable permanent, tapped or
not, land or not, at whatever moment the spell became affordable. Worse,
Twiddle's own mode hint is *"the mode that does something"* — so a Twiddle
aimed at their most valuable permanent while that permanent was TAPPED
**untapped it for them**.

Two readings are implemented, and only two:

1. **Their upkeep** (instants; `_fire_tap_instant`): tap their best
   untapped creature. It cannot attack this turn and, still tapped, cannot
   block on ours — the Icy Manipulator play, bought once with a card.
2. **Our precombat main with an attack ready** (`_size_tap`): tap the
   blocker in the way.

Both require a prize worth a whole card (`TAP_CARD_BAR`, a 2/2's board
value). `Word of Binding` ("tap X target creatures") rides the same policy
and now buys exactly as many targets as there are blockers worth tapping.

**Left out, on purpose:**

| Reading | Why not |
|---|---|
| Tap their LAND to deny mana | One land is not worth a card, and a land tapped on OUR turn untaps before their main phase and denies nothing at all. `_tap_denies_something` refuses lands outright. |
| Untap our own LAND as a mana burst | Twiddle costs {U} to untap one land: net zero mana and a card gone. It is only a ritual on a permanent that makes two or more (Sol Ring, Basalt Monolith, Mana Vault) — and that is a two-step plan (untap, then spend it on a specific card in hand) which a one-ply heuristic has no way to represent. Wants M4 phase 3, or a `_mana_spell_enables`-shaped reader for untap effects. |
| Untap our own attacker for a surprise block | Real — a creature that attacked stays tapped through the opponent's whole turn — but it needs a read of THEIR attack, which this AI only performs once blockers are being declared, by which time our window has passed. |
| An untap ABILITY as a mana sink (Ebony Horse, Instill Energy) | `_ability_option` still returns `{}` for `intent.untaps`. Same missing model as the row above; no card in the shipped decks loses by it. |

**A third form of the same disease, found by the sweep and deliberately
NOT fixed.** `_is_harmful` treats an unrecognised card-local effect as
removal-shaped, so the picker shops the OPPONENT's board for it. Three
cards target one of YOUR OWN permanents through a `with_source_filter`:
**Simulacrum**, **Energy Tap** and **Glyph of Destruction**. Nothing on
the enemy side is ever legal for them, so the picker returns null and the
AI has never cast any of the three, in any game. `EffectBase.helpful()`
exists for exactly this and **no card in the pool calls it** — but flipping
these three would make the AI worse, not better, because it has no model
for what they DO: it would aim Energy Tap and Simulacrum at its own most
valuable creature (tapping it out of combat, or shooting it), and Glyph of
Destruction's spec is only satisfiable mid-combat. They want an effect
reading first, then `.helpful()`, and they want it in that order.

**One limit worth naming.** An aura's static P/T change is invisible to
the reader (a `StaticAbility`'s Callable), so a hostile aura is aimed by
POLARITY alone, not by whether it kills. Weakness is right either way;
**Immolation** (+2/-2) is the card that pays for it — pointed at their
biggest creature it can make a 4/4 into a 6/2. That is still strictly
better than the alternative, which was pointing it at OUR OWN board where
+2/-2 kills a 2/2 outright. A `host_pt(p, t)` datum on the card, stated by
the card about itself, would let the AI aim these by result instead.

**Measured** (Deck Lab, `--gauntlet decks/ --games 200 --seed 1 --no-elo`,
wizard vs wizard, 1 000 games per deck against the five starter decks):

| Deck under test | Before | After | Swing |
|---|---|---|---|
| Thought Invoker (4 Psychic Venom, 3 Twiddle, 3 Icy Manipulator) | **4.5%** (45-955) | **32.3%** (323-677) | **+27.8** |
| Ethyl Merman (4 Psychic Venom, 4 Unstable Mutation) | **13.1%** (131-869) | **44.1%** (441-559) | **+31.0** |
| Elementalist (4 Twiddle, no auras) | **36.6%** (366-634) | **39.6%** (396-604) | **+3.0** |
| Big Green vs Black-Red Raiders (no aura, no tap spell) | **46.0%** (92-108) | **46.0%** (92-108) | **0.0** |

The last row is the null control and it is EXACTLY zero, which is what a
targeting fix should look like in a matchup that holds neither shape. The
size of the first two is not a tuning win: a Thought Invoker that
enchanted its own Islands with four Psychic Venoms was paying 2 life every
time it tapped for mana, all game, in a deck whose only other plan is to
sit behind counterspells. None of the five starter decks changed
behaviour — only one of them runs an aura at all (White Knights' three
Holy Strength, friendly before and after).

## The AI attack audit (2026-09-04) — how many blockers are there?

One line from the owner's playtest:

> *"Examine when the AI attacks — I have a notion it does not calculate
> when to attack (I have no defence) etc."*

**The policy it actually followed.** `AiPlayer._declare_attacks` (rewritten
in the 2026-09-02 sweep) asked, of each legal attacker, INDEPENDENTLY of
every other one:

1. is it legal to attack with (untapped, not sick, no Defender, attack
   cost payable)?
2. would everything get past their best blocks and win? — then send the
   whole board (the lethal push, counted THROUGH blocks);
3. otherwise: can ANY untapped enemy creature legally block it and come
   out ahead? The worst such answer is priced in Evaluator stat points —
   the attacker's whole value when the blocker kills it and lives, the
   size of the trade-down when both die — and the attack happens only if
   that number is at or below a tolerance of `(aggression - 0.5) * 6`,
   plus 1 when ahead on board;
4. one extra doubtful body if a Giant Growth is in hand with the mana up;
5. must-attackers conscripted, mistake injection drops one, Festival and
   the Caverns cap trim, bands grouped, then a four-rung declaration
   ladder ending in concede rather than a wedged step.

**What was wrong: step 3 has no reward term and no denominator.** Nothing
in it counted the DAMAGE an attack deals — a Grizzly Bears is worth four
stat points and the two damage it deals was worth nothing at all — and
nothing in it counted how many blockers the defender actually has. Four
2/2s facing one 3/3 each asked "does that Hill Giant beat you?", each
heard yes, and **all four stayed home** against a creature that can eat
exactly one of them and would have let six damage through. The measured
before-states, from `tests/ai/test_ai_attacks_2026_09_04.gd`:

| board (our side vs theirs) | old declaration | correct |
| --- | --- | --- |
| 4 Grizzly Bears vs 1 Hill Giant | **0 attackers** | 4 |
| 5 Grizzly Bears vs 1 Serra Angel | **0 attackers** | 5 |
| 3 Grizzly Bears vs 1 Hill Giant, them at 8 life | **0 attackers** | 3 |
| Craw Wurm + 3 Bears vs 1 Hill Giant | **1 attacker** | 4 |

The owner's own reading of the symptom was right, though the mechanism is
not quite "it ignores an empty board": an EMPTY board was always attacked
with everything, and so is one whose every creature is tapped. It takes
exactly ONE untapped body to switch the whole team off.

**The fix: the attack is chosen as a GROUP** (`_choose_attack_cohort`,
`_cohort_value`, `_face_damage_value`). The per-creature read stays as the
floor — it is sound, and the difficulty ladder is calibrated on it — and
the bodies it rejected are then offered back cheapest-risk-first, keeping
the longest prefix whose WHOLE-GROUP exchange pays. The group is priced by
simulating the defence the way a competent defender plays it: one blocker
per attacker, each block taken in descending order of what it gains them,
which is the same model `_damage_through_blocks` already used for the
lethal push. Face damage finally has a price — `_face_damage_value`, one
point of life per point ([constant Evaluator.W_LIFE]) scaled up by the
share of their REMAINING total the hit takes, so two damage is worth 2.2
against 20 life and 4.0 against 4. Adding only ever widens an attack, so
no attack this AI used to make was lost, and `_combat_tolerance` stays the
single difficulty knob: it is the slack a marginal extra body is allowed,
which keeps the Apprentice loose and the Wizard tight.

### Measured

Both seats share the code, so a symmetric before/after only shows which
DECKS the bug was taxing. The honest number is the asymmetric one: the new
policy piloting one seat against the old policy on the other, mirror
matchups, 1,000 games each — with a NULL run of the identical AI on both
seats at the same seed, because seat-and-seed bias in a mirror is worth
two to three points and swallows the effect whole if you forget it.

| deck (mirror) | new vs old | null (same AI both seats) | Δ |
| --- | --- | --- | --- |
| Big Green | 54.1% (541-459) | 51.6% (516-484) | **+2.5** |
| Blue Skies | 53.1% (531-469) | 53.1% (531-469) | **0.0** |
| White Knights | 50.2% (502-498) | 49.7% (497-503) | +0.5 |
| Mountain Artillery | 51.5% (515-485) | 51.4% (514-486) | +0.1 |
| Black-Red Raiders | 49.6% (496-504) | 49.5% (495-505) | +0.1 |
| **all five, 5,000 games** | **51.7%** | **51.1%** | **+0.6** |

Blue Skies is EXACTLY the null, game for game, and that is the row that
proves the harness: it is a mono-flier deck, its attackers are unblockable
by anything the opponent has on the ground, so every one of them was
already in the "nothing can block it" set and the cohort never has a body
to add. The change cannot fire there. Big Green — ground creatures, the
shape a single fat blocker walls off — is where the bug lived and where
the +2.5 comes from.

Symmetric before/after over the shipped gauntlet (full matrix, 200 games
x 10 matchups, seed 1) moved no matchup outside its confidence interval;
what it did move was the CLOCK. Games got shorter in eight of ten
matchups, and the Big Green mirror control went **20.5 -> 19.2 turns** at
49.5% -> 46.5% (a mirror, so the win rate is noise by construction).

### Tried, measured, and NOT kept

- **A heavier clock weight** (face damage scaled by 2x the life share
  rather than 1x): 50.3% against the shipped weight over 1,500 mirror
  games, against a 50.5% null. No lever at all — three of the five decks
  played byte-identical games. Kept at 1.0, the more conservative value.
- **A crack-back brake** — hold attackers home when the opponent's
  counter-swing would be lethal, since an attacker is tapped through
  their whole turn. It is a REAL gap (at 3 life behind one untapped 3/3,
  facing a tapped Craw Wurm, the AI swings the 3/3 and dies to the
  crack-back), and it measured 50.9% against a 50.5% null over 1,500
  games — inside the noise, and Mountain Artillery was 2.3 points WORSE
  with it. Left out: an unmeasurable gain that costs a matchup is a
  tuning liability, and the honest version of this needs the search
  (M4 phase 3), not another heuristic.

  **The honest version WAS built and measured that night** (next
  section): a one-ply lookahead running the same defence model over the
  opponent's whole board through the blockers the attack would leave. It
  closes the 3-life board exactly, and it measured +0.3 against the null
  over 5,000 games with Big Green 1.1 points WORSE. Left out again — and
  the conclusion sharpened: the gap is not the heuristic's fault, so the
  next attempt is the search itself.

### Known limits of the attack maths, deliberately left

- The defence model is one blocker per attacker. Gang blocks, and the
  defender's own combat tricks, are outside it — the same simplification
  `_damage_through_blocks` has always carried.
- Combat tricks are counted for exactly ONE extra attacker, and only for
  a single-effect non-self pump instant with a toughness bonus (Giant
  Growth). A power-only pump, and firebreathing on the attacker itself,
  do not enter the declaration — `_combat_self_pumps` fires later in the
  combat instead.
- The opponent's open mana and hand are not modelled at all, on purpose:
  the AI does not look at cards it may not see, so five untapped Islands
  invent no blockers. That is a floor on its play, not a bug.

All three were re-examined against instrumented games the same night and
two of them now carry a MEASURED reason to stay — see the next section,
"The defence-modelling gaps: which were worth closing".

## The AI block audit and dead-card sweep (2026-09-04)

The attack audit earlier the same day rewrote how the AI DECLARES an
attack and said in as many words that BLOCKING had never had a
comparable look. This is that look — plus the answer to the second thing
it left, three cards that had never been cast in any logged game.

### How the weaknesses were found

By instrumenting whole games, not by reading the ladder. 120 AI-vs-AI
games (all five starter decks, every pairing, Wizard on both seats) wrote
out every block decision with its board — the attackers, the free bodies,
the legality matrix, life on both sides — and the 1,022 records were
mined offline. That is what the attack audit's evidence looked like, and
it is what kept three plausible theories from being worked on at all:

| the reading | records | verdict |
| --- | --- | --- |
| combats faced / with a free body / declaring ZERO blocks | 1,022 / 571 / 271 | of the 271, **114 had no legal block at all** and 136 had only blocks that lose material |
| combats where the unblocked damage was LETHAL | 98 | |
| ...with an idle body that could legally have blocked one of those attackers | **0** | the headline fear — *the AI dies holding blockers* — does not happen |
| kill-and-live blocks that spent a costlier body than one that would do | **1** | the ladder takes the first body in each tier; over 120 games it cost one exchange. Left alone |
| gang blocks declared | 46 (4.5% of combats) | the frequency that decides two questions below |

Two things WERE wrong, and the log named both.

### What was wrong: the panic line was asked before the blocks, and the chump had no price

`desperate` was `life - <total power of every attacker> <= chump_threshold`,
counted with nothing blocked. A Wizard (threshold 6) at 7 life facing
three power called itself desperate. It fired in **192 of the 571**
combats the AI had a free body for. Once desperate, rung 4 threw the
cheapest legal body under the attacker whatever it was worth — and
"cheapest" is only cheap when there is a choice.

**49 of the 92 bodies the AI sacrificed over those 120 games died in a
combat it would have survived untouched**, 31 of them with four life or
more to spare. The worst single line in the log: a **Hypnotic Specter
(7.5 points) put under an Ironroot Treefolk at 7 life, to stop 3
damage**.

**The fix, in two halves, both built from numbers the AI already had.**
The block plan is run once with no desperation, and what gets THROUGH
that plan is what the panic line is asked about (`_damage_after_value_blocks`)
— so a swing the value blocks absorb is not a panic. And the chump rung
is priced: the life it buys goes through `_face_damage_value`, the attack
side's own clock read from OUR side of the table, and is compared against
`Evaluator.permanent_value` of the body being spent. A residue that would
actually finish us (`lethal_swing`) still buys anything at any price,
because the alternative is losing. `AiProfile.chump_threshold` keeps its
meaning and its direction — the larger number still panics earlier — so
the ladder is untouched.

### What was wrong on the attacking side of the same combat: no damage assignment order

`AiPlayer` overrode neither `DecisionAgent.order_blockers` nor
`assign_combat_damage`, so a gang block was divided in whatever order the
DEFENDER happened to declare it (CR 509.2 gives that order to the
attacker). 46 gang blocks in 120 games, **24 of them order-sensitive** —
the attacker's power short of every blocker's lethal put together, so the
order decides who dies. An Erg Raiders held by a Drudge Skeletons 1/1 and
a Hypnotic Specter 2/2 kills whichever of them it is pointed at first.

`order_blockers` is now the small knapsack it looks like: the set of
blockers whose lethal totals no more than the damage on offer and whose
worth is greatest goes first, and `MtgGame.default_damage_split`'s
lethal-first walk does the rest. Bodies nothing can be gained from — a
regenerator with its mana open, an indestructible one — are worth 0 here
and sort to the back. The budget is the whole BAND's power, not the lead
attacker's (CR 702.22j).

### The dead-card sweep: 72 cards the AI could not cast

Three cards had never been cast in a logged game — Simulacrum, Energy Tap,
Glyph of Destruction. Rather than answer for three names, the POOL was
swept: every one of the 851 non-land cards was put in hand on a
maximally favourable board (25 lands and a stocked zoo on both sides, our
own main phase, Wizard profile) and offered to the real `_try_cast_best`.
**Seventy-two came back uncast, and no board improved thirty-nine of
them.** They fall into six structural classes:

| # | class | cards | closed? |
| --- | --- | --- | --- |
| 1 | **Only castable in our own main phase.** `act` reaches `_try_cast_best` only there, and `_respond_action` has no general caster — it knows Fog by NAME, whatever `_find_instant_removal_for`/`_find_pump_instant` recognise, and `CounterEffect`s. Anything whose legality lives in another window is unreachable | 12 (Blaze of Glory, Camouflage, Disharmony, False Orders, Festival, Reset, Siren's Call, Teleport, Feint, the two other Glyphs, Glyph of Reincarnation) | **left** |
| 2 | **A `*/*` creature is worth 0 in hand.** `Evaluator.card_value` reads PRINTED power and toughness; a creature sized by a static ability prints 0/0, or scores NEGATIVE as a `0/*` Wall (Defender is -1.0). `_try_cast_best` keeps `value > best_value` from a floor of 0.0, so none of them could ever be the best card in hand | 12 (Clone, Keldon Warlord, Plague Rats, Shapeshifter, Vesuvan Doppelganger, Gaea's Liege, Dakkon Blackblade, Necropolis, Wood Elemental, Wall of Shadows/Tombstones/Vapor) | **CLOSED** |
| 3 | **A counterspell built from a card-local effect is not a counterspell.** `_try_counter` and `_is_reactive` tested `e is CounterEffect`; four of the pool's counterspells are `class X extends EffectBase` inside their own card file, so they were neither held for a spell to answer nor ever fired — dead cards in hand, in a third of the shipped deck pool | 8 (Power Sink 33 deck files, Mana Drain 29, Spell Blast 7, Force Spike 1; plus Fork, Reverberation, Rust, Darkpact, which are other shapes) | **CLOSED for the counterspells whose X can be sized** |
| 4 | **The planner picks a target the engine then rules illegal** — and pays for it first, so the cast leaks the mana every time | 3 (Fire and Brimstone's `player_filter`, Detonate's X-dependent target, Orcish Catapult's `at_random` spec) | **left** |
| 5 | **An unclassified effect is aimed at the wrong side of the table.** A card-local effect the reader has no model for is assumed removal-shaped, so the picker shops the OPPONENT's battlefield — and a card whose own spec says "you control" finds nothing there | 3 (Simulacrum, Energy Tap, Glyph of Destruction) | **CLOSED** (Glyph is also class 1) |
| 6 | **Pump instants nobody can fire.** `_find_pump_instant` demands a single non-self `PumpEffect` with `toughness > 0`, so a `+X/+0` or keyword-granting pump is invisible to every firer | 2 (Howl from Beyond 12 deck files, Jump 2) | **left** |

The other 33 of the 72 are correctly GATED, not silenced — sweepers below
`SWEEP_BAR`, held instants waiting for the opponent's end step, real
`CounterEffect` cards routed to `_try_counter`, Dark Ritual waiting for
something to enable — and each was confirmed firing once the board gave
it a reason.

**The three fixes, each general rather than card-named:**

* `_card_value` prices a creature whose value comes out at or below zero
  by its MANA VALUE instead. We do not know how big it will be; we know
  what it cost.
* `_pick_for_spec` treats the harm reading as the GUESS it is. When the
  intent is `unknown` and the spec carries its own source filter, and the
  guessed side yields nothing legal, the other side is scanned before
  giving up. A KNOWN harmful effect never reaches this, so a Terror is
  still never turned on our own board.
* `_is_counterspell` reads the CARD'S OWN ORACLE LINE, which does not care
  how the effect was built and separates "Counter target ..." from "Copy
  target ..." (Fork, Reverberation, which must never be fired as
  answers). It drives both `_is_reactive` (so a counterspell is held, not
  ranked against the creatures in hand) and `_try_counter`. `_cast_response`
  grew an X so Power Sink is paid for with a real one — at X = 0 it
  counters nothing at all.

### Measured

The instrument is the attack audit's: a candidate policy on ONE seat, the
shipped one on the other, mirror matchups, 1,000 games each, against a
NULL run of the identical AI at the same seed. The reported figure is
SEAT 0's win rate, because seat 0 is the seat the candidate is on; the
null absorbs the seat-and-seed bias, which in these mirrors is worth 1-3
points. Read in the attack audit's own convention (deck A's plain win
rate) this null reproduces that audit's null column to within a handful
of games, and Big Green lands on **516-484**, its number exactly — which
is the harness saying it is the same instrument. The four small
differences are the engine changes made between the two runs (combat.gd
was audited and fixed the same day), not drift in the measurement.

#### The block audit

| deck (mirror) | new vs shipped | null | Δ |
| --- | --- | --- | --- |
| Big Green | 48.9% (489-511) | 48.4% (484-516) | **+0.5** |
| Blue Skies | 49.6% (496-504) | 49.1% (491-509) | **+0.5** |
| White Knights | 48.1% (481-519) | 46.7% (467-533) | **+1.4** |
| Mountain Artillery | 48.4% (484-516) | 48.3% (483-517) | **+0.1** |
| Black-Red Raiders | 51.6% (516-484) | 51.3% (513-487) | **+0.3** |
| **all 5, 5,000 games each arm** | **49.3%** | **48.8%** | **+0.6** |

95% CI on the aggregate delta: +-2.0 points. Decks moving the right way: 5 of 5 (sign test p=0.031).

And the same change measured on BEHAVIOUR rather than on wins, over the
same 120 instrumented games with the candidate on seat 0 and the shipped
policy on seat 1 as an in-run control:

| | bodies sacrificed | Evaluator points spent | ...in a combat it would have survived |
| --- | --- | --- | --- |
| shipped policy (seat 1, the in-run control) | 42 -> 44 | 207.4 -> 219.4 | 23 -> 25 |
| the candidate (seat 0) | **50 -> 40** | **273.8 -> 225.3** | **26 -> 10** |

That is the number the change was made for, and the control seat says the
harness is not moving on its own.

And the damage assignment order, measured the same way:

| deck (mirror) | with the order | null | Δ |
| --- | --- | --- | --- |
| Big Green | 50.0% (500-500) | 48.4% (484-516) | **+1.6** |
| Blue Skies | 49.5% (495-505) | 49.1% (491-509) | **+0.4** |
| White Knights | 46.7% (467-533) | 46.7% (467-533) | **+0.0** |
| Mountain Artillery | 48.2% (482-518) | 48.3% (483-517) | **-0.1** |
| Black-Red Raiders | 51.5% (515-485) | 51.3% (513-487) | **+0.2** |
| **all 5, 5,000 games each arm** | **49.2%** | **48.8%** | **+0.4** |

95% CI on the aggregate delta: +-2.0 points. Decks moving the right way: 3 of 5 (sign test p=0.500).

**White Knights is BYTE-IDENTICAL to the null — 1,000 games, game for
game** — and the reason is exact rather than assumed. Counting gang
blocks and order changes over 60 mirror games per deck:

| mirror | combats | gang blocks | ...where the attacker's order differs |
| --- | --- | --- | --- |
| White Knights | 683 | 10 | **0** |
| Mountain Artillery | 397 | 3 | 1 |
| Big Green | 649 | 62 | 16 |

White Knights' knights are small enough that a gang block always kills
everything it can reach whatever order it is pointed in, so there is
nothing for the change to change and it lands on the null exactly. The
dose follows the response down the whole column: Big Green, whose fat
creatures are the shape that GETS gang-blocked, is +1.6; Mountain
Artillery, with one order change in 60 games, is -0.1.

The win-rate evidence here is not decisive on its own (±2.0 on the
aggregate). What decides it is that nothing is worse than -0.1, one row
is provably untouched, and this is not a tuning constant: CR 509.2 gives
the damage assignment order to the ATTACKING player, and `AiPlayer` was
handing it to the defender. The behavioural count is the real argument —
24 order-sensitive gang blocks per 120 games, previously divided by
whoever happened to declare the blocks.

#### The two together

Both block changes on one seat, since they are one combat:

| deck (mirror) | both changes | null | Δ |
| --- | --- | --- | --- |
| Big Green | 50.5% (505-495) | 48.4% (484-516) | **+2.1** |
| Blue Skies | 50.1% (501-499) | 49.1% (491-509) | **+1.0** |
| White Knights | 48.1% (481-519) | 46.7% (467-533) | **+1.4** |
| Mountain Artillery | 48.3% (483-517) | 48.3% (483-517) | **+0.0** |
| Black-Red Raiders | 51.8% (518-482) | 51.3% (513-487) | **+0.5** |
| **all 5, 5,000 games each arm** | **49.8%** | **48.8%** | **+1.0** |

95% CI on the aggregate delta: +-2.0 points. Decks moving the right way: 4 of 5 (sign test p=0.188).

+0.6 and +0.4 add up to +1.0, which is what two changes in different
halves of the same combat should do, and it is the configuration that
ships. Four decks up, the fifth exactly flat, none worse.

#### The dead-card sweep

Measured on five deck files that actually HOLD the silenced cards — the
five starter decks contain none of them, so a starter-deck gauntlet
cannot see this change at all:

| deck (mirror) | cards it holds | new vs shipped | null | Δ |
| --- | --- | --- | --- | --- |
| Thought Invoker | 4 Power Sink, 4 Vesuvan Doppelganger, 4 Spell Blast | 58.5% (585-415) | 52.5% (525-475) | **+6.0** |
| Shapeshifter | 4 Clone, 2 Vesuvan Doppelganger, 2 Shapeshifter, 3 Spell Blast | 71.7% (717-283) | 55.2% (552-448) | **+16.5** |
| Whim | 4 Power Sink, 4 Clone | 52.5% (525-475) | 50.9% (509-491) | **+1.6** |
| The Deck (Weissman, Feb '96) | 4 Mana Drain | 54.3% (543-457) | 49.7% (497-503) | **+4.6** |
| Fire and Ice | 3 Power Sink | 46.3% (463-537) | 47.7% (477-523) | **-1.4** |
| **all 5, 5,000 games each arm** | | **56.7%** | **51.2%** | **+5.5** |

95% CI on the aggregate delta: +-2.0 points. Decks moving the right way: 4 of 5 (sign test p=0.188).

**Shapeshifter is the shape of the whole finding.** Its eight
shapeshifting creatures were four Clones, two Vesuvan Doppelgangers and
two Shapeshifters, and over 30 mirror games the seat carrying the fix
cast them **40 times against the control seat's zero** — that deck had
been playing with 52 cards. The Deck's +4.6 is Mana Drain alone. Fire and
Ice is the one row that goes the other way (-1.4, inside its own ±3.1
interval): it is the deck whose newly-live Power Sink taps it out for the
biggest X it can afford, and if that row repeats, the max-X policy is the
first thing to look at.

**A latent bug this surfaced, in a file this pass may not edit.**
`cards/sets/leg/mana_drain.gd:47` schedules its delayed payout with a
lambda that CAPTURES `game`, and the game holds the lambda in
`_next_main_actions` — a reference cycle. It is broken when the payout
fires, so it was invisible while nothing ever cast the card; now that the
AI does, a duel that ENDS with an unpaid Mana Drain pending leaks the
whole `MtgGame`. It is what turned `tests/ai/test_ai_dead_cards_2026_09_04.gd`
red on its first run ("115 ObjectDB instances were leaked at exit"), and
the test now runs the payout out rather than hiding it. The one-line fix
is a weak reference:

```gdscript
var weak := weakref(game)
game.schedule_next_main_phase_action(controller, func() -> void:
    var g := weak.get_ref() as MtgGame
    if g == null:
        return
    g.players[controller].mana_pool.add(Mtg.ManaColor.C, value)
    g.log_line("Mana Drain pays out %d colorless" % value))
```


### Tried, measured, and NOT kept

* **A crack-back LOOKAHEAD.** The attack audit found this gap, tried a
  heuristic for it, measured 50.9% against a 50.5% null and left it out,
  saying the honest version needs a real look at the opponent's next
  attack step. This is that version, and it is not a third heuristic: it
  runs `_damage_through_blocks` — the same defence model that prices our
  own attack — with the ROLES SWAPPED, their whole board (tapped bodies
  included, since they untap first) against the blockers this attack
  would leave us, and drops attackers one at a time, each time the one
  whose staying home buys the most life, until the counter-swing is
  survivable. It closes the audit's own reproduced board exactly
  (at 3 life with a Hill Giant against a TAPPED Craw Wurm it now declares
  no attackers; at 20 life on the same board it still swings; when the
  counter-swing is lethal whatever we do it still swings; a lethal push
  is never held back) and it still does not measure:

  | deck (mirror) | lookahead | null | Δ |
  | --- | --- | --- | --- |
  | Big Green | 47.3% (473-527) | 48.4% (484-516) | **-1.1** |
  | Blue Skies | 50.0% (500-500) | 49.1% (491-509) | **+0.9** |
  | White Knights | 47.8% (478-522) | 46.7% (467-533) | **+1.1** |
  | Mountain Artillery | 47.9% (479-521) | 48.3% (483-517) | **-0.4** |
  | Black-Red Raiders | 52.2% (522-478) | 51.3% (513-487) | **+0.9** |
  | **all 5, 5,000 games each arm** | **49.0%** | **48.8%** | **+0.3** |

  95% CI on the aggregate delta: +-2.0 points. Decks moving the right way: 3 of 5 (sign test p=0.500).

  Three of five decks the right way is a coin, and **Big Green is 1.1
  points worse** — the same shape as the heuristic version the attack
  audit rejected, which cost Mountain Artillery 2.3. LEFT OUT, for the
  audit's own reason: an unmeasurable gain that costs a matchup is a
  tuning liability. What this run adds to what the audit knew is that the
  gap is not the heuristic's fault. A correct one-ply lookahead does not
  pay either, so the next attempt should be the real search (M4 phase 3)
  rather than a better approximation of one turn.

### The defence-modelling gaps: which were worth closing

The attack audit listed three limits of the combat maths and called them
deliberate. Each was re-examined against the 1,022 logged block records
rather than against intuition:

* **One blocker per attacker (no gang blocks) in `_damage_through_blocks`
  and `_cohort_value`.** LEFT, and now with a number: the defender
  gang-blocked in **46 of 1,022 combats, 4.5%**. Teaching the attack maths
  to fear a double block would make it pessimistic about something that
  happens once every twenty-two combats — and the fault the attack audit
  had just fixed was the AI being too pessimistic, not too little. The
  same model is used on both sides of the table, so it stays consistent.
* **The defender's own combat tricks.** LEFT: it is the same rule as "the
  opponent's hand is not modelled", and modelling a card we may not see
  is exactly the cheat this AI does not take.
* **Combat tricks count for one extra attacker, and only for a
  single-effect non-self pump instant with a toughness bonus.** LEFT, and
  the sweep says WHY it is worth closing later rather than now: the same
  `toughness > 0` test in `_find_pump_instant` is why Howl from Beyond
  (12 deck files) and Jump (2) have never been fired, and Howl is `{X}{B}`
  — so closing it needs the same missing capability as class 3's Spell
  Blast and class 4's Detonate: **size an X at instant speed and validate
  the target against it before paying**. `TargetSpec.is_legal` has no X
  parameter and the X is read off `source.memory["x_value"]`, which only
  `MtgGame.cast_spell` stamps. Three of the six dead-card classes and one
  of the defence gaps are the same missing piece; it is worth one change,
  not four.
* **`assign_combat_damage` had no override either** — the brief's fourth
  item. It does not need one now: with `order_blockers` in place,
  `MtgGame.default_damage_split`'s lethal-first walk down THAT order is
  the best division available, trample spill included. What is left is a
  blocker dividing its damage among several attackers (needs
  `cur_extra_blocks` — Two-Headed Giant of Foriys, Blaze of Glory) and the
  defensive-banding `free_order` case, where the default already picks the
  defender's own cheapest body. Both are rare enough that no measurement
  could resolve them.

### Still open, and why

* **Class 1, "only castable in our own main phase" (12 cards).**
  `_respond_action` needs a GENERAL "cast the best legal spell in this
  window" arm — it currently knows Fog by name and three effect shapes.
  That is a new AI capability with its own risk surface (an instant cast
  in the wrong window is worse than one never cast), and it wants its own
  audit rather than a rider on this one.
* **Class 4, "the planner picks a target the engine then rules illegal"
  (3 cards).** A real bug, not just silence: the lands are tapped BEFORE
  the refusal, so every attempt leaks the mana. The fix is to validate the
  assembled plan — `spec.is_legal` with the FINAL x, the `player_filter`,
  the `at_random` arity — before `_plan_and_pay`. It shares the X problem
  above. **CLOSED 2026-09-05** — see "The X a spell is being cast for, and
  the mana the planner leaked".
* **Class 6, "pump instants nobody can fire" (2 cards).** Same X problem
  (Howl from Beyond is `{X}{B}`), and `_find_pump_instant` serves three
  callers with three different needs; splitting it is a change worth
  measuring on its own. **HALF CLOSED 2026-09-05**: Howl from Beyond is
  fired as a lethal-only finisher through a separate finder
  (`_find_x_power_pump`, +3.3 over 2,000 games); Jump and the
  `_find_pump_instant` split are still open — same section.
* **Spell Blast** (7 deck files) is recognised as a counterspell and
  correctly declines to fire, because its target's legality reads the X
  off the casting card and nothing in the AI can try an X on without
  stamping the instance. **CLOSED 2026-09-05** by `MtgGame.casting_x`,
  which answers for a PROPOSED X — same section.

### What shipped, and what it is worth

| change | measured | verdict |
| --- | --- | --- |
| the panic line asked AFTER the blocks, and the chump rung priced | +0.6 over 5,000 games, **5 of 5 decks the right way** (p=0.031), no deck worse; needless sacrifices on the changed seat 26 -> 10 against a control seat's 23 -> 25 | **kept** |
| `order_blockers` (CR 509.2) | +0.4 over 5,000, worst deck -0.1, one deck byte-identical because the change cannot fire there, and the response tracks the dose | **kept** — a rule the AI was not playing, at no measured cost |
| the dead-card fixes | **+5.5 over 5,000 games**, four of five decks, outside the ±2.0 interval; the Shapeshifter deck alone **+16.5** | **kept** |
| the crack-back lookahead | +0.3 over 5,000, 3 of 5 decks, **Big Green -1.1** | **left out**, for the attack audit's own reason |

## The X a spell is being cast for, and the mana the planner leaked (2026-09-05)

The dead-card sweep of the day before left three of its six classes on
one missing piece, and said so in as many words: **size an X at instant
speed and validate the target against it before paying.**
`TargetSpec.is_legal` had no X parameter, and the X a targeting
restriction reads was stamped exactly one way — `MtgGame.cast_spell`
writing `memory["x_value"]` on its way past. Nobody could ask the
question before announcing the spell, so class 3's Spell Blast, class 4's
three cards and class 6's Howl from Beyond were all stuck behind the same
door. This is that one change.

### Class 4 was a live bug, and here is the leak

`AiPlayer` taps its lands and THEN calls `cast_spell`. Every legality the
planner does not mirror is therefore paid for before it is discovered,
and the floating mana empties at the next step boundary (CR 500.4) with
the card still in hand. Reproduced first, on a Wizard seat with twenty
untapped lands:

| card | why the engine refused | untapped lands, before -> after |
| --- | --- | --- |
| Fire and Brimstone | `Illegal target (type)` — "target player who attacked this turn" is a `TargetSpec.player_filter` and the picker handed the opponent over without asking it | 20 -> 15 |
| Detonate | `Illegal target (type)` — the filter reads the caster's X, which in hand was 0, so the picker found the one artifact that cost nothing, sized X to every land it had, and offered the engine a target its own X had just made illegal | 20 -> 0 |
| Orcish Catapult | `takes 0 target(s), got 1` — its targets are ROLLED by the game (CR 601.2c), so the caster supplies none; the planner supplied one anyway | 20 -> 0 |

`tests/ai/test_ai_x_seam_2026_09_05.gd` states it end to end as well: the
seat starts main phase 1 with twenty lands and a Fire and Brimstone next
to a Grizzly Bears, and by main phase 2 it has spent seven of them and
cast a two-drop.

### The seam

Two halves, both read-only, both in `MtgGame`:

* **`casting_x(inst)` is the one reader.** It answers "what X is this card
  being cast for?" with the value a planner has PROPOSED while trying an X
  on, and with the value `cast_spell` stamped otherwise. Detonate and
  Spell Blast — the two cards in the pool whose targeting restriction
  names its own X — now ask it instead of reading `memory` directly, so
  the same filter gives the same answer at plan time, at announcement and
  at resolution. `target_legal_at` / `legal_targets_at` are the
  prospective twins of `TargetSpec.is_legal` / `.legal_targets` that scope
  the proposal: pushed and popped around one query, never observable
  outside it, so there is no undo record to keep and nothing to leave
  stale.
* **`cast_refusal(pid, inst, targets, x, mode)` is `cast_spell`'s
  validation half run as a DRY RUN.** Not a second copy of the rules —
  the same `_cast_checks` the real cast runs, so the two cannot drift:
  zone, priority and timing, the mode, the damage window, the whole target
  plan at THIS X (legality, the no-duplicate rule, the divided
  arithmetic, the arity a rolled or opponent-chosen slot demands) and the
  additional sacrifice cost. Nothing paid, nothing moved, no roll
  consumed, no question asked. `""` means only the mana is left to find.

Why that shape rather than an X parameter threaded through
`TargetSpec.is_legal`: the X is a property of the SOURCE, not of the spec.
A spec's filter already takes the source (`with_source_filter(game,
source, inst)`), and eleven other cards use that signature for things
that have nothing to do with X. Adding an X argument to the legality chain
would have changed all of them to carry a value only two of them can use.
The defect was never that `is_legal` lacked a parameter — it was that the
announcement was the only thing allowed to say what X was, and an
announcement can perfectly well be hypothetical.

Extracting `_cast_checks` also fixed a small rules wart on the way: the X
used to be stamped BEFORE the targets were validated, so a refused
announcement left `memory["x_value"]` behind. It is now stamped below the
checks, and a refused cast leaves everything as it was (CR 601.2h).

### What the planner does with it

`_try_cast_best` and `_cast_response` — between them every cast this file
makes — end with `cast_refusal` before a single land is tapped. The
picker learned the three legalities it was missing: a PLAYER slot is
legality-checked instead of handed over, a slot the GAME rolls or the
OPPONENT names is left empty because it is not ours to fill, and every
legality question is asked at the X being considered.

And the X is now SIZED to the target rather than to the mana:
`_targets_depend_on_x` spots a card whose targeting moves with its X, and
`_size_and_aim` tries each affordable X on, cheapest first, keeping the
best aim. `_x_that_makes_legal` is the same search for one known target,
and it is what fires Spell Blast for exactly the mana value on the stack.

### Measured: the leak itself, across the whole deck pool

258 shipped deck files, six mirror games each, Wizard on both seats,
every `(AI cast of X refused: ...)` line in the log counted and bucketed
by REASON:

| refusal | shipped | with the seam |
| --- | --- | --- |
| `Illegal target (…)` — the whole class-4 bucket | **127** | **0** |
| `… can only be cast in your main phase with an empty stack` | 1,143 | 1,142 |
| a block-declaration error (pre-existing, unrelated) | 1 | 1 |
| **total refused casts / 1,026 games** | **1,271** | **1,143** |

The class-4 bucket is gone, exactly and entirely. A wider run — 6,840
games over the same pool — puts Detonate alone at 971 of 8,457 refused
casts, the single biggest contributor in the pool.

### Measured: the win rate, asymmetrically, against a null

The instrument is the block audit's: the candidate policy on ONE seat, the
shipped one on the other, mirror matchups, 1,000 games each, against a
NULL run of the identical shipped AI at the same seed. The reported figure
is SEAT 0's win rate, because seat 0 is the seat the candidate is on; the
null absorbs the seat-and-seed bias. Measured on decks that actually HOLD
the affected cards — the five starter decks hold none of them, which is
what makes one of them the control row.

| deck (mirror) | cards it holds | new vs shipped | null | Δ |
| --- | --- | --- | --- | --- |
| Thought Invoker | 4 Spell Blast | 52.7% (527-473) | 52.2% (522-478) | **+0.5** |
| Coral Reef | 2 Spell Blast | 49.1% (491-509) | 48.3% (483-517) | **+0.8** |
| War Mage | 3 Detonate | 47.6% (476-524) | 46.8% (468-532) | **+0.8** |
| Crag Hydra | 1 Detonate | 43.6% (436-564) | 43.9% (439-561) | **-0.3** |
| Big Green (control) | **none** | 49.3% (493-507) | 49.3% (493-507) | **+0.0** |
| **all 5, 5,000 games each arm** | | **48.5%** | **48.1%** | **+0.4** |

95% CI on the aggregate delta: ±2.0 points. Of the four rows that CAN
move, 3 of 4 move the right way, and the worst is -0.3.

**Big Green is BYTE-IDENTICAL to the null — 1,000 games, game for game,
the same `results.json`.** It is the control row and it was chosen to be
one: it holds no Spell Blast, no Detonate, no Orcish Catapult, no Fire and
Brimstone, and nothing in it ever draws a refusal from the engine, so
there is nothing for this change to change. A row that provably cannot
move landing exactly on the null is the harness saying it works.

The win-rate evidence is not decisive on its own (±2.0 on a +0.4). What
decides it is the behavioural table above — 127 illegal-target refusals
across 258 decks becoming 0 — and the fact that this is a BUG, not a
tuning constant: the planner was buying the engine's answer with its
lands.

### AND THE HUMAN HAD THE SAME HOLE, on the other side of the screen (2026-09-06)

This whole pass was the PLANNER's. The human's X window was never in its
scope, and it turned out to be shut in a simpler and worse way: **no {X}
spell and no {X} ability in the pool could be cast by hand at all.**

`DuelScreen._open_x_dialog` sized `@DIALOG_FIREBALL`'s `(max: %d)` off
`players[pid].mana_pool` — the FLOATING pool. But payment comes after the
choice in this game as it did in 1997 (*"Once you've selected a spell to
cast, you must draw enough mana… to power the spell"*, `Duel.hlp`, topic
**Hands**), so at the moment that window opens the pool is empty and the
lands are still untapped. The bound was therefore 0, the SpinBox was
0..0 with nothing to select, and the window is modal (`_modal_open`) so
the lands could not be tapped either. OK paid X = 0. The owner's playtest
put it in one sentence: *"Disintegrate makes a dialog and asks for generic
mana to put into the spell. However it does not let me tap the lands to
put into the spell, or select any mana at the dialog!"*

**The right number was already in the file, under another name.** The
double-click auto-cast answers the same question — *"ALL of the mana you
have available in your pool AND FROM LAND SOURCES will be put into that
spell"* (`Duel.hlp`, **Hands**, repeated under **Spells**) — and
`_auto_x_budget`'s own doc comment described itself as *"`_open_x_dialog`'s
own budget loop, asked of potential mana instead of the floating pool"*.
Two answers to one question, and the window had the wrong one. They are
now one function, `DuelScreen._x_budget`, planning the whole cost at each
candidate X over `ManaPlanner.sources` so the coloured pips and X compete
for the same lands (six Mountains pay Disintegrate's `{R}` from one and
leave five for X). The single difference is the exclusion set: the
gesture leaves a locked land alone, the window counts it, because
`_pending_is_reachable` already reasons that way — *"the only way to tap a
locked land is manually, by clicking on it"* (`Duel.hlp`, **Territory**).

**Swept as a class, not as a card.** 24 spells with `{X}` in the cast cost
(Alabaster Potion, Braingeyser, Detonate, Disintegrate, Drain Life,
Earthquake, Fireball, Frankenstein's Monster, Guardian Angel, Howl from
Beyond, Hurricane, Mind Twist, Orcish Catapult, Part Water, Power Sink,
Recall, Rock Hydra, Spell Blast, Stream of Life, Venarian Gold, Volcanic
Eruption, Whimsy, Winter Blast, Word of Binding) and 10 activated
abilities with `{X}` in theirs (Aladdin's Lamp, Banshee, Candelabra of
Tawnos, Clockwork Avian, Clockwork Beast, Goblin Polka Band, Illusionary
Mask, Nebuchadnezzar, Reflecting Mirror, Voodoo Doll). Every one of the
34 is now dealt to a seat with twenty lands and clicked by
`tests/ui/test_x_dialog.gd`, which asserts each offers the bound its own
board can pay. The OTHER way a human is asked for mana mid-resolution —
*"unless that player pays {X}"* / *"you may pay {X}"* (In the Eye of
Chaos, Invoke Prejudice, Power Sink, Primordial Ooze, Transmute Artifact)
— was never affected: it is a `PlayerChoice.YES_NO` whose hint is
`MtgGame.can_afford_cost`, and `try_pay` auto-taps lands on a yes.

**Why the suite did not catch it.** Every X test in the file staged its
mana by writing into `mana_pool` directly. Not one of them put a land on
the battlefield, which is the only way a player ever arrives at that
window. The four new end-to-end tests all start from untapped lands.

### Class 6, measured on its own: the +X/+0 finisher

`_find_pump_instant` is why Howl from Beyond (12 deck files) and Jump (2)
had never been fired: it demands a single non-self `PumpEffect` with
`toughness > 0`, and it serves three callers who all read a FIXED
`power`/`toughness` straight off the effect. Splitting it is still a
change of its own. What landed instead is a separate finder,
`_find_x_power_pump`, with exactly one caller — the lethal push in
`_offensive_combat_response` — and one policy: a pump with no toughness
buys no block and no board, so it is offered ONLY when the swing wins the
game, and X is the shortfall exactly rather than the maximum the mana
allows. Jump is untouched: a keyword-granting pump needs combat maths that
can read a granted keyword, which is the same split.

| deck (mirror) | cards it holds | with the finisher | null | Δ |
| --- | --- | --- | --- | --- |
| Warlock | 4 Howl from Beyond | 53.4% (534-466) | 50.2% (502-498) | **+3.2** |
| Undead Knight | 4 Howl from Beyond | 52.5% (525-475) | 49.1% (491-509) | **+3.4** |
| **both, 2,000 games each arm** | | **52.9%** | **49.6%** | **+3.3** |

95% CI on the aggregate delta: ±3.1 points. 2 of 2 decks, and the
aggregate clears its own interval — which is what a card going from never
cast to cast for the kill should look like.

### Tried, measured, and NOT kept

* **Firing Orcish Catapult.** Skipping the rolled slot makes the card
  legal to cast, so the leak closes either way — but the AI cannot AIM it,
  and the abstention is measured rather than assumed: 400 Catapults for
  X=4 rolled over symmetric three-creature boards put **794 of their 1,600
  counters on our OWN creatures (49.6%)**, and 35% of the volleys hurt us
  more than they hurt the opponent. A one-ply heuristic has no way to
  price a coin flip, and no shipped deck holds the card, so it stays in
  hand. If a search ever lands (M4 phase 3) it can roll the dice itself.
* **The Apprentice was left out of the counterspell half by construction,
  not by a new knob.** Spell Blast reaches the table through
  `_try_counter`, which lives behind `AiProfile.holds_instants` — and so
  does the finisher, which is inside `_respond_action`. The leak fix
  applies to every profile on purpose: a refused action is not a DECISION,
  and the bottom difficulty's honest weakness is `mistake_chance`, not an
  engine that bounces what it chose.

### What this cost, and what it did not fix

`cast_refusal` runs once per ranked candidate, so the planner does more
work: the candidate arm ran 195s per 1,000 games against the null's 184s,
about **6% slower**, which is the price of asking before paying.

And the bigger residue this pass NAMED but did not close — **CLOSED 2026-09-05**, see "The tap-trigger refusal, and the crack-back search" below:
1,271 refused casts in that 1,026-game census are
`… can only be cast in your main phase with an empty stack`**, and they
have nothing to do with targets. The planner taps its lands, a
TAP-TRIGGERED ability goes on the stack in the middle of it — Manabarbs,
Psychic Venom, Blight — and the sorcery it was paying for is refused
because the stack is no longer empty. `cast_refusal` cannot see it: the
stack IS empty when it is asked. The mana is not lost outright (the pool
survives the step, so a later cast can spend it) but the card is memoed as
refused and does not reach the table that turn. The fix is a different
mechanism — a refusal the planner can WAIT OUT should not enter the
refusal memo — and it wants its own measurement.

### Still open after this pass

* **Class 1, "only castable in our own main phase" (12 cards).** Unchanged
  and untouched: `_respond_action` still needs a general "cast the best
  legal spell in this window" arm. This pass makes it CHEAPER — the window
  caster can now ask `cast_refusal` instead of mirroring the timing rules
  — but the ranking, and the risk of an instant cast in the wrong window,
  is still its own audit. Fire and Brimstone in particular is only ever
  legal during the opponent's turn after they have attacked, so it is a
  class-1 card as well as a class-4 one: this pass stopped it leaking, and
  it will stay uncast until class 1 lands.
* **Jump, and the `_find_pump_instant` split** (see class 6 above).
* ~~**The tap-trigger refusal**, above.~~ **CLOSED 2026-09-05** — the
  refusal memo now tells a refusal that stands from one the planner can
  wait out; 1,199 refused casts over 1,296 games became 0.


## The tap-trigger refusal, and the crack-back search (2026-09-05)

Two items, both NAMED and left open by the passes of the day before, and
they are opposite in shape. The first is 1,143 of 1,271 refused casts and
the fix is one comparison; the second is one board in one playtest, and
it had already been attempted twice and rejected twice.

### Item 1 — a refusal the planner can WAIT OUT is not a refusal

**The mechanism, restated from the census that found it.** `AiPlayer`
taps its lands and THEN announces the spell they pay for. So a
TAP-TRIGGERED ability goes on the stack in the middle of paying, and
CR 601.2a's sorcery timing then refuses the spell it was being paid for
— the stack is no longer empty. `cast_refusal`, the dry run the X-seam
pass added the day before, cannot see this coming: the stack genuinely IS
empty when it is asked.

The card then went into the REFUSAL MEMO, which is keyed by step, so it
was skipped for the rest of the main phase. Reproduced exactly, on four
Mountains with a Hill Giant in hand and a Manabarbs across the table:

```
Trigger: Manabarbs — ... deals 1 damage to that player.   (x4)
(AI cast of Hill Giant refused: Hill Giant can only be cast in your
 main phase with an empty stack)
Manabarbs deals 1 damage to P0 (life 19) ... (life 16)
P0 declares no attackers
```

Four life paid, four Mountains spent, the pool emptied at the step
boundary and the Giant still in hand. The seat then passed with four red
mana floating and a castable creature it had already decided to cast.

**The fix is one distinction, and it is structural rather than a string
match.** `_wait_out` asks whether the STACK FILLED UP WHILE WE WERE
PAYING. It can only have been our own taps: `act()` reaches the
main-phase planner only with an empty stack, and `cast_refusal` cleared
this exact cast a few lines earlier. Everything that follows is then
already true — the mana stays in the pool until the step ends
(CR 500.4), the trigger resolves one priority round later, and
`ManaPlanner.sources` sorts the floating pool FIRST, so the retry pays
from the pool without tapping a second land and the trigger is not
charged twice. With an empty stack `_wait_out` returns false and the memo
takes the refusal exactly as before, which is what still stops the
planner tapping twice for a cast that really is refused. The same board
now reads:

```
(AI holds Hill Giant: the stack filled up while it was paying)
Manabarbs deals 1 damage to P0 (life 19) ... (life 16)
P0 casts Hill Giant
```

#### Measured: the census, before and after

The X-seam pass's instrument, rebuilt: every playable shipped deck file
(**216 of 317** — the rest hold proxies or fail a strict load), six
mirror games each, Wizard on both seats, **1,296 games**, every
`(AI ... refused: ...)` line counted and bucketed by REASON. (It is a
slightly wider run than the census that NAMED this — 1,296 games against
1,026 — so the shipped column reads 1,199 where that one read 1,143. Same
rate, same single cause.)

| | shipped | with the wait-out |
| --- | --- | --- |
| `… can only be cast in your main phase with an empty stack` | **1,199** | **0** |
| a cast HELD for one priority round and then made | — | 811 |
| every other refusal | 0 | 0 |
| spells that reached the stack | 37,665 (29.06/game) | **38,087 (29.39/game)** |
| seconds for the 1,296 games | 428.0 | 426.0 |

The bucket is gone entirely, 422 more spells reach the table, and it
costs nothing measurable — there is no extra work, only one fewer entry
in a Dictionary.

**The biggest contributor is not one of the three cards the census's own
note named.** Manabarbs, Psychic Venom and Blight are all in the class,
but the deck files that lose most to it run **City of Brass**
(*"Whenever City of Brass becomes tapped, it deals 1 damage to you"* —
four copies in The Deck (Weissman), in Arzakon, in Whim) and **Kudzu**,
whose *"when enchanted land becomes tapped"* is the same shape on our own
land. The fix names no card, which is why they were all in it already.

#### Measured: the win rate, asymmetrically, against a null

The block audit's instrument: the candidate on ONE seat, the shipped
policy on the other, mirror matchups, 1,000 games each, against a NULL
run of the identical shipped AI at the same seed. The figure is SEAT 0's
win rate, because seat 0 is the seat the candidate is on.

| deck (mirror) | what it holds | wait-out | null | Δ |
| --- | --- | --- | --- | --- |
| Sorcerer | 4 City of Brass | 70.1% (701-299) | 51.5% (515-485) | **+18.6** |
| Whim | 4 City of Brass, 4 Psychic Venom | 68.0% (680-320) | 51.1% (511-489) | **+16.9** |
| Arzakon | 4 City of Brass | 63.0% (630-370) | 52.4% (524-476) | **+10.6** |
| Fungus Master | 2 Kudzu | 60.1% (601-399) | 51.3% (513-487) | **+8.8** |
| Big Green (control) | **nothing** | 49.3% (493-507) | 49.3% (493-507) | **+0.0** |
| **all 5, 5,000 games each arm** | | **62.1%** | **51.1%** | **+11.0** |

95% CI on the aggregate delta: ±2.0 points. Every row that CAN move moves
the right way, and the smallest of them is four times the interval.

**Big Green is the control row and it lands on the null exactly: 493-507
in both arms, with a BYTE-IDENTICAL `matchups.csv` — 1,000 games, game
for game.** It holds no tap-triggered permanent, so the change cannot
fire in it, and the null figure is also the X-seam pass's own Big Green
null to the game. That is the harness saying it is the same instrument.

Two further notes on the size. Fungus Master's +8.8 comes from **two**
Kudzu, which is how cheap this bug was to hit: any permanent that
triggers on a tap taxes every sorcery-speed cast the deck makes for the
rest of the turn. And the fix applies to every profile on purpose — a
refused action is not a DECISION, so this is not a difficulty knob.

### Item 2 — the crack-back, third attempt: a real search

**What was standing.** At 3 life behind one untapped 3/3, facing a TAPPED
Craw Wurm, the AI swings the 3/3 and dies to the counter-swing: an
attacker is tapped through the opponent's whole turn. Two answers were
built and both were rejected ON MEASUREMENT — a heuristic brake (50.9%
against a 50.5% null over 1,500 games, Mountain Artillery **2.3 points
worse**), and a one-ply lookahead running `_damage_through_blocks` with
the roles swapped (+0.3 over 5,000 games, Big Green **1.1 points
worse**). The standing conclusion was that the gap is not the
approximation's fault, so the next attempt is search.

**Both failed the same way, and naming it is what shaped this attempt:
they are PESSIMISTIC.** They assume the opponent swings with everything;
they assume we block it greedily; and they test the result against a
threshold ("is the counter-swing lethal?") rather than pricing it against
what the attack was worth. Every one of those errs in the same direction
— hold the body home — which is why the deck that wants to attack is the
deck that pays.

#### What the undo journal could carry, and what it could not

The obvious shape was the one the phase-3 note points at: make the moves
in the ENGINE and unmake them through `engine/undo_log.gd`, which is 21x
a `GameSnapshot` and exists for exactly this. **It does not reach, and
the journal's own doc says why**: its documented boundary is the TURN
MACHINERY — *"a search must not cross a step boundary until they do"* —
and a crack-back search crosses two step boundaries and a turn boundary
by construction (our combat damage, their untap step, their combat).
Instrumenting `_advance_step` / `_enter_step` is the next increment and
a real one; it is not a rider on this.

What the search does NOT need is a second rules model. `CombatSearch`
runs over a flat MODEL built once per decision out of the engine's own
predicates — `CombatState.block_illegality` for every legality,
`AiPlayer._dies_to` for every kill, both precomputed into matrices — so
the tree indexes arrays instead of re-asking the engine, and no rule is
written twice. The one predicate decomposed rather than called is
`attack_illegality`, whose TAPPED and SUMMONING-SICK arms are false by
the time the crack-back happens; only its durable half is asked, and
over-including there is the safe direction for a defensive read.

#### The search

Four decision layers, three of them enumerated and backed up through an
alpha-beta minimax:

1. **OUR attack (max)** — every subset of the declaration the cohort and
   the pump rider have already made: the powerset while the optional
   bodies are five or fewer, the best-defender-first chain above that.
   The search can therefore only ever hold a body BACK, never send one
   the 2026-09-04 attack audit's maths rejected, so that audit's +2.5 on
   Big Green cannot be undone by this one.
2. **THEIR blocks (min)** — NOT searched, deliberately: the shipped
   one-blocker-per-attacker greedy model, the same one `_cohort_value`
   and `_damage_through_blocks` use. The job here is the crack-back, and
   a search that re-litigated the FORWARD combat with a second model
   would be two changes measured as one.
3. **THEIR crack-back attack (max, theirs)** — over their survivors, all
   of them, because they untap first, which is the whole premise.
   **Declining is on their list and is worth exactly nothing**, so it is
   the starting alpha-beta bound rather than a move: a swing that costs
   them more than it gains is one they simply do not make. That line is
   the first of the two pessimisms gone.
4. **OUR blocks (min, theirs)** — a recursive assignment over the bodies
   this attack would leave us: our untapped creatures that stayed home,
   plus the vigilant ones that did not. Searched, not assumed. That is
   the second pessimism gone.

The leaf is the position DELTA in `AiPlayer`'s own currency —
`_face_damage_value`'s clock-scaled face damage plus
`Evaluator.permanent_value` for every body that dies on either side — so
what the search backs up is comparable with what `_cohort_value`
produced, and a creature held home is PRICED against the attack it
forgoes instead of tested against a threshold. Our own death is a large
negative and theirs a large positive, which is what makes "survive"
dominate without a special case.

**The gate is exact, not tuned.** If every creature they control
connecting still leaves us alive, no attack we could declare loses the
game to the counter-swing, and the cohort's answer stands untouched. The
search runs in about **1.3 declarations per game** because of it.

**Determinism, which is load-bearing.** The tree reads the board and
writes nothing: no `MtgGame` mutation, no `game.rng` draw, no card the
seat may not see (pinned by two tests, one of them
`tests/ai/test_undo_log.gd`'s own whole-state differ). Ties keep the
widest attack and every sort falls back to battlefield order. The node
budget is SHARED OUT per candidate attack rather than spent first-come —
a global counter would hand the widest attack the whole tree and leave
the narrow ones truncated, which is a bias in favour of attacking
dressed up as a result. `--matrix decks/ --games 6 --seed 4242` is
byte-identical at `--jobs 1`, `4` and `22`.

**The ladder is gated by capability, the way `holds_instants` is.**
`AiProfile.combat_search_nodes`: Apprentice 0, Magician 0, Sorcerer
1,500, Wizard 3,000. The bottom two do not look past their own combat at
all.

#### It closes the reproduced board

`tests/ai/test_ai_crack_back_2026_09_05.gd` states the boards rather than
the win rate, the way the attack audit's own file does:

| board (ours vs theirs) | before | with the search |
| --- | --- | --- |
| Hill Giant vs a TAPPED Craw Wurm, **at 3 life** | 1 attacker, and it loses | **0** |
| the same board **at 20 life** | 1 | 1 |
| Hill Giant vs **two** tapped Craw Wurms at 3 life (dead whatever we do) | 1 | 1 |
| 3 Hill Giants vs a tapped Craw Wurm, them at 6 (a lethal push) | 3 | 3 |
| 4 Grizzly Bears vs a tapped Craw Wurm at 20 life (the gate) | 4 | 4 |
| 2 Grizzly Bears vs a tapped Craw Wurm, **at 5 life** | 2 | **1** |

The last row is the one a threshold cannot produce: one Bears has to stay
home to block the Wurm, and the other is still four free damage.

#### Measured: the win rate, asymmetrically, against a null

Same instrument, same five starter decks both rejected attempts were
measured on, so the three are directly comparable. The null is the
shipped AI (with item 1 in it) on both seats at the same seed.

| deck (mirror) | the search | null | Δ |
| --- | --- | --- | --- |
| Blue Skies | 51.9% (519-481) | 49.1% (491-509) | **+2.8** |
| Black-Red Raiders | 52.5% (525-475) | 50.9% (509-491) | **+1.6** |
| White Knights | 48.9% (489-511) | 47.6% (476-524) | **+1.3** |
| Mountain Artillery | 48.0% (480-520) | 48.3% (483-517) | **-0.3** |
| Big Green | 48.8% (488-512) | 49.3% (493-507) | **-0.5** |
| **all 5, 5,000 games each arm** | **50.0%** (2501-2499) | **49.0%** (2452-2548) | **+1.0** |

95% CI on the aggregate delta: ±2.0 points. Decks moving the right way:
3 of 5 (sign test p=0.500).

**Set against its two predecessors, on the same decks and the same
instrument:**

| | aggregate | worst deck |
| --- | --- | --- |
| the heuristic brake (rejected) | +0.4 | Mountain Artillery **-2.3** |
| the one-ply lookahead (rejected) | +0.3 | Big Green **-1.1** |
| **the search** | **+1.0** | Big Green **-0.5** |

Both rejections were left out for one stated reason: *an unmeasurable
gain that costs a matchup is a tuning liability.* This one costs no
matchup — -0.5 and -0.3 are inside a single deck's own ±3.1 interval —
and Big Green, the deck that punished both approximations for being
pessimistic, is now essentially flat.

#### Measured on BEHAVIOUR, which is what decides it

The win-rate delta is not decisive on its own (+1.0 against ±2.0), and
neither was `order_blockers`' +0.4. What decides it is the number the
change was made for, counted the same way the block audit counted its
own: over the 216-deck census, **1,296 games**, with the search on SEAT 0
and the shipped policy on SEAT 1 as an in-run control. A CRACK-BACK
DEATH is a seat losing on the OPPONENT's turn having attacked on its own
turn immediately before.

| | crack-back deaths, seat 0 | seat 1 (the control seat) | seat 0 wins |
| --- | --- | --- | --- |
| search off, both seats | 245 | 308 | 721 |
| **search on seat 0 only** | **181** | 317 | **738** |

**The searching seat dies to a counter-swing 26% less often, and the
control seat moves the other way** — which is the harness saying it is
not drifting on its own. Both figures reproduced exactly on a second
interleaved pass.

#### What it costs

Two readings, and they agree once the confound is named. Over the five
starter decks at 1,000 games each the two arms are **1,097.8 s against
1,094.2 s — no measurable difference at all**. Over the whole 216-deck
census the candidate arm is about **5% slower** (453.3 s against 475.0 s,
means of two interleaved passes), and **2.3 points of that 5 is longer
GAMES rather than slower ones**: the search holds attackers home, so
turns go 22.79 → 23.31 and spells cast go 29.39 → 30.60. The search's own
cost is what is left, which is small because the gate keeps it off
roughly nine combats in ten. For comparison, `cast_refusal` cost 6%.

### Tried and NOT kept

* **A global node budget.** The first version spent one budget across the
  whole decision, first-come. That hands the WIDEST attack the entire
  tree — it is enumerated first — and leaves the narrow ones truncated,
  which is a systematic bias towards attacking that would have looked
  like a result. Replaced before any measurement by a per-candidate
  slice, and recorded here because the bug is invisible in the output.
* **Searching the opponent's blocks (ply 2) as well.** Left as the
  shipped greedy model on purpose, not for cost: it would change how the
  AI prices its FORWARD combat, which is the 2026-09-04 attack audit's
  measured +2.5, and the two would then be one experiment instead of two.
* **The chain that drops the WORST defender first.** The >5-body fallback
  move list originally narrowed from the wrong end. Fixed before
  measurement; the powerset covers every board of five optional bodies or
  fewer, which the phase-3 note's own census (attack subsets mean 2,
  max 16) says is nearly all of them.

### Still open

* **The journal across a step boundary.** `_advance_step` / `_enter_step`
  journal nothing, which is why this search runs over a model rather than
  over the engine itself. Instrumenting the untap sweep, the draw step,
  cleanup and combat damage is the next increment, and it is what would
  let a search make its moves through the same helpers a real duel makes
  them through. **CLOSED 2026-09-05** — see "The journal across a step
  boundary", which also answers the question this bullet did not think to
  ask: a boundary crossing is 11-19x cheaper than a snapshot, but a whole
  TURN — which is what a crack-back node is — is at parity, so THIS
  search stays on its model whatever the journal covers.
* **One blocker per attacker**, on both sides of both combats — the
  engine-wide ledger row above, with the 4.5% that keeps it there.
  **REOPENED AND MEASURED 2026-09-05** — see "The gang block".
* **Neither player's hand is modelled.** Unchanged and deliberate: the AI
  does not look at cards it may not see. What 2026-09-05 added is the
  PROOF rather than the model: three tests that change only the hidden
  zones and pin that the declaration does not move (same section).

## The journal across a step boundary (2026-09-05)

The crack-back search of the same day runs over a FLAT MODEL rather than
over the engine, and said in as many words why: `engine/undo_log.gd`'s
documented boundary was the TURN MACHINERY — *"a search must not cross a
step boundary until they do"* — because `_advance_step` and `_enter_step`
journalled nothing. This closes that. It is a capability, not a policy
change: nothing in the shipped AI calls it yet, and a duel that never
searches still pays one null test per instrumented write.

### What it took, and why the shape

`MtgGame._rec_turn`, called at the top of BOTH `_advance_step` and
`_enter_step`, plus per-permanent records at the two boundaries that
write every permanent on the table. Four field lists:

| list | what it covers |
| --- | --- |
| `TURN_FIELDS` (41) | where the turn is (`_step_index`, `turn_number`, `active_player`, `priority_player`, `_passes`, `_skip_first_draw`), the four steps that hold themselves open, the combat damage step's own bookkeeping (`_first_strike_ids`, the request/split arrays, the three `awaiting_*` damage flags), the per-turn tallies cleanup empties, the 1997 phase-end life check's `game_over`/`winner`/`is_draw`, and the question machinery a turn-based action can open |
| `TURN_PLAYER_FIELDS` (11) | the untap sweep's counters, the draw step's per-step tally, the per-turn player flags cleanup wipes |
| `UNTAP_INSTANCE_FIELDS` (7) | what the untap sweep writes on every permanent on the table — both seats', because "attacked this turn" expires for everyone |
| — | cleanup takes each permanent WHOLE (`UndoLog.record_object`), because `_finish_cleanup` writes twenty-six fields each and a hand list would rot the next time a this-turn flag was added |

Plus `record_object(combat)` and `continuous.record_all()` at every
boundary, for the wholesale `combat.clear()` at declare-attackers and at
the end of the combat phase, and the three different expiries
`_advance_step` runs.

**Hand-listed rather than `record_object(self)`,** which is what a
departure and a resolution use, because `MtgGame` also carries the three
things a per-boundary record must not copy: `log_lines` (thousands of
strings by turn 20), `_instances`, and the battlefield caches.

**The list was not written from reading the code; it was DIFFED into
existence.** `tests/ai/test_undo_log.gd`'s differ takes a `GameSnapshot`,
makes the move with the journal on, unmakes it and names every field that
moved. The first run of it over a step boundary named exactly one
(`_step_index`); over a whole turn, eight. After the lists went in it
found one more — `damage_dealt_this_turn`, journalled at its own write
site but not at the wholesale wipe cleanup does — and then nothing.

### Measured: what a boundary costs

`tools/bench_undo.gd` section I, added for this. A `GameSnapshot` round
trip against a `make_mark`/`unmake_to` of the same move, mean of 100:

| crossing | board | snapshot | journal | records | speed-up |
| --- | --- | --- | --- | --- | --- |
| one step (main 1 → combat) | 10 | 3717 us | **198 us** | 264 | **18.7x** |
| one step | 20 | 4059 us | 232 us | 264 | 17.5x |
| one step | 40 | 4699 us | 309 us | 264 | 15.2x |
| one step | 80 | 5981 us | 527 us | 264 | 11.4x |
| a whole TURN (14 steps) | 10 | 4233 us | 3924 us | 5924 | **1.1x** |
| a whole turn | 20 | 4846 us | 4940 us | 7334 | 1.0x |
| a whole turn | 40 | 6108 us | 7142 us | 10154 | 0.9x |
| a whole turn | 80 | 9349 us | 12399 us | 15794 | 0.8x |

(One run. `tools/bench_undo.gd`'s own header says the absolute
microseconds move 10-20% between runs on a shared box and the ratios are
the robust reading; a second run of the same table gave 18.1x / 17.4x /
15.0x / 11.2x and 1.1 / 1.0 / 0.8 / 0.8.)

**And the second half of that table is the finding.** The journal is
proportional to the MOVE, and a whole turn is not a small move: untap
writes seven fields on every permanent, cleanup writes twenty-six, and
fourteen boundaries pay for the machinery each. At a turn's width the
journal is at PARITY with a snapshot — it is 0.8x on a wide board, i.e.
worse.

**The consequence, stated plainly, because it is the opposite of what the
crack-back pass expected.** A crack-back node is our combat, their untap
and their combat — a whole turn — so at ~4 ms a node a 3,000-node budget
would be twelve seconds per declaration. **The crack-back search cannot
move onto the real engine, and not because of the boundary: because of
the size of its move.** What the boundary buys is a search whose node is
ONE step or a few — a combat resolved to end of combat, a main phase, a
block assignment — and there it is 11-19x, which is the number M4
phase 3's design note asked for.

### Pinned

Ten new round trips in `tests/ai/test_undo_log.gd`, each ending in
`end_search()` (a journal left armed keeps recording, and the records
hold the game — the leak the file's own header already warns about):
one step; **every step of a turn, one mark per boundary**, so a gap names
the step it lives in; the untap sweep with a tapped board, a Barl's Cage
one-shot and a Wall of Dust ban outstanding; cleanup with marked damage,
a regeneration shield and an until-end-of-turn pump; a whole turn
including the draw, with the opponent's library checked back into order;
both combat damage steps under first strike; a 1997 phase boundary that
burns mana and checks for a dead player; an upkeep trigger crossed and
resolved (Juzám Djinn's own damage, made and unmade); and — the one that
states what the capability IS — **a search that plays our combat, their
untap and their crack-back through the real `declare_attackers` /
`declare_blockers` / `_advance_step`, watches a creature die and both
life totals fall, and rewinds all of it to nothing.**

### Still open

* **Nothing uses it yet.** The journal is a capability; `CombatSearch`
  still runs over its flat model, and for the reason above that is the
  right call for THAT search. The first search whose node is one step —
  a block assignment played through `declare_blockers`, a main phase
  played through `cast_spell` — is where the 11-19x is collected.
* **The whole-turn record is not as small as it could be.** `_rec_turn`
  runs at the top of BOTH `_advance_step` and `_enter_step`, which
  double-records ~124 fields per boundary (264 of the 5,924 a turn costs,
  times fourteen). Deliberate: either method can be entered on its own
  (`answer_choice` re-runs a held step, `_next_turn` enters step 0
  directly) and a duplicate record is free to UNMAKE — the log replays
  backwards, so the older value wins. Halving it would take a guard whose
  failure mode is a silent search bug, and it would not change the
  conclusion above: a turn would still be ~2 ms against a snapshot's ~4.
* **The one thing still outside the journal** is a card script writing a
  primary field onto a THIRD object during resolution — not its own card
  and not a target. Unchanged, and recorded in `engine/undo_log.gd`.

## The gang block: the AI reads more than one blocker on an attacker (2026-09-05)

The engine-wide ledger row *"the AI's combat maths blocks ONE creature per
attacker"*, reopened. The ENGINE has always implemented gang blocks fully
and the AI itself declares them — the block audit's own instrument counted
**46 gang blocks in 1,022 logged combats (4.5%)**. What was flat was the
AI's MODEL of a combat: every one of them assigned at most one blocker to
an attacker, so the AI could not see a counter-swing that two of its
bodies could hold between them.

### The arithmetic, and why it is not a second rules model

`CombatSearch.resolve_block(attacker, blockers, ours_attacks)` returns
`[attacker dies, bitmask of blockers that die, damage past]` for one
attacker against a whole gang, and every rule in it is the engine's own:

* **the damage order is `AiPlayer.order_blockers`' own** — the agent that
  announces it for the live game (CR 509.2) — restated over the model: the
  max-WORTH subset of blockers whose lethal totals fit inside the power on
  offer goes first, worth-descending, the rest after, and a body nothing
  can be gained from (indestructible, a regenerator with its mana open,
  one the attacker's damage is prevented against) is worth zero and sorts
  to the back;
* **lethal-first down that order** (CR 510.1c), which is what
  `MtgGame.default_damage_split` does;
* **trample spills only what is left after every blocker has been
  assigned lethal damage** (CR 702.19b);
* **first strike is decided per ASSIGNMENT, not per pair** (CR 510.4).
  That is what forced `AiPlayer._damage_from` to be split in two:
  its first-strike clause asks whether the victim's power reaches the
  hitter's whole toughness, which is right when they are alone together
  and wrong inside a gang, because an attacker facing three blockers
  divides its power between them. `_damage_after_prevention` is the half
  the model takes raw.

**And the pin that keeps it honest: for a gang of ONE it must give exactly
what `AiPlayer._dies_to` gives**, pair by pair, over a board built out of
the awkward cases — first strike both ways, protection from a colour, a
regenerator with its mana open, a trampler, a 0/8 wall.
`tests/ai/test_ai_gang_blocks_2026_09_05.gd` checks all twenty pairs of
it. **The Deck Lab then checked the same thing end to end**: the null arm
below is the new resolver with `gang_defence` off, and it is
**byte-identical to a run of the code as it stood before this pass** —
1,000 Big Green games and 1,000 Black-Red Raiders games, game for game.
So the null really is the shipped AI and not a near-miss of it.

### Two halves, measured apart, because they pull opposite ways

* **OUR blocks of THEIR crack-back (ply 4).** Knowing two bodies can hold
  an attacker one cannot makes the search BRAVER: fewer attackers have to
  stay home as insurance.
* **THEIR blocks of OUR attack (ply 2).** Knowing they can gang up on
  what we send makes the forward attack more CAUTIOUS — which is the
  exact fault the 2026-09-04 attack audit spent a pass removing.

Measured on the same instrument at once: at every declaration the search
reached, answer it three ways and count the disagreements. Five starter
decks, 200 mirror games each, **1,323 searched declarations**.

| | declarations changed | wider (more attackers) | narrower |
| --- | --- | --- | --- |
| gangs on OUR defence (ply 4) | **200 of 1,323 (15.1%)** | **134** | 47 |
| gangs on both sides | 252 of 1,323 (19.0%) | 92 | **120** |

The second row is the whole argument. Adding ply 2 fires MORE often and
turns the change from a 2.9:1 lean towards attacking into a 1.3:1 lean
away from it.

### Measured: the win rate, asymmetrically, against a null

The block audit's instrument: candidate on SEAT 0, shipped policy on
seat 1, mirror matchups, 1,000 games each, against a null run of the
identical shipped AI at the same seed (20260905). The figure is seat 0's
win rate. Seat 1 wins these mirrors by two to three points whatever is
running, which is why the null column is the only one worth reading
against.

| deck (mirror) | ply 4 only | both plies | null | Δ (ply 4) |
| --- | --- | --- | --- | --- |
| Big Green | 44.0% (440-560) | 43.9% | 44.1% (441-559) | **-0.1** |
| Blue Skies | 47.5% (475-525) | 47.9% | 47.4% (474-526) | **+0.1** |
| White Knights | 49.8% (498-502) | 49.8% | 49.6% (496-504) | **+0.2** |
| Mountain Artillery | 49.4% (494-506) | 49.3% | 49.4% (494-506) | **0.0** |
| Black-Red Raiders | 46.7% (467-533) | 46.6% | 46.7% (467-533) | **+0.0** |
| **all five, 5,000 games each arm** | **47.5%** (2374-2626) | **47.5%** (2375-2625) | **47.4%** (2372-2628) | **+0.1** |

95% CI on the aggregate delta: ±2.0 points. **The win rate does not
decide this and is not claimed to**, exactly as `order_blockers`' +0.4 did
not decide that one.

**Black-Red Raiders is the row the change cannot move, and it lands on
the null with a BYTE-IDENTICAL `matchups.csv` — 467-533 both ways, both
halves of the seat split, the turn averages to two decimals.** It is not
quite the same 1,000 games: `results.json` carries `avg_turns` to three
decimals and it moves, 16.036 to 16.039. That is the most precise
statement available and it is a better one than "identical" would have
been — **the change fires in this deck and never once changes who wins.**
The census says how often it fires: over 219 searched declarations in that
deck the defensive widening changed **6** of them. It is a fifteen-
creature aggro mirror that ends on turn 16 with small boards, so the two
idle bodies a gang needs are rarely both there while the search's gate is
open.

### Verdict, and what it rests on

**KEPT: gangs on our own defence.** The case is not the win rate — it is
that the change fires in 15.1% of searched declarations, moves the play
2.9:1 in the direction the last two audits established as the right one,
costs **+0.9% of game time** (1,162.5 s against the null's 1,151.9 s over
5,000 games), and makes the model agree with a rule the engine implements
and this same AI already plays 4.5% of the time.

**NOT KEPT: gangs on their side of our forward combat**, and it was built,
measured and then deleted rather than left behind a flag. Three reasons,
in order of weight: it moves 120 declarations the narrow way against 92
wide; it costs +2.0% of game time against +0.9%; and it would make ply 2
disagree with `AiPlayer._cohort_value`, which chose the cohort under the
one-blocker model and still does — the search would then systematically
price attacks below the analysis that proposed them. Lifting that half
means moving `_cohort_value`, `_damage_through_blocks` and ply 2
together, which is one change, not three, and it is what the narrowed
ledger row now says.

### One pinned board changed, and the reason is worth reading

The crack-back pass's own table ended with *"2 Grizzly Bears vs a tapped
Craw Wurm, at 5 life: 1 attacker — the row a threshold cannot produce"*,
justified as *"one Bears has to stay home to block the Wurm, and the other
is still four free damage."* **It now declares 0, and the old
justification was an artefact of the simplification it was measured
under**: the reason the second bear's attack was "free" is that whichever
bear stayed home was going to die to the Wurm anyway. Two bears TOGETHER
kill a 6/4, so the counter-swing becomes a swing the opponent does not
make, and holding both is worth more than two points of face damage and a
dead bear. `tests/ai/test_ai_crack_back_2026_09_05.gd` carries the
paragraph next to the assertion.

### Cost, and the one thing to watch

Gang enumeration multiplies ply 4's branching factor: the move list for
one attacker goes from `1 + blockers` to `1 + blockers + pairs + triples`,
capped at [constant CombatSearch.GANG_LIMIT] = 3 bodies drawn from the
best [constant CombatSearch.GANG_POOL] = 6. The node budget is unchanged,
so a wide board now truncates sooner. Two things keep that safe and both
are deliberate: the move list is **none, then singles, then gangs**, so
alpha-beta still gets its bound from the move the shipped policy would
make and a truncated line degrades to exactly the old one-blocker answer;
and the budget was already shared out per candidate attack. If a later
pass widens the search, this is the first constant to re-measure.

### Still open after the gang block

* **The forward half of the same row** — `_attack_risk`,
  `_cohort_value`, `_damage_through_blocks` and ply 2 — measured and left
  out above, and the ledger row now says what lifting it would take.
* **A blocker dividing its damage among several attackers** (`cur_extra_blocks`
  — Two-Headed Giant of Foriys, Blaze of Glory) is still outside every
  model: `resolve_block` takes one attacker and its gang, not the other
  way round. Same for defensive banding's `free_order`, which the block
  audit already recorded as too rare for a measurement to resolve.
* **`GANG_LIMIT` = 3 and `GANG_POOL` = 6 are unmeasured constants.** They
  come from `order_blockers`' own note that a gang block is two or three
  bodies, not from a census of gang WIDTH. If the search is ever widened,
  measure them.

## What the search is allowed to see — and what it still is not (2026-09-05)

The third of the three items this pass was given, and **it is reported
undone on purpose.** The brief was to model the opponent's hand honestly —
what a player at the table could know — with the hard constraint that the
AI must never read the actual cards. Nothing was built. What was built
instead is the PROOF of the boundary as it stands, because the constraint
is worth more than the feature and a claim like this should be pinned
rather than asserted.

**What the search reads, in full.** `AiPlayer._build_combat_model` is the
whole list, and after it the tree indexes flat arrays and nothing else:

| read | zone | public? |
| --- | --- | --- |
| every creature on BOTH battlefields — power, toughness, damage marked, keywords, colours, protection and prevention, indestructibility, whether a regeneration shield is affordable | battlefield | yes |
| whether each of their permanents is tapped | battlefield | yes |
| both life totals | — | yes |
| `CombatState.block_illegality` and `attack_illegality`'s durable half over those creatures | battlefield | yes |
| which of OUR creatures the cohort chose to attack with, and whether a pump in OUR hand was counted | our own hand | ours to read |

Not read, at all: their hand, their library, their graveyard, their deck
list, `AiMatchMemory`. **Three tests pin it**
(`tests/ai/test_ai_crack_back_2026_09_05.gd`):

* replace every card in the opponent's hand — seven Giant Growths, seven
  Mountains, seven Shivan Dragons — and the declaration does not move by
  a body;
* reverse their whole library and it does not move;
* and the structural half, which fails loudly if somebody adds a hand term
  later: every field of `CombatSearch` is a flat array of numbers sized
  one per creature or one per pair, so there is nowhere in it to put a
  card nobody has seen.

**Why nothing was built.** An honest hand model is a distribution over
what their deck could still hold, conditioned on what has been revealed —
and the only thing the combat search could do with it is fear a trick,
which means holding attackers home. Every version of "hold attackers home
because something might be there" that this project has measured has lost:
the heuristic brake (Mountain Artillery -2.3), the one-ply lookahead (Big
Green -1.1), and now the forward half of the gang block (120 declarations
the narrow way). A hand model would be a fourth, and it would arrive with
a bigger surface and a fairness risk attached. The honest order is: build
it where it can make the AI CAST something it is not casting (the block
audit's class 1, "only castable in our own main phase"), not where its
only output is caution.

## The control sweep: the AI could not pilot a control deck (2026-09-06)

Every AI measurement this project had made was a MIRROR — a candidate
policy against the shipped one on the SAME deck — and a mirror cancels
out exactly the kind of blindness that is the same on both seats. The
first measurement taken against an external standard found one.

**Brian Weissman's The Deck**, the archetypal control list, scored **3.8%
against the five shipped starters — 57 wins in 1,500 games**, 2 in 300
against White Knights. The list is not the problem: it is 59/60 of Randy
Buehler's August 2015 Old School build, one substitution documented in
the file. Average game length against Big Green was 31.8 turns with a
median of 23 — the AI SURVIVED and then lost, which is a player that
defends adequately and has no idea how to win.

### What the article says the deck is, and what the sweep found

Wizards' own retrospective (magic.wizards.com, "The Deck", 2014-02-17)
and Weissman's *Taking Card Advantage* (The Duelist #14, April 1996)
state the principles as: **elongate the game until it is out of the
opponent's reach**; answer threats one-for-one and bank the difference;
**"taking cards away from your opponent is card advantage just as much as
drawing cards of your own"**; and win with ONE threat deployed only after
stabilising — "The Deck's principal way to win is by attacking with Serra
Angel", and Buehler's Old School list does not even run the Angel. **Its
only threat is three Mishra's Factories.**

The dead-card sweep (the method from the 2026-09-04 pass) was run over
the whole list: 100 instrumented games, 20 against each starter, every
card counted for turns-in-hand, turns-on-battlefield, casts and
activations. Four rows carried the whole finding:

| card | turns on the battlefield | activations |
| --- | --- | --- |
| **Mishra's Factory** — the deck's ONLY win condition | 2,339 | **0** |
| **Disrupting Scepter** — the deck's soft lock | 1,706 | **0** |
| Strip Mine | 2,733 | 0 (cost rider the planner did not model — closed 2026-09-06, `pays_sacrifices`: 45 activations per 200 games, see THE 2026-09-06 PASS) |
| Library of Alexandria | 890 | 27 |

**The AI had never once animated a Mishra's Factory**, so a deck of
fifty-nine answers had literally no way to end a game it had already
stabilised. Its 57 wins were the opponent decking out.

### Why, structurally — and it is one hole, not three

`AiPlayer._ability_option` prices an activated ability by the board it
changes: damage dealt, a creature removed, a permanent tapped, cards
drawn, life gained, a sweeper's swing. Everything else falls through to a
final `return {}` — "pumps, regeneration, mana, untaps, unknowns: not
here". **An animation changes nothing until the attack it enables, and a
discard changes nothing on the board at all**, so both landed in that
`{}` and neither could ever be chosen. The same hole that class 2 of the
2026-09-04 sweep found in `card_value` (a creature the evaluator could
not price was never cast) had a twin one function over, in the ability
scorer, and it swallowed the entire control archetype.

### What was built — three general capabilities, none card-named

* **`EffectIntent` reads the ANIMATE shape** (`AnimateSelfEffect`, kept
  whole the way a sweeper is, because its worth is a combat calculation)
  **and the AIMED DISCARD.** There is no shared `DiscardEffect` in this
  vocabulary — every discard in the pool is a card-local class — so the
  reader consults the effect's own `describe()` line, the precedent
  `_is_counterspell` set for the same reason. The `target player` /
  `target opponent` prefix is the guard that separates an aimed discard
  (Scepter, Rag Man, Gwendlyn Di Corci, Wand of Ith, Nebuchadnezzar) from
  a symmetrical one (Wheel of Fortune, Mind Bomb) and from one WE pay
  (Contract from Below, Recall) — pinned by a test, because getting it
  wrong would have the AI emptying its own hand every turn.
* **`_animation_value` prices the animation as the ATTACK it enables**, in
  the same `_face_damage_value` currency `_declare_attacks` uses, so the
  scorer and the attack code agree about one swing. It refuses in four
  places, and the refusals are the interesting half: already a creature
  (the animation has no per-turn cap, so the mana sink would re-animate
  the same land forever), not our precombat main / tapped / summoning
  sick (CR 302.6, the Factory judge call), and — the one that decides how
  the deck plays — **any untapped creature they could block with that
  survives the body or kills it**. What animates is almost always a LAND,
  and a land traded for nothing is a mana source a control deck needed.
  That refusal reproduces Weissman's own order of operations (clear the
  board, THEN attack with the Factory) from the numbers rather than by
  being told.
* **An arm may state its own bar.** `ABILITY_BAR_MAIN` (3.0) asks "is this
  worth mana a SPELL might want" — but `_try_activate(MAIN)` runs only
  after `_try_cast_best` has declined every card in hand, and
  `_held_reserve` has already protected the instant this seat means to
  hold. An ability that **cannot be used at any later moment this turn**
  is therefore not competing with a spell, and answers to the SINK bar
  instead, for the sink's own stated reason: mana that would otherwise be
  lost. That is what makes an animation (useful only before our combat)
  and a `your_turn_only` Scepter fire at all — `_face_damage_value(2)` at
  20 life is 2.2, and against a 3.0 bar the Factory stayed a land even
  after the reader learned to see it. Two runs are on the record for
  exactly this: the arm with the moment's bar moved the number **not one
  game** (57-1443, byte-identical to the null); with its own bar it went
  to 118.
* **An animation is never paid for by tapping the thing it animates.**
  `ManaPlanner` sorts the least flexible source first, so Mishra's
  Factory — which makes exactly one colour — is the FIRST land the
  planner reaches for, and it happily tapped the Factory to pay for the
  Factory's own animation. The body that comes out cannot attack and
  cannot block (CR 508.1a, 509.1a both want an untapped creature), so the
  {1} bought nothing. `ManaPlanner.sources` already takes an `excluded`
  set; the animation asks for the plan without itself, BEFORE the option
  is offered. Worth **+1.7 points on its own** (137 → 162 wins).

All of it is gated by **`AiProfile.plays_engines`** — a CAPABILITY in the
sense `holds_instants` and `combat_search_nodes` are, off for Apprentice
and Magician, on for Sorcerer and Wizard. Reading a permanent as a thing
that PAYS OVER TIME rather than as a number on the board today is a whole
layer of play, and the bottom two difficulties not having it is the same
honest weakness as the Apprentice never holding an instant.

### Measured

The Deck against the five shipped starters, 300 games per matchup, seed
4242, wizard on both seats, against a null run of the identical shipped
AI at the same seed:

| matchup | shipped (null) | with the capability | Δ |
| --- | --- | --- | --- |
| vs Big Green | 1.3% (4-296) | **11.7%** (35-265) | **+10.4** |
| vs Blue Skies | 15.3% (46-254) | **22.7%** (68-232) | **+7.4** |
| vs White Knights | 0.7% (2-298) | **4.0%** (12-288) | **+3.3** |
| vs Mountain Artillery | 0.7% (2-298) | **6.7%** (20-280) | **+6.0** |
| vs Black-Red Raiders | 1.0% (3-297) | **9.0%** (27-273) | **+8.0** |
| **the whole gauntlet** | **3.8%** (57-1443) | **10.8%** (162-1338) | **+7.0** |

Five matchups of five move the right way; the aggregate 95% interval is
±1.6 points against a +7.0 shift. **A 2.8x win rate on the hardest deck
in the collection.**

### The row that provably cannot move — and it is the whole starter matrix

The five starters run **no animation, no repeatable discard and no draw
ability at all**, so every arm added here is unreachable from any of the
10 cells of their round robin. `matchups.csv` for the 5x5 matrix at seed
4242 is **BYTE-IDENTICAL to the null**, 3,000 games game for game — and
so is the same matrix piloted by a Sorcerer and by a Magician. Not a
tolerance, an identity: the change cannot cost the aggro decks a game
because it cannot execute in one.

That is also the honest limit of the claim. It is a general capability —
it fires for any deck holding a man-land or a repeatable discarder, and
there are nine playable such decks in `decks/` — but the five starters
are not among them, so the starter gauntlet says nothing about it either
way beyond "no harm, provably".

### Generality: the same capability on eight other decks

The capability is keyed on effect SHAPE, not on a card name, so the test
of that claim is other decks. **Weissman's four real historical lists**,
none of which runs a Mishra's Factory at all — so this measures the
DISCARD arm alone, against the same five starters, 1,500 games each:

| list | shipped (null) | with the capability | Δ |
| --- | --- | --- | --- |
| The Deck, Fall 1994 ("Protection deck") | 33.4% (501-999) | **36.6%** (549-951) | **+3.2** |
| The Deck, Winter 1994-95 | 35.6% (534-966) | **40.2%** (603-897) | **+4.6** |
| The Deck, February 1996 | 19.4% (291-1209) | **23.3%** (350-1150) | **+3.9** |
| The Deck, Summer 1996 | 1.9% (29-1471) | **2.3%** (35-1465) | **+0.4** |

Four of four the right way. Summer 1996 barely moves, and the reason is
the same finding from the other end: that list's only threat is Mirror
Universe, so a Scepter lock buys it turns it still cannot convert.

And a MIXED FIELD, where both seats get the capability and the question
is whether it costs anyone: eight playable decks, round robin, 300 games
a matchup, 8,400 games an arm. Four of the eight hold an animation or a
repeatable discard; four hold neither.

| deck | engine cards | null | with | Δ |
| --- | --- | --- | --- | --- |
| "Stalin" (n00bcon 2014, UR Eel aggro) | 1 Factory | 51.1% | **53.2%** | **+2.1** |
| Arch Angel (Sargent) | 4 Factory | 54.5% | **55.3%** | **+0.8** |
| Mono Brown Workshop Aggro (Menendian) | 2 Factory | 50.1% | **50.7%** | **+0.6** |
| Berlin (n00bcon 2016, The Deck) | 3 | 28.7% | 28.8% | +0.1 |
| Proto-Zoo (Edwards) | none | 64.4% | 64.1% | -0.3 |
| Twist of Fire (Merritt) | none | 63.5% | 62.9% | -0.6 |
| Beckert (EC Old School 2015) | none | 35.6% | 34.8% | -0.8 |
| Ape Lord (Sargent) | none | 52.1% | 50.1% | -2.0 |

**Every deck that gains holds an engine card and every deck that loses
holds none** — a matrix is zero-sum, so a deck with nothing to gain loses
exactly what its opponents win. The worst single cell, Ape Lord vs Arch
Angel at -5.7, is Arch Angel's four Mishra's Factories finally attacking;
Ape Lord's own play is unchanged. And the identity holds cell by cell:
**every one of the six matchups where NEITHER deck holds an animation or
an aimed discard is byte-identical to the null**, 300 games each.

### Tried and rejected, with the numbers

* **Repricing the card-draw engines.** `_draw_need` is mage-go's appetite
  reading (a 7-card hand is charged -3.0, a 9-card hand -4.0) and it
  switches Library of Alexandria off at EXACTLY the hand size the card
  requires. Replacing it, for engine abilities only, with the real cost —
  the cleanup discard, which CR 514.1 puts on the ACTIVE player alone, so
  a card drawn at their end step is never discarded — made the deck
  **worse: 9.1% → 7.3%** (137 → 109 wins), Big Green 8.7% → 5.7%.
  Restricting it to the mana-sink moment gave the same 7.3%. The reading
  is that card QUANTITY is not this deck's bottleneck and a four-mana
  Tome activation costs it the Counterspell. Left out; `_draw_need` is
  untouched.
* **Animating to BLOCK.** The defensive half of the same capability, in
  the declare-attackers window where the AI already answers an attack
  with removal — and the only window Jade Statue has at all ("activate
  only during combat", so the main-phase arm can never reach it).
  Measured **10.6% (159) with, 10.8% (162) without**: a wash, inside
  noise. No playable deck in the collection runs Jade Statue, so there is
  nowhere it could be shown to earn its place. Left out, and Jade Statue
  stays a dead card.
* **Keeping animated permanents off the mana plan** (a permanent that is
  a creature now but is not printed as one goes to the back of the source
  list). Measured **exactly neutral** — 136-1364 with and without — because
  by the time a permanent is animated the main phase has already spent its
  mana. Left out; the real bug was one step earlier, and is fixed above.
* **Animating BEFORE the main-phase caster** rather than after it, so the
  clock is bought before a spell takes the mana: **8.4% (126) against
  9.1% (137)**. The sequencing that looks obviously right costs more mana
  than the swing is worth. Left out.

### What is still open

* ~~**Strip Mine, and the thirteen other sacrifice-cost abilities.**~~
  **CLOSED 2026-09-06** — `AiProfile.pays_sacrifices`, priced by the
  body that goes, `_best_victim` looking past creatures; Dracur's mirror
  49.8% -> 52.0%, the control pair byte-identical. See THE 2026-09-06
  PASS. (As written here: `_ability_available` refused any ability with
  a sacrifice rider; 2,733 battlefield-turns of Strip Mine, zero
  activations.)
* ~~**The Deck still loses 96% to White Knights.**~~ **INSTRUMENTED AND
  ANSWERED 2026-09-06**: the four Cities cost The Deck 3.3 life a game
  against 17 from the opponent — a tax, not the loss; the 96% is the
  matchup (The Abyss cannot target a White Knight). The tax got its model
  anyway (`ManaAbility.pain`, `AiProfile.minds_pain`: 6.2% -> 7.1%
  against White Knights) and the planner will never tap the last City at
  1 life. The loss profile stands as it was read: died on turn 27.8 with
  8.4 lands untapped and 1.8 enemy creatures worth 3.7 power on the table
  — ground down, not overrun.
* **The counter threshold is an absolute card value** (`counter_threshold`
  against `Evaluator.card_value`), so against White Knights The Deck
  counters almost nothing: Savannah Lions prices at 3.0 and Crusade at
  3.0 against a Wizard's 5.0 bar. Weissman's rule is different in kind —
  counter what your hand cannot answer LATER — and that is a real
  capability, but it runs through the same `_try_counter` that Blue
  Skies' two Counterspells use, so it cannot be made starter-neutral by
  construction the way this pass was. It needs its own measurement.

### The difficulty ladder, and a pre-existing inversion this pass exposed

The capability is gated by `plays_engines` exactly the way
`combat_search_nodes` and `holds_instants` are, so the ladder question
has to be asked. On a STARTER mirror it is untouched and monotone — Big
Green against a Wizard, 1,000 games a rung: **15.8% / 37.6% / 45.1% /
51.7%** (the last is the seat bias in a true mirror), and byte-identical
to the null at every profile because the starters cannot reach any of
the new arms.

On The Deck's own mirror the shipped ladder was **completely inverted**,
and this pass is what made it visible. Against a Wizard, 1,500 games a
rung:

| pilot | shipped (null), 400 games | with the capability, 1,500 games |
| --- | --- | --- |
| Apprentice | **87.8%** | 34.3% |
| Magician | 76.0% | 48.8% |
| Sorcerer | 73.8% | **60.6%** |
| Wizard (the mirror's seat bias) | 52.5% | 49.7% |

A fumbling Apprentice beat a Wizard **87.8%** of the time with the
shipped AI, and the worse the profile the better it did — because
neither seat could win, every duel went fifty turns to attrition, and
the seat that DID less took less City of Brass damage doing it. Playing
well was strictly a liability in a deck that had no way to convert it.
The capability puts three of the four rungs back in order. Sorcerer
still sits about eleven points above Wizard, which is outside its
interval and is now the open item — the Wizard's lower
`counter_threshold` (5.0 against 5.5) spends more mana in a game already
decided by attrition, and four City of Brass charge a life for every
point of it. That is a knob question on a deck that still cannot close
reliably, not a capability question, and it needs the loss-profile
instrumentation above before anyone touches a number.

### Gates

Suite 250 scripts / 4,376 tests, exit 0. `./duel_soak.sh` green (`SOAK
done`, 6 duels, exit 0). `matchups.csv` for the headline run is
byte-identical at `--jobs 1 --procs 1`, at the default, and at `--jobs 8
--procs 4`.

## Where we are — M1: engine core (DONE, v0.1)

Working and tested (50 tests / 647 asserts): turn/step machine with priority
(CR 117), the stack with LIFO resolution and fizzling (608.2b/c), casting
with timing + mana payment, lands & mana abilities (stackless, 605.3),
activated abilities with tap costs and summoning sickness (602.5g),
triggered abilities with APNAP ordering (603.3b), static abilities + until-EOT
effects via a recompute-the-world continuous pipeline, auras with SBA
cleanup (704.5m), combat with flying/reach/vigilance/trample/defender,
state-based actions (704: lethal damage, 0 toughness, life ≤ 0, draw from
empty library), deterministic seeded games, full game log. 19-card starter
pool proving every subsystem.

## Mechanics landed in wave 1 (2026-08-30)

First strike (two-wave combat, CR 510.5) · protection with the full DEBT
bundle (702.16) · regeneration shields (701.15) · landwalk by land subtype
(702.14) · "attacks each combat if able" + blocker-subtype bans (Juggernaut)
· counterspells (SPELL target kind + counter_spell, 701.5a) · X flowing into
effects (Fireball/Earthquake/Braingeyser/Stream of Life) · spell-produced
mana (Dark Ritual) · sacrifice mana abilities (Black Lotus) · bounce and
exile zone moves · random discard · self-pump activated abilities · global
static abilities (Crusade/Bad Moon) · per-turn attacked tracking (Erg
Raiders). All exercised in tests/unit/test_mechanics.gd.

## Mechanics landed in waves 19-42 (2026-08-31)

Everything below was added to `engine/` while graduating 288 stubs, each
with its own engine test in `tests/unit/test_engine_additions.gd` and its
card tests in `tests/cards/test_pool_wave19..42.gd`.

**Continuous pipeline** (`continuous.gd`; the pass order was reworked into
CR 613 layer order by the 2026-09 audit — reset → animations (4) →
type-changing statics (4) → base-P/T statics (7a/7b) → floating base-P/T
sets (7b) → colour changes (5) → the remaining statics (7c) → counters (7d)
→ floating pumps → landwalk grants → block restrictions → ability losses
(6) → combat-damage shields → P/T switches (7e); the file header is the
authority):
`MassPumpEffect` · CR 613.4e **P/T switches** (Transmutation) ·
**base-P/T sets** in layer 7b (Island of Wak-Wak, Sorceress Queen) ·
**ability losses** incl. all-landwalk (Hammerheim, Urborg) · **landwalk
grants** (Scarwood Hag) · counters of ANY `+A/+B` name (`-0/-2`, `+1/+0`,
`+0/+1`) · floating **combat-damage prevention** (Lady Evangela, Kry
Shield).

**Rules systems**: the **world rule** (CR 704.5k) with `Supertype.WORLD` ·
**RAMPAGE** (CR 702.23) as a `CardData` field applied at declare-blockers ·
**landwalk nullifiers** (`MtgGame.nullified_landwalk` — the printed "as
though it didn't have it" is a blocking-rule change, not an ability loss) ·
**TOKENS** (`create_token`, `schedule_end_step_token`; tokens cease to
exist on leaving, CR 704.5e) · **coin flips** (`flip_coin`, seeded through
`game.rng`) · **control leashes** ("for as long as you control / this
remains tapped" — `gain_control_leashed` + a state-based check) ·
**"can't be regenerated this turn"** · **attack/block caps** (Caverns of
Despair) · **untap caps** (Smoke, Winter Orb, Damping Field) · **forced
blocking** (Lure) · **delayed end-step destruction** (Berserk, Stone
Giant) · `END_OF_COMBAT` event · leave-the-battlefield triggers now reach
the departing card (CR 603.6d).

**Targeting** (`target.gd`): `TargetSpec.opponent()` · source-aware
filters (`with_source_filter`) · shroud, "can't be the target of spells",
"can't be enchanted by other Auras", "can't be the target of Aura spells".

**Abilities**: `ActivatedAbility` riders — `during_step`, `before_step`,
`your_turn_only`/`opponents_turn_only`, `opponent_activated`,
`with_exile_cost`, `with_random_discard_cost`, `only_if` (arbitrary
activation condition), and **{X} costs** (`activate_ability(..., x_value)`).
`ManaAbility` riders — `without_tap`, `with_sacrifice_of`,
`scaling_with_sacrifice`, `with_dynamic_amount` (the Urzatron),
`with_life_cost`, `with_side_effect`.

**CardData flags**: `rampage`, `cant_be_aura_target`,
`sacrifice_if_no_land_type` (lifted the Sea Serpent / Pirate Ship ledger
rows), `sacrifice_if_you_control_subtype`, `enters_with_counters`,
`may_skip_untap`, `dies_returns_to_hand`.

**Player-level statics**: `max_hand_size` (Cursed Rack),
`min_life_from_damage` (Ali from Cairo), `artifact_damage_redirect`
(Martyrs of Korlis), `artifact_damage_this_turn` (Reverse Polarity),
predicate-keyed prevention shields (Circle of Protection: Artifacts).

**Cost reductions**: cost modifiers may now be NEGATIVE (Mana Matrix,
Planar Gate, Stone Calendar), clamped so a reduction never eats coloured
pips (CR 601.2f).

**CardInstance**: LIVE `cur_mana_abilities` / `cur_activated_abilities`
(so Evil Presence really retunes a land and Zombie Master really grants an
ability), `memory` for card-local choices, `cur_damage_immunity`
(source-filtered prevention), `damaged_players_this_turn`,
`blocked_this_turn`, `added_types`.

**Engine bug fixed**: combat state was cleared when the end-of-combat
STEP began instead of when the combat PHASE ends, so "target attacking
creature" was already illegal for Desert's end-of-combat ping
(CR 506.4/511.3).

## Mechanics landed in wave 43 (2026-08-31)

**Multi- and divided targeting** (`engine/core/target_plan.gd`, new): an
effect may now demand a variable NUMBER of targets and split an amount
between them. `EffectBase` gained `target_min`/`target_max`,
`one_or_more()`, `x_targets()` ("X target creatures" — the count is the
spell's X) and `divided_among()`, plus `resolve_multi()` — the entry point
MtgGame calls, whose default repeats the single-target `resolve()` once per
chosen target (so TapEffect, UntapEffect and friends became multi-target
for free). `TargetRef` carries an `amount` (a target's share of a divided
total); `TargetPlan` groups the caller's flat ref list per effect,
enforces legality, the no-duplicate rule (CR 601.2c) and the division
arithmetic (CR 601.2d); `StackItem.target_groups` carries the grouping to
resolution, where an individually illegal target now drops out of its group
instead of skipping the whole effect (CR 608.2c). Also landed:
`TargetSpec.legal_targets` (a legal-target census, used by the plan and the
AI), `ManaCost.x_count` (a doubled {X}{X} cost really charges twice —
Part Water), `CardData.extra_cost_per_target` ("costs {1} more for each
target beyond the first" — Fireball), `MtgGame.return_from_graveyard_to_library_top`,
and `GrantLandwalkEffect`. The AI picks the extra targets a variable-count
effect needs (`AiPlayer._extra_targets`).

## Mechanics landed in wave 44 (2026-08-31)

**Live colours** (CR 105.2 / 613 layer 5): `CardInstance.cur_colors` is now
the live colour mask every rules check reads — `has_color()` /
`is_colorless()` replaced `data.color_mask()` at all 46 call sites in
`engine/` and `cards/`. Two durations: INDEFINITE changes ride on
`CardInstance.color_override` (restored by `reset_characteristics`, cleared
by the zone change, applied by `MtgGame.set_color`) and UNTIL-END-OF-TURN
ones float in `ContinuousEffects.add_until_eot_color`, applied BEFORE the
statics pass so the anthems (Bad Moon, Crusade) see the repaint. A Lace
aimed at a spell on the stack keeps its colour when that spell resolves into
a permanent. Also landed: `TargetSpec.Kind.SPELL_OR_PERMANENT` (the Laces'
target line), `ChangeColorEffect`, and `DecisionAgent.choose_color` (the
"colour of your choice" hook — Alchor's Tomb, Dream Coat). Kormus Bell's
colour simplification was lifted with it.

## Mechanics landed in wave 45 (2026-08-31)

**The random-effect subsystem** (`engine/random_effects.gd` +
`engine/effects/random_effect_table.gd`, both new) — the whole Astral set's
vocabulary, every pick routed through `MtgGame.rng` so a seeded duel replays
a Whimsy line for line: `RandomEffects.roll/pick/permanent/creature/
spell_or_permanent/damage_target/player/color/card_in_graveyard/
card_in_libraries/creature_type_of/distribute`, plus the two 1997 lists —
`RandomEffectTable` (Whimsy's 17, `@WHIMSY_MESSAGES`) and
`RandomCreatureEffectTable` (Faerie Dragon's 20, `@FAERIEDRAGON_MESSAGES`;
`engine/effects/random_creature_effect_table.gd`, lifted 2026-09-02 with
`TargetSpec.at_random` — the game rolls "random target creatures" as the
spell or ability is put on the stack). Supporting engine additions: `CardInstance.added_protection`
(permanent protection grants — Rainbow Knights), `ManaAbility.with_dynamic_color`
(Gem Bazaar taps for "the colour last chosen"), `ActivatedAbility.with_colored_x`
+ `ManaCost.plus_colored` ("Pay {R} for each target" — Goblin Polka Band).

## Mechanics landed in wave 46 (2026-08-31)

**ANTE** — the zone `Mtg.Zone.ANTE` reserved since v0.1 is now real, and with
it the one change that outlives a duel. `MtgPlayer.ante` holds each player's
stake (a card sits with its OWNER), and `MtgGame` gained `all_ante`,
`move_to_ante` (from any zone; tokens refused, CR 704.5e),
`ante_top_of_library`, `remove_from_ante`, `return_from_exile_to_graveyard`,
the private `_remove_from_zone`, and — the important one —
**`change_owner`**, a permanent ownership transfer that moves the card into
the new owner's copy of its current zone (Bronze Tablet, Tempest Efreet,
Darkpact). `TargetSpec.Kind.CARD_IN_ANTE` targets the public ante.
Shandalar's adventure economy (M5) plugs straight into this.

## Mechanics landed in wave 47 (2026-08-31)

**COPYING** (CR 707). A copy takes the copiable values of what it copies —
and in this engine "printed values" IS `CardInstance.data`, so copying is
repointing that one reference: the object keeps its id, counters, damage and
controller, and `CardInstance.printed_data` restores it the instant it
leaves the battlefield. `MtgGame.become_copy` (with `extra_types` for Copy
Artifact's "in addition to its other types" and `keep_own_colors` for
Vesuvan Doppelganger's "doesn't copy that creature's color"),
`CardData.enters_as_copy` — a real REPLACEMENT effect applied inside
`_put_on_battlefield`, so a 0/0 Clone is never on the battlefield for
state-based actions to bury — plus `CardData.shallow_copy` /
`with_extra_trigger` for "and it has this ability".
**Spell copies**: `MtgGame.copy_spell_on_stack` + `find_stack_item` +
`CardInstance.is_copy`; a resolving copy ceases to exist instead of going to
a graveyard (CR 707.10a). Also landed: leave- and dies-triggers now carry a
SNAPSHOT of the departing permanent's `memory` in their event data, since
battlefield state is wiped before they fire (CR 400.7).

## Mechanics landed in wave 48 (2026-08-31)

**POISON COUNTERS** (CR 704.5c): `MtgPlayer.poison`, `MtgGame.add_poison`,
and the ten-counter loss as a state-based action.

**BLOCK HISTORY** — the record the whole Glyph cycle is built on:
`CardInstance.blocked_ids_this_turn` maps every creature a permanent blocked
this turn to **the controller it had at that moment**, which is Glyph of
Reincarnation's "the player who controlled that creature the last time it
became blocked by that Wall", verbatim. Cleared at cleanup.

Supporting additions: `MtgGame.schedule_end_of_combat_action` (a delayed
end-of-combat action that outlives its source, CR 603.7a — Glyph of Doom),
`MtgGame.watch_damage_for_life` (a floating "whenever that creature is dealt
damage, you gain that much life" watch — Glyph of Life),
`CardInstance.cur_prevent_all_damage_taken` (Glyph of Destruction), and the
turn-based **glyph counter** rules in the untap and upkeep steps ("doesn't
untap while it has a glyph counter"; "remove one at your upkeep").

## Mechanics landed in wave 49 (2026-08-31)

**RESTRICTED MANA** (CR 106.6): `ManaPool` keeps a second, KEYED pool —
"spend this mana only to cast artifact spells" (Mishra's Workshop) /
creature spells (Metamorphosis). A payment names the usage keys it
qualifies for (`MtgGame.mana_usage_keys`) and restricted mana is spent
FIRST, because it is the mana that would otherwise be wasted.
`ManaAbility.with_restriction` produces it. Alongside it:
`MtgPlayer.mana_substitutions` ("you may spend white mana as though it were
red" — Sunglasses of Urza, rebuilt by the continuous pipeline) and
`MtgPlayer.any_color_spells` (North Star's one-spell wildcard, consumed only
by a cast that actually needs it).

**TEXT CHANGES** (CR 613 layer 3): `CardInstance.text_changes` +
`MtgGame.change_text`, applied at the end of every characteristics reset.
Three kinds — `land_type` (Magical Hack: subtypes, landwalk, and a basic
land's mana all follow), `color_word` (Sleight of Mind: protection colours)
and `mana_color` (Quarum Trench Gnomes). `Mtg.BASIC_LAND_COLORS` is now the
one place that answers "what does a Swamp tap for".

Also landed: `CardData.additional_sacrifice` — "as an additional cost to
cast this spell, sacrifice a creature", paid as the spell goes on the stack
(CR 601.2h) with the eaten permanent's mana value recorded in the spell's
own memory.

## Mechanics landed in wave 50 (2026-08-31)

**COMBAT RE-ARRANGEMENT** — reaching into a combat after it is declared:
`MtgGame.set_block` (re-assign a blocker mid-combat — False Orders,
Sorrow's Path), `CardInstance.must_block_this_turn` (an order to block,
enforced by `declare_blockers` — Blaze of Glory),
`MtgGame.camouflage_this_turn` + `_camouflage_block_map` (the defender's
piles, asked through the turn-based hold, DEALT to the attackers through
`game.rng` — Camouflage), and
`MtgGame.gain_control_until_eot` (a borrowed permanent that goes home at
cleanup even if the effect that took it is gone — Disharmony). Raging
River's left/right banks ride the existing `cur_block_restrictions`
machinery.

~~Still owed here: a ONE-TO-MANY block map~~ **DONE 2026-09-02** —
`CombatState.extra_blocks` (blocker id → the ADDITIONAL attackers it
blocks, CR 509.1b) with `CardData.extra_blocks` for the printed permission
(Two-Headed Giant of Foriys) and `CardInstance.extra_blocks_this_turn` for
the granted one (Blaze of Glory, which also means its *"blocks EACH
attacking creature"* can finally ask for each). `blocks` keeps its shape —
one entry per blocker, naming the first attacker — because two dozen cards
ask `blocks.has(id)` and CR 509.1b describes a multi-block the same way;
the "is X blocking Y" question moved to `CombatState.is_blocking`. The
damage requests are now built ONE PER BLOCKER instead of one per band,
which is what stops a blocker in two bands striking twice. Human and AI
both: `DuelScreen._pick_block` keeps a multi-blocker in hand after an
assignment so its second block is one more click. Pinned by
`tests/unit/test_one_to_many_blocks.gd` and `tests/ui/test_block_picker.gd`.

## Mechanics landed in wave 51 (2026-08-31)

**PHASING** (CR 702.25): `MtgGame.phase_out` / `phase_in` lift a permanent
(and everything attached to it) out of the battlefield arrays, so no query,
static, trigger or state-based action sees it and `TargetSpec` refuses it —
without a zone change, so nothing triggers either way.
`MtgPlayer.phased_out` parks them; `CardInstance.phased_out` marks them.

**A GAME DRAW** (CR 104.4): `MtgGame.draw_game` + `MtgGame.is_draw` —
`game_over` with `winner` left at -1. Divine Intervention is the pool's
only source.

**FACE-DOWN permanents** (CR 708): `CardInstance.face_down` makes an object
a 2/2 colourless creature with no name, no other types and no abilities;
`MtgGame.turn_face_up` restores it, and dealing damage, being dealt damage
and becoming tapped all do that automatically (Illusionary Mask's printed
replacement). `put_from_hand_face_down`, `exile_top_of_library` (face down)
and `return_from_exile_to_hand` round it out for Knowledge Vault.

**OUTSIDE THE GAME**: `MtgPlayer.outside_the_game` +
`MtgGame.take_from_outside_the_game` — empty in a plain duel, and exactly
where Shandalar's adventure layer (M5) will put the player's collection for
Ring of Ma'rûf to reach into.

## Mechanics landed in wave 52 (2026-08-31)

The MULTI-PART ONE-OFFS — no shared system, just their own design passes,
and the engine bits they each needed: `MtgGame.skip_rest_of_turn` (Time
Vault — replaced 2026-09-02 by the whole-turn skip `MtgGame._begin_turn`
/ `_skip_turn`, asked as the turn begins), `MtgPlayer.cant_lose_to_life` + `life_gain_becomes_draw` and
`MtgGame.lose_game` (Lich), `CardData.play_ban` + `MtgGame.play_banned`
("players can't cast spells … originally printed in Arabian Nights" — City
in a Bottle), `Mtg.EventType.BECAME_UNTAPPED` (Tawnos's Coffin releases its
prisoner on it), `MtgGame.pick_from_library` / `put_into_play` /
`put_into_graveyard` (Transmute Artifact's search-and-pay-the-difference),
and `return_from_exile_to_play`. Golgothian Sylex and City in a Bottle read
`CardData.set_code`, which the registry already keys to the set folder, so
"originally printed in <expansion>" is exact.

## Mechanics landed in wave 53 (2026-08-31)

More MULTI-PART ONE-OFFS, with the engine bits each needed:
`ManaAbility.with_counter_cost` ("Remove a dream counter: Add {C}" —
Rasputin Dreamweaver taps for mana without ever tapping),
`MtgGame.attach_aura_from_anywhere` (Takklemaggot jumping out of the
graveyard onto a new host), and `cast_spell` now records the chosen X on
the permanent's own memory (`memory["x_value"]`), which is how
Frankenstein's Monster knows how many corpses to eat.

## Mechanics landed in wave 54 (2026-08-31)

The Unlimited remainders, and the two flags they needed:
`CardInstance.cur_indestructible` (CR 700.4 — destruction and lethal damage
both do nothing; Consecrate Land) and `CardInstance.exile_instead_of_dying`
(Disintegrate's replacement, cleared at cleanup). Also
`MtgPlayer.untapped_lands_at_turn_start`, snapshotted by the untap step,
which is the number Power Surge actually asks for.

## Mechanics landed in wave 55 (2026-08-31)

Fourth Edition and The Dark remainders, plus two engine additions:
`ContinuousEffects.add_until_eot_block_restriction` (a floating "can't be
blocked except by …" — the same list the statics write into; Tower of
Coireall) and `MtgGame.no_attacks_this_turn` (a game-level attack ban,
cleared at cleanup — Festival).

## Mechanics landed in wave 56 (2026-08-31)

Arabian Nights, Antiquities, Legends and promo remainders. Engine bits:
`ManaCost.minus_generic` + `ActivatedAbility.shallow_copy`/`discounted`
(Power Artifact rewrites its host's LIVE abilities with cheaper copies —
the same live-abilities list Zombie Master appends to) and
`CardInstance.exile_after_resolution` ("Exile Recall", a spell that removes
itself instead of resting in the graveyard).

## Mechanics landed in wave 57 (2026-08-31)

**Damage redirection and bookkeeping**: `MtgPlayer.damage_taken_this_turn`
(Simulacrum), `MtgPlayer.combat_damage_redirect` (Veteran Bodyguard soaks
UNBLOCKED attackers only), `MtgPlayer.reverse_damage_shields` (prevent and
gain that much life), and `CardInstance.damage_redirect_to` /
`damage_redirects` (Jade Monolith's one-shot "that damage is dealt to you
instead").
**Conscription**: `CardInstance.must_attack_this_turn`, enforced by
`declare_attackers`, plus `doom_at_next_end_step_if_it_did_not_attack` —
the mirror of Berserk's clause (Nettling Imp).
**Graveyard triggers**: `CardData.graveyard_triggers` — abilities that
listen while their card is in a GRAVEYARD. Only the turn-based events
(UPKEEP_START, END_STEP_START) reach them, so the dispatcher's hot path is
untouched. Nether Shadow is the pool's only user.

## Mechanics landed in wave 65 (2026-09-01)

**CONTROL EXCHANGE** (CR 701.10): `MtgGame.exchange_control` trades two
permanents' controllers as ONE action — all or nothing per 701.10c (both
must still be on the battlefield, under different players), swapped inside
a `begin_simultaneous` bracket so an Aura that loses its host and the legend
rule both judge the finished board. Juxtapose, Gauntlets of Chaos and the
already-shipped Power Struggle are the pool's three.

**A CONTROL-CHANGE BAN**: `CardInstance.cur_cant_change_control`, gated in
`change_control` (the one door every control change goes through) and again
in `exchange_control`, where it stops the WHOLE trade rather than half of
it. That lifted Guardian Beast's ledger row — its third printed clause,
"other players can't gain control of them", is now real.

**SIBLING TARGET SLOTS**: `MtgGame.current_targets()` hands a resolving
effect every target of the object it belongs to, flat and in slot order.
One targeting effect owns one slot, so a card whose two slots take
DIFFERENT specs ("target artifact, creature, or land you control AND target
permanent an opponent controls") is two effects and the one that does the
work has to see the other slot; mage-go's `EffectContext.Targets` is the
same idea. Gauntlets of Chaos is the first user.

Also: `RandomEffects.sample` (N DIFFERENT random elements — Nebuchadnezzar's
"reveals X cards at random from their hand").

**The blocker analysis this wave disproved.** M3's stub table listed
"choice-heavy politics" as *"blocked less by mechanics than by the missing
await-based human prompt"*. That prompt had already shipped in §1.3; the
entry was written from reading rather than from building. All five cards
graduated on the ordinary `DecisionAgent` funnel.

## Mechanics landed in wave 66 (2026-09-01)

**DRAW REPLACEMENTS** (CR 614) — the hook the M3 table said the engine
lacked, and it really did. `MtgGame.draw_cards` is the one door every draw
in the engine goes through, so `_replace_draw` sits inside it and applies
two kinds:

- STATIC ones on a battlefield permanent (`CardData.draw_replacement` /
  `replaces_draws`) — Island Sanctuary, Chains of Mephistopheles;
- ONE-SHOT ones registered by a resolving effect
  (`MtgGame.replace_next_draw`) and consumed by the next draw they catch,
  cleared at cleanup because the clause says "this turn" — Aladdin's Lamp.

A replaced draw is not a draw: no card moves, no `CARD_DRAWN` fires and an
empty library cannot kill anybody through it. **CR 614.5** — a replacement
applies at most once to an event — is a re-entry guard held while a
callback runs, which is the only reason Chains of Mephistopheles terminates.
Both scans read battlefield-index lists built with the statics index, so a
duel with no replacement on the table pays one `is_empty()` per draw.

**A DRAW-STEP replacement**: `CardData.draw_step_replacement` /
`replaces_draw_step`, applied in `_enter_step`. The STEP is skipped, so
nothing draws, no `DRAW_STEP` event fires and nobody gets priority in it —
which is what separates Fasting from Island Sanctuary.

Supporting additions: `MtgPlayer.drawn_this_turn` (the CARDS drawn this
turn, because Sylvan Library asks which ones), `MtgPlayer.draws_this_step`
(would-be draws, reset every step boundary — Chains' "the first one they
draw in each of their draw steps"), `MtgGame.put_from_hand_on_top_of_library`
and `put_on_bottom_of_library`, and `ActivatedAbility.with_min_x` ("X can't
be 0" as a REFUSAL rather than a silent clamp — Aladdin's Lamp).

**The blocker analysis this wave corrected.** The M3 table filed **Sylvan
Library** with the draw-replacement cluster. It is not a replacement at all
— it is a plain draw-step TRIGGER, and what it actually wanted was the
record of WHICH cards were drawn this turn. Three of the four cards in that
bullet did want the hook; the fourth wanted a list.

## Mechanics landed in waves 67-72 (2026-09-01)

The one-off remainder, each card paying for one small SHARED piece rather
than a hack of its own. Every piece has its own tests (in
`tests/unit/test_engine_additions.gd`, `tests/unit/test_draw_replacement.gd`
or the wave's own card file).

**Objects on the stack**: a `StackItem` now carries an `id`, so an ACTIVATED
ABILITY is a first-class targetable object (CR 113.3b) —
`TargetSpec.Kind.ABILITY`, `TargetRef.ability`, `MtgGame.find_stack_ability`
/ `counter_ability`, and the shared `CounterAbilityEffect` with its optional
"unless its controller pays" ransom (Rust, Ayesha Tanaka). The printed
"(Mana abilities can't be targeted.)" needs no code: a mana ability never
reaches the stack. `MtgGame.retarget_spell` rewrites one target slot of a
spell already on the stack (Reflecting Mirror).

**ATTACK COSTS** (CR 508.1g): `CardInstance.cur_attack_costs`, checked for
every declared attacker BEFORE any is paid, so a declaration the engine
refuses spends nothing (Brainwash, Leviathan). Alongside it
`MtgGame.attacks_without_tapping` (Johan) and
`Mtg.EventType.COMBAT_START` — the beginning-of-combat step as an event
(Battering Ram, Johan).

**Costs that eat a card**: `ActivatedAbility.with_exile_of` (a permanent you
control — City of Shadows), `with_exile_from_graveyard` (Necropolis) and
`with_discard_cost` (a CHOSEN discard — Land's Edge), all paid in
`activate_ability` with the mana (CR 601.2h) and all leaving what they ate
on the source's memory. Plus `with_min_x` and `with_x_condition`, which turn
"X can't be 0" and "X is twice that spell's mana value" into REFUSALS
instead of wasted activations.

**Damage**: `CardInstance.damage_unpreventable_this_turn` (Whippoorwill —
every prevention and redirection gate skipped, protection included),
`MtgPlayer.damage_caps` (Forethought Amulet's replacement, applied before
any prevention), an `all_turn` flag on `MtgPlayer.prevention_shield_filters`
(Scarecrow's whole-turn shield), and **`MtgGame.damage_dealt_this_turn`** —
per-SOURCE damage amounts, the bookkeeping the table below said was owed
(Backdraft).

**Delayed things**: `MtgGame.schedule_end_step_action` (Rakalite),
`schedule_next_main_phase_action` (Mana Drain), `watch_death`
(Reincarnation) and `watch_damage_dealt` (Runesword) — all per-turn, all
outliving their source, all cleared at cleanup.

**Continuous pipeline**: `add_until_eot_keywords` and
`add_until_eot_protection` (CR 613 layer 6, applied before the losses so a
loss still wins — Battering Ram, Goblin Wizard).

**Smaller pieces**: `CardInstance.cur_cant_change_control` (Guardian Beast —
which lifted its own ledger row), `destruction_shields` (Pyramids, a
replacement that is NOT regeneration and so has no tap),
`CardData.on_discarded` (a trigger from HAND — Psychic Purge) with
`MtgGame.current_resolution_controller` to say who caused it,
`CardData.exile_triggers` (All Hallow's Eve ticking down from exile),
`TargetSpec.with_player_filter` (Fire and Brimstone),
`MtgPlayer.attacked_this_turn`, `acted_this_turn` / `acted_last_turn`
(Arboria), `life_for_mana` + `MtgGame.pay_life_for_mana` (Channel),
`land_mana_becomes` (Deep Water) and `MtgGame.exchange_control`'s
all-or-nothing guard.

## Engine simplifications still to lift (in rough priority order)

Wave 3 additions (2026-08-30): **multi-block** with lethal-first
auto-assignment · **banding** (attack bands, band-blocking, band damage
spread — defensive banding excluded, see combat.gd) · live landwalk grants
(cur_landwalk — tribal lords, Burrowing) · untap locks (cur_skips_untap —
Meekstone) · attack-requirement clauses (Sea Serpent) · milling (Millstone)
· any-card graveyard recursion (Regrowth — the Timetwister loop is complete)
· upkeep-punisher patterns (Karma, Vise/Rack/Tower).

Wave 7 additions (2026-08-30): **live types** — rules code now asks the
INSTANCE (`inst.is_creature()`), never printed data, and summoning
sickness rides on EVERY entering permanent (animated lands, CR 302.6) ·
**cost modifiers** (`CardData.cost_modifier` → `spell_surcharge`/
`ability_surcharge`, Gloom) · **type-changing animation**
(`AnimateSelfEffect` + `add_until_eot_animation`, Mishra's Factory) ·
**amount-based damage prevention** (`prevention` pools consumed by
`deal_damage`, Healing Salve/Samite Healer) · **the 1997 legend rule**
(SBA buries the NEWEST duplicate legend) · **modal spells**
(`CardData.modes` + cast-time mode; Blasts, Healing Salve) · **choice-UI
hooks** (HumanAgent pre-selection mailbox; DuelScreen mode menu + library
picker before tutor casts).

| Simplification (code site) | Replacement |
|---|---|
| ~~Damage-order & band-spread are auto lethal-first~~ **DONE 2026-08-31** — the attacker announces the order (CR 509.2, `DecisionAgent.order_blockers` → `CombatState.damage_order`) and divides the damage (`assign_combat_damage`); the human seat gets the 1997 `%d points left` click loop. `default_damage_split` is the old heuristic, now only a default. | — |
| ~~No damage-prevention step; prevention is applied automatically in a fixed order~~ **DONE 2026-09-01** — the 1997 window is `RulesOptions.damage_prevention_window` (default modern, so the automatic order is still what an untouched engine does). Damage is a `DamagePacket` in `MtgGame.damage_pending`; the prevention step and the regeneration step are `awaiting_damage_prevention` / `awaiting_regeneration`; `TargetSpec.Kind.DAMAGE` makes a packet targetable, `DamageMarker` / `DamageMarkerLayer` put it on the table to click, and `AiPlayer._window_action` plays both windows so the fork is a ruleset rather than a one-sided buff (docs/duel-todo.md §6.8, which also carries the 4000+2400-game measurement) | — |
| **A prevention POOL is spent greedily across packets** (`mtg_game.gd:_land_damage_impl`). `Duel.hlp` lets the player spread Healing Salve's three points over three separate 1-point packets by hand — *"Select damage point to heal (%d of %d)"*, `@HEALING_SALVE`, `Program/prompts.txt:451`. Ours spends the pool on the packets in the order they land. Only reachable under the 1997 window, and identical whenever one packet is waiting | **RE-WEIGHED 2026-09-02 and still declined — but the 2026-09-01 reason was WRONG and is corrected below.** See the three paragraphs under this table. |
| ~~No defensive banding (`combat.gd`)~~ **DONE 2026-09-01** — if ANY creature blocking an attacker has banding, the DEFENDING player divides that attacker's combat damage among its blockers, and divides it FREELY (the lethal-first order of CR 510.1c does not apply). One flag on the damage request (`free_order`) flips the assigner and relaxes `_split_illegality`; `default_damage_split` grows a defender-minded answer (all of it onto the body they mind losing least, which also denies a trampler its spill). Lifted Fortified Area and Wall of Caltrops, whose grants were inert. Pinned by `tests/unit/test_damage_assignment.gd` | — |
| "X target creatures" takes as many as exist when fewer than X are legal (`target_plan.gd`) | Force the caster to pick a smaller X instead (CR 601.2c) |
| The duel UI still prompts for ONE target per effect (`duel_screen.gd`) | A multi-pick + damage-division prompt (main session's domain) |
| ~~Cleanup discard is automatic~~ **DONE 2026-08-31** — the cleanup step HOLDS OPEN (`MtgGame.awaiting_discard` / `discard_to_hand_size`) for any seat whose agent says `wants_to_choose_discard`. The AI and the heuristic agent still answer their own. | — |
| ~~No mulligan~~ **DONE 2026-08-31** — the SHANDALAR rule (`Duel.hlp`): `deal_opening_hands` / `may_mulligan` / `take_mulligan` / `decline_mulligan` / `start_duel`. Seven for seven, only a no-land or all-land hand, one chance each, and the opponent may follow. The toss winner also chooses play or draw. | — |
| Simplified layers (`ContinuousEffects.recalculate`) | Full CR 613 layer/timestamp/dependency system — contained in that one method |
| ~~Triggers can't target (`TriggeredAbility`)~~ **DONE 2026-09-02** — `TriggeredAbility.targeting(spec, order, prompt)` gives a trigger a real target, chosen by its controller AS IT GOES ON THE STACK (CR 603.3d; `MtgGame._arm_trigger_targets`): the controller's seat is asked through the `DecisionAgent` funnel (a human seat is HELD on the question through the cost mailbox, provisional pick on the stack meanwhile — `StackItem.target_held`), the pick is shown in the stack description for the opponent to respond to, shroud keeps a creature off the list, and the trigger fizzles on resolution when the target has left (CR 608.2b) or never goes on the stack with nothing legal. `.modal(labels, hint, prompt)` announces a MODE before the target the same way (CR 603.3c; `MtgGame.current_mode()`). Triggers fired by a player's own action (cast, activate, tap for mana) reach that hold through `MtgGame._resume_priority` (CR 117.3c). Lifted the eight-card "triggers that pick their own victim" row (Oubliette, Halfdane, Dance of Many, Blazing Effigy, Axelrod Gunnarson, Floral Spuzzem, Relic Bind, Erhnam Djinn). Pinned by `tests/unit/test_targeted_triggers.gd` and `tests/cards/test_fidelity_2026_09_02_targeted_triggers.gd` | One target spec per trigger — enough for the 1997 pool |
| Triggered payments (`MtgGame.try_pay`) auto-tap LANDS only, greedy pick (basics first) | Let the payer choose sources; include artifact mana (Sol Ring) in the auto-plan |
| ~~No banding~~ **DONE** (attack bands wave 3, defensive banding 2026-09-01, "bands with other [quality]" 2026-09-02 — `CardInstance.cur_bands_with` / `grant_bands_with`, `CombatState.shared_bands_with` / `bands_with_offered` / `bands_with_among`; the five Legends banding lands and Master of the Hunt's Wolves grant the real per-quality restriction, not plain banding, pinned by `tests/cards/test_fidelity_2026_09_02_bands_with_other.gd`). No protection-from-artifacts etc. | As stubs demand them |
| ~~Mid-resolution questions are answered by a heuristic~~ **DONE 2026-08-31, FINISHED 2026-09-01** — every ask is a first-class `PlayerChoice` on the record. 103 of the 109 call sites are inside a stack resolution and the engine PRE-FLIGHTS each one over a `GameSnapshot` rewind point, then holds it open on `MtgGame.awaiting_choice` until `answer_choice`. The four COST payments outside the stack (`tap_for_mana`'s sacrifice, Fellwar Stone's colour, `cast_spell`'s additional sacrifice, `activate_ability`'s sacrifice cost) are held open by `MtgGame._pending_action` — a record of the ACTION that `answer_choice` re-issues, no rewind point, because all four ask after every refusal check and before any mutation (CR 601.2h). Same overlay, same `answer_choice`, told apart by `PlayerChoice.is_cost` (docs/duel-todo.md §1.3) | Only `CardData.as_it_enters` run from a NON-resolution path is left, and reached the ordinary way (a creature resolving) even that is inside the probe. Fellwar Stone's colour moved out of the card into `ManaAbility.color_options` on the way, which also fixed it being asked TWICE per activation and being asked after the source was already tapped |
| **A draw replacement asks OUTSIDE a resolution** (`mtg_game.gd:_replace_draw`, `_draw_step_skipped`). Island Sanctuary's *"you may skip that draw"* and Fasting's *"you may skip that step"* are asked from the draw step — a turn-based action — so the §1.3 pre-flight, which only wraps stack resolutions, cannot hold the question open for a human seat. The answer falls through to the heuristic and is LEDGERED in `unanswered_choices` | A third hold, for a question asked from a turn-based action: the same `awaiting_choice` overlay, parked on a record of the STEP rather than on a snapshot |
| **Two draw replacements are applied in a fixed order** (`_replace_draw`): one-shots first, then statics in battlefield timestamp order. CR 616.1 gives the AFFECTED PLAYER the choice | A choice when more than one applies. No pair in the 1997 pool can be on the table at once and disagree, so this is invisible today |
| ~~A static ability cannot outlive its source, and nothing runs at the INSTANT a permanent leaves~~ **DONE 2026-09-02** — `CardData.as_it_leaves` is the twin of `as_it_enters`: `MtgGame._run_leave_hook` calls it from all four battlefield exits (graveyard, exile, hand, ante) after the leave-triggers are on the stack and after `forget_instance`, but BEFORE `recalculate()`, and hands it the parting memory snapshot. A trigger cannot do this work — it resolves after the world has been recomputed without the departing permanent. `ContinuousEffects.add_floating_static` is what the hook registers: the same `StaticAbility`, run in the same five sub-passes of `recalculate` in the same layer order, with only the source's presence lifted (CR 611.3a — such an effect is NOT locked in). Lifted Titania's Song's rider and made Oubliette's *"until this enchantment leaves the battlefield"* the duration it is printed as rather than a trigger. Pinned by `tests/unit/test_leave_hook.gd` | — |
| ~~Departure events carry no CAUSE (`_move_to_graveyard`)~~ **DONE 2026-09-01** — `sacrificed` rides on both the LEAVES_BATTLEFIELD and the DIES payload, set by `sacrifice_permanent` and by nothing else, which lifted Urza's Miter's *"if it wasn't sacrificed"* | — |
| ~~Nothing can ban a permanent from ENTERING the battlefield~~ **DONE 2026-09-02** — `MtgGame.entry_refused` is asked at the top of `_put_on_battlefield`, which now returns bool. Two sources, both CR 614.1c-shaped prohibitions: `CardData.enters_ban_rule`, radiated the way Kismet's `enters_tapped_rule` is (Worms of the Earth's second line), and `CardData.entry_condition`, a card's veto on its OWN arrival (Frankenstein's Monster's *"instead of onto the battlefield"*). A refused object stays in the zone it came from — back into the library for a search, in the hand for a land drop that `play_land` then refuses in words — a permanent SPELL goes to its owner's graveyard and a TOKEN ceases to exist (CR 111.7). Six callers with post-work read the bool. Pinned by `tests/unit/test_entry_ban.gd` | — |
| ~~No event is dispatched when an ability is ACTIVATED~~ **DONE 2026-09-01** — `Mtg.EventType.ABILITY_ACTIVATED`, dispatched from `activate_ability` (after the append, so the trigger sits above the ability, CR 603.3b) and from `tap_for_mana` (CR 605.1a — a mana ability is an activated one). Data: `{instance, controller, player, ability, index, taps}`. Unlocked Artifact Possession and lifted the Powerleech / Haunting Wind ledger row. | The mana-ability dispatch is gated on `MtgGame.has_trigger_listener` — that path runs for every land, every turn — so the `event_occurred` signal does not carry unheard mana activations |
| ~~Damage bookkeeping records source IDS, not amounts~~ **DONE 2026-09-01** — `MtgGame.damage_dealt_this_turn` is a per-source running total, cleared at cleanup (Backdraft). `CardInstance.damaged_by_this_turn` still carries the id list every dies-trigger reads, and `CardInstance.damage_from_this_turn` (added 2026-09-01) is the per-VICTIM half — source id -> what that source dealt to THIS permanent — snapshotted into the DIES event as `damaged_by_amounts`, which lifted Blazing Effigy's own ledger row (pinned by `tests/cards/test_fidelity_2026_09.gd`) | — |
| Delayed effects are turn-based actions, not stacked delayed triggers (`_end_step_doom`, `_end_of_combat_actions`, `_end_step_tokens`) — **narrowed 2026-09-02**: `MtgGame.delayed_triggers` is a real delayed-trigger queue (CR 603.7): `schedule_delayed_trigger(trig, controller, source, repeats, memory, desc)` files an entry that `dispatch_event` fires per seat in APNAP order after that seat's battlefield triggers, as a TRIGGER stack item that outlives its source (once-only entries leave the queue as they go on the stack, CR 603.7c; repeating ones stay until `retire_delayed_trigger`); `current_delayed()` hands the resolving effect its live entry (journaled memory, so a rewind restores it), and an entry may carry a `settle_cost`/`settle_by` the named player pays off any time they have priority (`settle_delayed_trigger`, `settleable_delayed_triggers` for a UI). Lifted Hazezon Tamar (exiled or bounced in response still pays out; a stolen Hazezon pays the caster), Nafs Asp (the debt outlives the Asp, one per bite, payable early) and Cyclopean Tomb (the mired lands stay Swamps after it dies and revert one per upkeep, the controller's choice, until spent). Pinned by tests/unit/test_delayed_triggers.gd and tests/cards/test_fidelity_2026_09_02_delayed_triggers.gd. The end-step/end-of-combat pools listed on the left are still turn-based actions | Move the end-step pools onto the queue so they can be responded to (CR 603.7a) |
| Triggers that fire while a cost is being paid go on the stack BELOW the object being cast/activated (`activate_ability`, `cast_spell`) | Collect them and stack them when a player would next receive priority (CR 603.3b) |
| An until-end-of-turn LOSS beats a later grant (`ContinuousEffects._losses`) | Timestamps within CR 613 layer 6 |
| ~~`ContinuousEffects` durations are end-of-turn and end-of-combat only~~ **DONE 2026-09-01** — every floating entry now carries a `lasts` (`ContinuousEffects.Duration`), so the pipeline knows four: end of turn, end of combat, **until your next upkeep** (`expire_upkeep_of`, called as the upkeep step opens and before its triggers stack — Xenic Poltergeist, Erhnam Djinn) and **indefinite** (Brine Hag). `add_granted_activated_ability` is the same idea for a granted ABILITY, which CR 611.2b makes durationless by default (Life Matrix). Pinned by `tests/unit/test_effect_durations.gd` | — |
| The CR 613 layer passes have no DEPENDENCY analysis (CR 613.8); layer-4 statics run twice when two share the board, which resolves one level | Real dependency ordering |
| ~~No POTENTIAL-mana query~~ **HALF-LIFTED 2026-09-03** — `MtgGame.could_afford(pid, data, excluded)` walks the untapped sources through the shared [ManaPlanner] and prices them with `can_afford`'s own modifiers, restricted-mana keys and `spell_payment` arithmetic, so a plan and a payment cannot disagree. The **castable highlight** now uses it, which is what makes the yellow name mean what `Duel.hlp` says it means (*"you must have enough mana available"*, topic **Hands**) and what the click-then-tap flow and the auto-cast both promise. **STILL OWED:** `DuelScreen._has_affordable_fast_effect` — the Done order's third condition — is deliberately left on the FLOATING pool, so Done and the opponent's-turn auto-pass stop only for a fast effect the player has actually floated for; its own `SIMPLIFIED` marker still says so. Moving it to `could_afford` would make both stop at every phase you hold an instant, which is the clicking the 2026-09-03 playtest was about | Point `_has_affordable_fast_effect` at `could_afford` when (and only when) the player asks for the stricter 1997 Done |
| **SIMPLIFIED — `could_afford` under-reports for two cards** (`mtg_game.gd`): colour SUBSTITUTIONS (Sunglasses of Urza) and North Star's any-type charge widen only the FLOATING half of the answer, because `can_afford` is asked first and [ManaPlanner] models neither. It never over-reports, which is the safe direction for a highlight and for an auto-tapper | Teach the planner substitutions and the wildcard, or price the potential pool through `ManaPool.can_pay` once it can take a source list |
| **SIMPLIFIED — the AI's combat maths blocks ONE creature per attacker in the FORWARD combat** (`ai_player.gd`'s `_attack_risk` / `_cohort_value` / `_damage_through_blocks`, and ply 2 of `ai/combat_search.gd`): when the AI prices its own attack, the defender's answer still puts at most one body on each attacker. **NARROWED 2026-09-05** — the DEFENSIVE half is lifted: `CombatSearch.resolve_block` puts one attacker against a whole gang (CR 509.2's damage order as `AiPlayer.order_blockers` announces it, 510.1c lethal-first down it, 702.19b trample spill, 510.4 first strike decided per assignment), and ply 4 of the crack-back search enumerates gangs, so the AI knows two bodies can hold a counter-swing one cannot. Pinned by `tests/ai/test_ai_gang_blocks_2026_09_05.gd`, including that a gang of ONE answers exactly what `_dies_to` answers. The forward half was BUILT AND MEASURED TOO and left out on the numbers: it changed 19.0% of searched declarations against the defensive half's 15.1%, but 120 of those the narrow way against 92 the wide way (the defensive half is 134 wide against 47 narrow), which is the pessimism the 2026-09-04 attack audit had just removed. Both arms measured +0.1 ± 2.0 on the win rate, so direction decided it. The 4.5% that kept the whole row until now stands: the defender gang-blocks in 46 of 1,022 logged combats | Price the same widening in `_cohort_value` and `_damage_through_blocks` — but not before the pessimism it adds is worth something a measurement can see, and not without `_cohort_value` and ply 2 moving together (they price the same board and would otherwise disagree) |
Card-level simplifications are tracked separately in
**docs/simplified-cards.md** — one row per card that deviates from its
printed behavior, so future passes can lift them one by one.

### The greedy prevention pool, re-weighed (2026-09-02)

**What was recorded on 2026-09-01 is not the obstacle.** That entry said
the `%d of %d` click loop would be "a second hold-open (`awaiting_*` + a
`DecisionAgent` gate + a UI mode) the size of §1.4's damage division". It
would not: §6.14 built a fully GENERIC divided click loop
(`EffectBase.divided_among` + the duel screen's `_divided_prompt`, which
already spells `Select (1st of 4) …` for Pyrotechnics) and §6.8 made a
damage packet a first-class clickable target
(`TargetSpec.Kind.DAMAGE` + `DamageMarker`). Those two compose: a
"prevent 3 damage divided among damage packets" slot needs no new
hold-open, no new agent gate and no new UI mode, and the AI already
answers divided slots. The old row was describing the CURRENT
implementation rather than what a fix would cost.

**THE REAL OBSTACLE is that the pool and the division are two different
cards.** Our Healing Salve is the modern one — *"Prevent the next 3 damage
that would be dealt to any target this turn"* — a shield that outlives its
resolution and answers damage that has not happened yet, castable in a
main phase with nothing on the table. The 1997 prompt is the other card:
pick a player, then deal three points out over damage ALREADY WAITING,
which is a divided target over `Kind.DAMAGE` and nothing else. A card
cannot be both, and a card cannot be one under `--rules fifth` and the
other under modern rules, because a `TargetSpec` is built ONCE per
`CardData` and shared by every copy in every game (`target.gd` says so
itself about `damage_filter`). Making a card's target slots depend on the
game they are being cast in is a change to `CardData`/`TargetPlan` that
reaches every card in the pool — an order of magnitude more than the click
loop it would enable, and for one card's worth of fidelity.

**AND THE DEVIATION IS NARROWER THAN THE ROW LOOKS.** A prevention pool
belongs to ONE victim — `MtgPlayer.damage_prevention` or
`CardInstance.prevention` — so every packet it can be spent on is aimed at
that same victim. Life and marked damage are fungible, so WHICH packet the
points come off changes nothing observable unless a packet is
individually distinguishable, which happens in exactly two ways: a
`DamagePacket.after_landing` rider ("you gain life equal to the damage
dealt this way" — **Drain Life is the only card in the pool that has
one**), and a trigger that reads how much one DAMAGE_DEALT event carried.
Everywhere else, greedy and hand-spread give the same board and the same
life totals.

**The obvious cheap improvement is not cheap either.** "Spend the pool on
rider-carrying packets first" is strictly better for the pool's owner in
the only case where the order is observable — but the pool is drawn down
inside `_land_damage_impl`, which sees one packet at a time, and
`damage_pending` has already been emptied by `_land_pending_damage`
before the first packet lands. Implementing it means REORDERING THE
LANDING LOOP, which reorders every `DAMAGE_DEALT` event in every combat
and so can move any trigger that listens for one. That is a wide blast
radius for one card, and it was measured against: the Deck Lab default
(`--matrix decks --games 6 --seed 4242`) is byte-identical today and this
would be the change most likely to move it. Left alone deliberately.

The mid-resolution `choice request` interface is `DecisionAgent`
(synchronous defaults) + `HumanAgent` (the mailbox) + TWO holds, both of
which raise `awaiting_choice` for the DuelScreen's one generic overlay and
both of which are answered by `answer_choice`:
- the PRE-FLIGHT, for a question asked inside a resolution — `_resolve_top`
  runs the item once over a `GameSnapshot`, keeps the question, rewinds, and
  holds the resolution open;
- the COST HOLD, for a question asked while a cost is assembled (CR 601.2h) —
  `_hold_cost_choice` parks a record of the ACTION in
  `MtgGame._pending_action` and `answer_choice` re-issues it. No snapshot:
  the question is put where no refusal is left and nothing has been mutated.

The await-based upgrade was CONSIDERED and rejected — a GDScript coroutine
does not propagate through `Callable.call()`, so it would make the whole
engine async (reasoning in docs/duel-todo.md §1.3, thirty-ninth pass of
docs/duel-screen-design.md).

## M2 — Duel screen (v1 SHIPPED 2026-08-30)

Playable hotseat duel: battlefield/hand/stack rendering, click-to-act
through the engine's public API, target picker, X dialog, ability menus,
combat declaration modes, game log, fast-forward, keyboard shortcuts.
Full design record (platforms incl. Raspberry Pi via the Compatibility
renderer, faithful-graphics strategy, QoL wishlist): docs/duel-screen-design.md.
Remaining M2.x: auto-tap mana (`auto-cast` / `Don't Auto Tap`, blocked
behind @MENU_MANAPOOL's per-mana spends — docs/duel-todo.md §9.8),
hover zoom, gamepad focus ring. **Phase-stop options landed** with
duel-todo §6.1/§6.3 (`game/duel/phase_stops.gd`), and the
original-assets import pipeline and card-art fetching are shipped
(`tools/import_original.py`, `tools/fetch_card_art.py`) — the line
listed all three as outstanding until 2026-09-01.

## M3 — Card pool to Shandalar parity (POOL COMPLETE 2026-09-01)

The pool is defined and downloaded: base game (2ed Unlimited, 4ed, Arabian
Nights, Antiquities, Astral, HarperPrism promos) + the **Duels of the
Planeswalkers** expansion (Legends, The Dark), plus the **six promotional
cards** the 1997 game shipped = **897 unique cards** after dedupe AND after
dropping the four physically unimplementable ones (Chaos Orb, Falling Star,
Shahrazad, Word of Command — same exclusions as s30, and none of the four is
in `cards/data/` at all). 897 is therefore the finished number, not a target
with four still to subtract.

**The target moved from 896 to 897 on 2026-09-01**, and it moved because the
pool DEFINITION was one card short, not because anything was recounted. The
definition is eight Scryfall sets, and `phpr` — "HarperPrism Book Promos",
complete at five: Arena, Sewers of Estark, Windseeker Centaur, Giant Badger,
Mana Crypt — was standing in for "the promos". The 1997 game had a SIXTH
promo, **Nalathni Dragon**, which is not a book promo at all: it was handed
out at DragonCon 1994 and Scryfall files it under `pdrc`, so fetching whole
sets could never have produced it. `Duel.hlp` — Tier 1, the game's own
shipped help — carries its card entry verbatim, which is what settles that
it belongs. `tools/fetch_cards.py` now has an `EXTRA_PRINTINGS` hook that
fetches a named card from another Scryfall set and files it under one of
ours, so the printed text is still fetched rather than recalled.

Two things were checked while fixing it, and both are worth keeping:
`shandalar-src/Program/Cards.dat` and `Program/Magic.exe` also name Nalathni
Dragon, but BOTH are Manalink-updated (they contain Necropotence and
Lhurgoyf, which the 1997 game never had) and cannot settle a pool question —
only `Duel.hlp` and the printed manual can. And diffing every card ENTRY in
`Duel.hlp` against the pool turned up exactly one name we did not have, so
the promo bucket is now complete and the base pool has no other hole.

Current state: **897 implemented** (821 hand-written across waves 1-74 +
76 generator-auto) and **cards/todo/ IS EMPTY** — every stub has graduated,
and `tests/cards/test_pool_wave73.gd` pins that it stays empty. The only
cards the pool does not contain are the four excluded on physical grounds
above.

Still owed under M3, now that the cards are done: deck validation (4-copy
rule, restricted list, Tome duplicate-limit modifier) and card-image
downloading for the UI (port s30's utils/download_card_images.py, Scryfall
border crops, images stay out of the repo).

### What the stubs were waiting on (the record, closed 2026-09-01)

EVERY CLUSTER IN THIS TABLE IS CLEARED — waves 43-73 built each missing
system (with its own tests in `tests/unit/`) and then graduated the cards it
unblocked. The table is kept as the record of what each wave was for:

| Missing system | Cards blocked |
|---|---|
| ~~Multi/divided targeting~~ (landed wave 43) | cluster cleared |
| ~~Copying~~ (landed wave 47) | cluster cleared |
| ~~Ante~~ (landed wave 46) | cluster cleared except Ring of Ma'rûf, which waits on the outside-the-game zone instead |
| ~~Poison counters~~ (landed wave 48) | cluster cleared |
| ~~Text-changing effects~~ (landed wave 49) | cluster cleared |
| ~~Combat re-arrangement~~ (landed wave 50) | cluster cleared; one blocker on TWO attackers is still owed |
| ~~"Blocked by that Wall this turn" history~~ (landed wave 48) | the whole Glyph cycle graduated |
| ~~Phasing~~ (landed wave 51) | cluster cleared |
| ~~A game-DRAW result~~ (landed wave 51) | cluster cleared |
| ~~Face-down / outside-the-game zones~~ (landed wave 51) | cluster cleared |
| ~~Restricted mana~~ (landed wave 49) | cluster cleared |
| ~~A random-effect subsystem~~ (landed wave 45) | the whole Astral set graduated |

The stubs that remain are ALL one-off multi-part cards — each needs its
own design pass, none needs a shared system. Waves 52-57 worked through the
first 60 of them (Lich, Stasis, Time Vault, Gaea's Liege, Cyclopean Tomb,
Tawnos's Coffin, Transmute Artifact, Golgothian Sylex, City in a Bottle,
Frankenstein's Monster, Voodoo Doll, Sword of the Ages, Triassic Egg,
Rasputin Dreamweaver, Hazezon Tamar, Halfdane, Takklemaggot, Imprison, and
the Unlimited / Fourth Edition / Arabian Nights / Antiquities / Legends
remainders). What is left, by the shape of the work each one wants:

- ~~**Damage-replacement one-offs** — Forcefield, Eye for an Eye, Dark
  Sphere, Blood of the Martyr, Nova Pentacle, Shimian Night Stalker,
  Personal Incarnation, Rock Hydra, Silhouette, Reverberation~~
  **CLEARED, wave 73** — and the note above was half right. They ARE all
  variations on "the next damage from a chosen source is changed", but the
  four shapes the engine had did not cover them, because none of those
  four is a REPLACEMENT: prevention pools and predicate shields prevent,
  and the two redirections are hard-wired to one victim. What they wanted
  was one list — `MtgPlayer.damage_replacements` — applied before every
  prevention gate (CR 616), with a handler that says either "carry on with
  what is left" or "the event ends here". Five of the ten are three-line
  handlers on it; the other five wanted their own small pieces
  (`may_take_creature_damage`, `damage_eats_counters`,
  `damage_all_redirect_to`, a floating damage immunity, and
  `ActivatedAbility.owner_only`).
- ~~**Draw-step replacements** — Sylvan Library, Aladdin's Lamp, Island
  Sanctuary, Chains of Mephistopheles~~ **CLEARED, wave 66.** The hook was
  genuinely missing and is now built (CR 614, above). One correction: Sylvan
  Library is not a replacement — it is a draw-step trigger that wanted
  `MtgPlayer.drawn_this_turn`. Fasting, filed under "the rest", belonged
  here and graduated with them on the draw-STEP replacement.
- ~~**Choice-heavy politics** — Balance, Eureka, Juxtapose, Gauntlets of
  Chaos, Nebuchadnezzar, Petra Sphinx, Season of the Witch, Cleansing~~
  **CLEARED, wave 65.** This entry was wrong when it was written: the
  "missing await-based human prompt" it blamed had already landed in §1.3,
  and every one of these cards is expressible through the ordinary
  `DecisionAgent` funnel. What they actually wanted was two small engine
  pieces — `MtgGame.exchange_control` (CR 701.10) and
  `MtgGame.current_targets()` — and one design pass each.
- ~~**The rest** — single cards with their own bookkeeping~~ **CLEARED,
  waves 67-72.** Thirty-nine cards, and the shared engine pieces each one
  paid for are listed under "Mechanics landed in waves 67-72" above. Two
  entries in this bullet had already graduated when it was written.


Set-pack policy for the future: new sets go in new folders and MUST NOT
change original-game balance (see docs/adding-cards.md, "Future card packs").

## M4 — AI opponent (phase 1 SHIPPED 2026-08-30)

Shipped: greedy-heuristic AiPlayer (engine/ai/) driving a seat through the
public API — value-ranked casting with mana-tap planning, intent-classified
targeting, favorable-trade attack analysis with lethal-push override,
kill/absorb/trade/gang/chump block logic, DecisionAgent answers (tutors,
discards, Paralyze ransoms) — plus AiProfile difficulty presets under the
ORIGINAL's names (Apprentice/Magician/Sorcerer/Wizard), where difficulty =
seeded mistake injection + aggression tilt, exactly the original's scaling
model. AI-vs-AI soaks run in CI as the engine's broadest regression net;
seeded games replay line-for-line.

Phase 2 (SHIPPED 2026-08-30): instant-speed responses through a guarded
response framework (never responds over its own stack object) — counters
big threats past a per-profile threshold (counter-wars judged by the
contested prize), Fogs real damage once blocks are known, aims instant
removal down the attacker list by value, Giant-Growth tricks on both
sides of a block, firebreathes unblocked attackers, holds {U}{U} open
over marginal casts, declares attack bands, and times Nevinyrral's Disk
by board deficit. The Apprentice profile keeps holds_instants=false —
phase-1 "my turn only" Magic IS the bottom difficulty's feel.
Phase 2.x: SIDEBOARDING SHIPPED 2026-09-02 (see below). Still open —
activation breadth (Icy locks, Royal Assassin holds), trick ANTICIPATION
on the opponent's side, eval-weight tuning per profile, deck-aware
mulligan when mulligans land.
Phase 3 (research): game cloning + full-turn minimax with transposition
tables — mage-go's `interactive/ai/search/` is the working reference; it
plugs in behind the same act() surface. **A design note is below** (M4
phase 3): NOT started, and the note exists because the first thing phase 3
needs is a measurement, not a search.

**The first search LANDED 2026-09-05** — `engine/ai/combat_search.gd`,
an alpha-beta minimax over the crack-back, kept on a −26% fall in the
deaths it exists to prevent. It runs over a MODEL rather than over the
engine, and the reason is the journal's own boundary: see "The
tap-trigger refusal, and the crack-back search (2026-09-05)" above.

### Phase 2.x — AI SIDEBOARDING (SHIPPED 2026-09-02)

**BUILT to the design below, which is kept because it is the reasoning.**
Two new engine files: `engine/ai/ai_match_memory.gd` (what one seat SAW —
the opponent's casts, land drops and battlefield arrivals, tokens
excluded, copies kept at the per-duel MAXIMUM rather than summed, plus
damage taken per COLOUR) and `engine/ai/ai_sideboard.gd` (the swap).
`AiProfile.sideboard_swaps` carries the difficulty (Apprentice 0,
Magician 2, Sorcerer 3, Wizard 4) and `mistake_chance` fumbles individual
swaps, so there is no second difficulty concept. `game/match_screen.gd`
sideboards its AI seats the moment a duel is recorded — no window, because
an AI seat has no use for one — and `DeckLab/simulate.gd` grew `--best-of`
and `--sideboard`, where one unit of work is now a MATCH.

**The three invariants each have a test** (`tests/ai/test_ai_sideboard.gd`,
23 tests): deck size unchanged, the copy limit counted across BOTH piles,
and the format still legal. The second and third hold structurally — a
one-for-one swap between two piles leaves their union alone, and legality
is a function of that union — and are re-checked against `DeckFormat`
anyway.

**THE EXPERIMENT THE DESIGN NAMED, RUN 2026-09-02.** `--matrix decks/
--games 60 --seed 4242 --best-of 3`, `--sideboard on` against `off`, 600
matches a side. **The delta is emphatically not zero**, so the answer is
that the sideboards are real and the heuristic finds them — not that our
sideboards are the problem. Overall match win rate across the matrix:
Black-Red Raiders **+13.2** (49.0% → 62.2%), Mountain Artillery **+7.0**,
White Knights ±0.0, Big Green **−7.9**, Blue Skies **−13.1** (83.8% →
70.6%). Both sides board, so a delta measures whose sideboard is better;
the largest single move is Black-Red Raiders vs Blue Skies, **18.3% →
53.3%**, which is four Red Elemental Blasts against a mono-blue deck.
Blue Skies, the best deck in the field, is the deck sideboarding costs
most — what happens to the best deck when everyone else gets answers to
it. Determinism holds: identical output across runs and across `--jobs`.
Full table in `DeckLab/README.md`.

**What was deliberately NOT built.** "Score every main-deck card for how
little it DID" is answered as "how little it can do in THIS matchup",
because a card that never left the library did nothing and that is not the
card's fault; per-card performance is mostly noise at one duel's sample
size. Recorded here rather than silently substituted.

#### The design, as written before it was built


**The gap, stated plainly.** `game/match_screen.gd:29` says it outright:
the between-duels sideboard step is offered to human seats only, because
the AI has no sideboarding heuristic. Everything around it is already
built — `DeckList` parses and round-trips `SB:`, `DuelConfig.sideboards`
carries both piles, `MatchState.sideboard_between_duels` is the original's
`Side&board between duels` checkbox, and `match_screen.gd` has a working
Sideboard window that moves cards both ways and validates the result. The
only missing piece is the seat that cannot use it.

**Why it blocks two things.** A `Sideboard between duels` match against an
AI opponent is currently a match in which only one side adapts, which is
worse than not offering the step at all. And the Deck Lab is AI vs AI, so
`--sideboard on|off` there would change nothing whatever — which is why
that flag and `--best-of` are still absent from the CLI (DeckLab/README.md).
Both land the moment this does.

**What the AI actually knows.** Not the opponent's decklist — knowing it
would be cheating, and the original does not cheat here. It knows what it
SAW: every card the opponent cast, played or revealed in the duels
already played. That is the real sideboarding signal in paper Magic and it
is the one to use. `MtgGame.log_lines` and the zone histories are the
existing sources; if what is needed is not recoverable from them, add a
per-duel `cards_seen` set to `MatchState` rather than reaching into the
opponent's library.

**The heuristic, in the shape the rest of engine/ai/ already uses.**
Score every sideboard card against what was seen (artifact removal scores
on the count of artifacts seen, a Circle of Protection on damage taken
from one colour, graveyard hate on recursion seen, and so on); score every
main-deck card for how little it did; swap the best N in for the worst N,
strictly one for one so deck size cannot move. Three invariants the swap
must not break, and each is a test: **deck size unchanged**, **the copy
limit counted ACROSS BOTH piles** (four in the deck plus one in the board
is five copies and illegal), and **the format still legal** if one was
required — a match that starts Type 1.5 must not become illegal at duel 2.

**Difficulty is the existing model, not a new one.** `AiProfile` scales by
seeded mistake injection and aggression tilt; sideboarding scales the same
way. Apprentice does not sideboard at all (phase-1 "my turn only" Magic is
that profile's whole feel); the stronger profiles swap more cards and
score them more accurately. No new difficulty concept.

**Determinism is not negotiable.** The choice must be a pure function of
(what was seen, the two piles, `game.rng`) so a seeded match replays
line-for-line, which is what the Deck Lab's whole determinism check rests
on.

**The honest caveat to record before building it.** Sideboarding is only
as good as the sideboards, and ours are 15 cards the pre-duel pass wrote
so that the between-duels step would have something to swap. Whether they
contain real answers to the field is unmeasured. Build the heuristic, then
measure it: `--best-of 3 --sideboard on` against `--sideboard off` over
the same seed is the experiment, and if the delta is zero the sideboards
are the problem, not the heuristic.

### Phase 3 — SEARCH: a design note, not a start (2026-09-02)

Written after AI sideboarding landed, in the style of §6.8a: what the
engine already gives a search, what it does not, and the ONE measurement
that decides the shape. **Nothing here is built and nothing here should be
built before that measurement exists.**

**THE CLONING PRIMITIVE ALREADY EXISTS, and it is not quite the right
shape.** `GameSnapshot` (engine/game_snapshot.gd) reads every mutable
object's script variables out and writes them back onto THE SAME objects,
so held references survive; `rng.state` goes with it (rule 7), and
`MtgGame._probing` already silences the log, the events and the state
signals for the duration. The §1.3 pre-flight runs a whole resolution over
one and rewinds it, and `tests/unit/test_snapshot_audit.gd` pins that a
probed duel is the same duel. But its own doc states the limit that
matters here: *"It is a REWIND, not a fork: only one snapshot may be live
at a time"*, and `restore` is one shot. A depth-first search wants a TRAIL
of them.

**AND THE COST SAYS A SNAPSHOT PER NODE CANNOT BE THE ANSWER.** Measured
2026-09-01 (`tools/bench_probe.gd`, Godot 4.7.2 headless): ~23 microseconds
per captured object, ~3 ms for take + resolve + rewind on a 129-object
early board, under 20 ms on a 439-object one. A one-second think would
therefore afford roughly **300 nodes** on an early board and **50** on a
late one. A single main phase with six castable cards, their targets and
their tap plans is already thousands of positions. Snapshot-per-node is
two orders of magnitude short, and that is not a tuning problem.

**WHICH IS WHY THE ARCHITECTURE'S OWN RULE IS THE OPENING.** CONTRIBUTING.md
rule 2 — *every* state mutation goes through an `MtgGame` helper — means
an UNDO LOG can be instrumented at ONE surface: record the inverse of each
helper call while a search move is applied, replay it backwards to unmake
the move. Nothing else in this engine would need to know. That is the
single largest thing this codebase gives a search that a typical engine
does not, and it is the reason phase 3 is plausible at all in GDScript.
**The measurement that decides everything: the per-node cost of
make/unmake through an undo log against the ~3 ms of a snapshot.** If it
is not at least an order of magnitude cheaper, phase 3 stays research.

**Move generation is mostly there and is not the hard part.** Action
methods return `""` or a refusal rather than throwing, so generate-and-test
needs no second legality model; `TargetSpec.legal_targets` enumerates
targets; `AiPlayer._mana_sources` / `_plan_taps` enumerate payments. What
is missing is the MOVE as an object — (card, mode, X, target tuple, tap
plan) — and a canonical ordering for it, because the transposition table
keys on positions and two different tap plans for the same cast are the
same position. Targets dominate the branching factor and will need
pruning by `Evaluator` value long before depth does.

**Hidden information is a fairness rule here, not a modelling
convenience.** A search must not read the opponent's hand or library, for
exactly the reason `AiMatchMemory` exists: the original does not cheat and
neither may we. Two honest shapes, and the choice is a design decision
nobody has made yet: search only OUR turn to a horizon with the opponent
modelled as passing (cheap, and wrong about instants), or DETERMINIZE the
opponent's hand from what has actually been seen — for which the memory
built for sideboarding is already the right record and already
per-opponent. The second is more work and is the one that would let the
search anticipate a trick, which is phase 2.x's open item too.

**The leaf is `Evaluator.position_score`, and a search will find its
holes.** Four linear terms (life, board, hand size, lands) is enough for a
one-ply heuristic and will not be enough at depth: it cannot see that a
card in hand is castable this turn, or that a 2/2 flyer is worth more than
a 3/3 ground creature against a board of ground creatures. Expect to tune
it against self-play, and expect the tuning to be the long pole.

**The plug-in point is unchanged**: a `SearchPlayer` behind the same
`act()` surface, falling back to the phase-1/2 heuristic whenever the
budget runs out — which also makes it shippable before it is good, and
lets `AiProfile` carry the depth the way it carries every other knob.

#### THE MEASUREMENT, RUN 2026-09-02 — and the note above was wrong twice

The note says the first thing phase 3 needs is a measurement, not a
search. This is that measurement. `tools/bench_undo.gd` (Godot 4.7.2
headless, eight sections, each answering one question) decomposes the
~3 ms and prices the alternative. **Everything below was timed on a
machine several agents were sharing; the RATIOS are the robust reading
and the absolute microseconds move 10-20% between runs.**

**1. THE 3 ms IS THE SNAPSHOT, NOT THE GAME — 96% of it.** On the
127-object early board the note quotes, `take` + `restore` is **3.44 ms**
while the move it wraps — cast a creature, resolve it, run state-based
actions — is **139 us**. The CR 613 continuous pipeline is **18 us** and
`check_state_based_actions()` is **2 us**. Inside the rewind, the
reflective `Object.get`/`set` loops are 56% of it (0.88 ms reading,
1.07 ms writing) and the graph walk plus container duplication is the
other 44%. The cost is in the WHOLE-GAME SHAPE, not in any one operation:
127 objects x 93 CardInstance properties is **12,023 property reads per
node**, and CardInstance is 98% of them. Nothing here is a tuning
problem, and nothing here is the engine being slow.

**2. A MOVE CHANGES 1-4 OBJECTS AND 2-10 FIELDS, FLAT IN BOARD SIZE.**
Measured by diffing a full snapshot across each move: casting a creature
moves 10 fields, playing a land 8, tapping a land 2, declaring one
attacker 7 — and the counts are IDENTICAL at 10 permanents and at 40.
That is the whole case for a journal: the snapshot's linearity in the
BOARD is the bug, because a move is not linear in the board.

**3. THE JOURNAL DELIVERS 21x AND THE FLOOR IS NOW THE ENGINE.**
`engine/undo_log.gd` plus `MtgGame.make_mark()` / `unmake_to()` SHIPPED
2026-09-02. Per node, same workload (cast a creature and resolve it):

| permanents | snapshot node | journal node | speed-up | nodes/s |
| --- | --- | --- | --- | --- |
| 10 | 3.51 ms | 0.16 ms | 21.4x | 6,100 |
| 20 | 3.91 ms | 0.26 ms | 15.3x | 3,900 |
| 40 | 4.65 ms | 0.49 ms | 9.5x | 2,100 |
| 80 | 6.19 ms | 1.15 ms | 5.4x | 870 |

28 records a node at 0.13 us to record and 0.14 us to write back — **6 us
of unmake**. The speed-up FALLS with board size because what is left is
the move itself plus one `recalculate()`, both linear in the board. The
journal has taken the rewind out of the node; there is nothing else of
that size left to remove.

**4. THE SEARCH SPACE IS SMALLER THAN THE NOTE GUESSED.** The note says
"a single main phase with six castable cards, their targets and their tap
plans is already thousands of positions". Measured over **140 real
main-phase decisions across five gauntlet duels** (Black-Red Raiders vs
Blue Skies, `wizard` both seats), counting land drops plus castable cards
times their legal target tuples plus activatable abilities times theirs:
**mean 2.3 moves, median 1, p90 5, max 12**. Combat is wider and still
not thousands — attack subsets mean 2 / max 16, block assignments mean 4
/ max 27 over 42 declarations. Tap plans are excluded deliberately: two
payments for one cast are the same position, which is what a
transposition table is for. Affordability is judged the way `AiPlayer`
judges it (what the untapped sources could pay), not by reading the
floating pool — reading the pool said b=1.2, which is only true of an AI
that has already spent its mana.

**WHAT IT ADDS UP TO.** mage-go budgets 20,000 nodes at depth 10; at
3,900 nodes/s that is five seconds and out of reach. But the typical turn
in THIS pool is tens of nodes, and a 2,000-node budget — half a second on
a 20-permanent board — covers it many times over while truncating the
12^4 tail. **Phase 3 is affordable now and was not before.** The leaf
eval, not the node rate, is the long pole the note predicted it would be.

#### What the journal covers, and the one thing that blocks a first search

BUILT and verified against `GameSnapshot` itself — make a move with the
journal on, unmake it, compare every field the snapshot captures, and any
mutation `MtgGame` fails to record prints by name
(`tests/ai/test_undo_log.gd`, 32 tests; `bench_undo.gd` section F runs
the same differ outside the suite). Covered: `play_land`,
`tap_for_mana`, `cast_spell` and its resolution, `draw_cards`,
`adjust_life`, `declare_attackers`, the stack pushes and the priority
round — and, since the 2026-09-02 review found the first list stopped
exactly where a spell RESOLUTION starts, everything a resolution writes:
damage and life, prevention and regeneration shields, counters, every
zone move on the helper surface (`_rec_move`), battlefield departures as
whole objects (`_rec_departure` — `clear_battlefield_state` wipes
forty-odd fields and the differ named every one), the resolving item's
card and targets as whole objects plus the per-turn tables
(`_rec_resolution`, `RESOLUTION_TABLES`, `PLAYER_RESOLUTION_FIELDS` —
which is what covers a card script writing `inst.memory[...]` or
`player.life_for_mana` directly), tokens, spell copies, control and
ownership changes, face-down, keywords granted for good, and the fifteen
`ContinuousEffects` lists, which record themselves through their own
`journal` pointer. The move menu in the test file is one round trip per
KIND of move a search makes, twenty-one of them, every one drift-free.
The API is a PAIR plus a teardown — `make_mark()` opens a node,
`unmake_to(mark)` closes it, `end_search()` hands the game back — and the
teardown is not optional: `unmake_to` empties the journal but leaves it
allocated, so a duel that searched once and never ended the search would
record every later mutation into a log nobody reads. A search node also
runs as a PROBE (`_probing`), which is the flag that already means
"silent log, no signals, no held resolutions", so no second concept was
invented for it.

**NOT covered, and it bounds a first search to a single step**: the TURN
MACHINERY. `_advance_step` / `_enter_step` — the untap sweep, upkeep,
the draw step, cleanup and the continuous-effect expiries — journal
nothing (mana burn's life write is the one exception, recorded since
2026-09-02 so that `adjust_life` and it agree), so a search must not
cross a step boundary until they do. That is the next increment, and it
is what a search would need to see combat from a main phase. The second
documented boundary, from `engine/undo_log.gd`'s "WHAT IS COVERED" block:
a card script that writes onto a THIRD object during resolution — not
its own card, not a target, not a player, not a table in the two lists —
is outside the journal. Nothing in the pool does that today (the move
menu would have named the field); a card that starts to gets its own
`_rec` or a row in `RESOLUTION_TABLES`.

**And that boundary is what shaped the first search that landed.** The
crack-back search of 2026-09-05 crosses two step boundaries and a turn
boundary by construction, so it could not use the journal at all; it
runs over a flat model built out of the engine's own predicates
instead. Instrumenting `_advance_step` / `_enter_step` is therefore not
an optimisation — it is the thing that decides whether the NEXT search
can make its moves through the same helpers a duel makes them through.

DERIVED STATE IS REBUILT, NOT JOURNALED, and that is the simplification
that made the instrumentation small: `cur_*` (37 of CardInstance's 93
fields), the player-level flags statics write (`max_hand_size`,
`combat_damage_redirect`, ...) and the battlefield index caches all come
back from `recalculate()`, which costs 18 us on an early board. The 97
card scripts that write those fields needed no instrumentation at all.

**COST WHEN OFF: NOTHING MEASURABLE, and measured against a control.**
The journal is null by default and every site is an inline
`if undo_log != null`. `--matrix decks --games 6 --seed 4242 --no-elo` is
**byte-identical** against a de-instrumented control build of
`mtg_game.gd`. Throughput over six INTERLEAVED 300-game matrix runs
(alternating builds, so the machine is priced rather than the change):
instrumented 31.8 s mean, control 32.8 s mean — the instrumented build is
nominally 3% FASTER, which is to say the difference is below a noise
floor of about +/-11% on a box under load average 19.

## M5 — Adventure mode

The Shandalar overworld: map, cities/card shops, wisemen/quests, enemies,
dungeons, castles, world magics, amulets/mana links, ante economy. Design
source of truth: `../docs/SHANDALAR_LORE.md` (systems tables) + s30's
adventure code + the original's data files in `../shandalar-src/`. This
milestone gets its own design doc before code.

## The Gauntlet — the fourth 1997 mode (BUILT 2026-09-02)

`@SHELLSCREEN_DUEL` (`Program/UIStrings.txt:5-11`) gives the original four
duel modes with their own descriptions: `1Solo &Duel` (we have it),
`2&Gauntlet:Defeat as many opponents in a row as possible.`,
`3&Sealed Deck`, `4Duel &Opponent` (network play — never). **The gauntlet
is the only one of the four that is cheap, and it is the only 1997 mode
this project has never touched.**

**Full design: `docs/gauntlet-design.md`** — the sources in the order they
answer the questions, the mode as a state machine, the four build slices,
and every place the sources run out with the `[QoL]` choice I would make
instead. Written after the first survey of the Tier 2 decompilation, which
answers the mode almost completely (the run loop, the opponent shuffle,
the round counter, the two Match Sizes and the twenty-opponent cap are all
readable in it).

**What it is.** A run of **N matches** against **N different opponent
decks**, shuffled out of the deck folder, entered at a random point and
walked with wraparound. Each opponent is a match of the chosen size (best
of three or best of one). Ante, sideboard-between-duels and the four Enemy
Levels are its parameters. A running `wins/losses/ties` and a round number
are shown after every duel. **Losing a match ends the run.**

**What it is NOT.** No collection, no purse, no unlocks, no persistent
record between runs — checked in every source and none of them is there.
The run is the reward.

**Size: M, four slices, UI only. SHIPPED 2026-09-02** — the mode is on
the title screen, between `Magic Battle` and `Deck Builder`, carrying
`@SHELLSCREEN_DUEL`'s own description as its tooltip.

| Slice | What | Size | State |
|---|---|---|---|
| 1 | `game/duel/gauntlet_state.gd` — order, round, session record, the shuffle, the `@GAUNTLET` strings. Pure, headless, tested | S | **built** |
| 2 | `MatchState`: `LENGTHS = [1, 3, 5]` (§6.21's `Best of &One`), `last_winner`, the `&Free play` `[QoL]` label and the corrected citations | S | **built** |
| 3 | `game/duel/gauntlet_screen.gd` + `gauntlet_options.gd` — a sibling of `MatchScreen` that OWNS `MatchScreen`s, the round window and the Gauntlet Options window. One new signal (`match_finished`) and one flag (`reports_to_owner`) on `MatchScreen` | M | **built** |
| 4 | The main-menu entry | S | **built** |
| 4b | The 1997 finish: the three `@DIALOG_STARTEXP1MATCH_GAUNTLET` next-opponent announcements on a window of their own, `&Create Deck...` on the Gauntlet Options window, and the rest of `@GAUNTLETERRORS`' opponent-deck refusals | S | **built 2026-09-02** |

**Nothing is owed on this mode any more.** The design's own slice 4 is
built and stamped in `docs/gauntlet-design.md` §10, which records what it
proved. Two things from it belong here:

* **The design was wrong about one of the four `@GAUNTLETERRORS`
  opponent-deck messages.** `Opponent's deck %s is invalid. Wrong version
  number.` cannot be produced: **neither deck format this project reads
  carries a version number** — the 55 shipped 1997 `.dck` files open with
  a bare name line and no version field, our `.deck`/`.dec` text has none,
  and the only numbered revision anywhere is Manalink 3's `;%d` header
  (`shandalar-src/src/deck/deckdll.cpp:5522-5545`, Tier 3). The string is
  kept with that obituary on it and a test asserts nothing returns it. The
  other three are wired and end the run in the original's own words.
* **`&Create Deck...` diverges once, marked at the site.** The original
  returned to its startup screen with the parameters still set; ours is a
  scene change to the Deck Builder, which exits to the title. The 1997
  re-enumerate-and-reshuffle rule then holds by construction — the next
  entry re-reads the deck folder and re-shuffles — but the parameters are
  not carried back. Honouring that needs the Deck Builder to know who sent
  it, which is the same missing piece that keeps `MatchScreen`'s
  `&Edit deck...` greyed.

**Why it is worth an M.** We already own the inner two thirds:
`MatchState` (140 lines) is the match and its `wins_needed()` is already
`best_of / 2 + 1`; `MatchScreen` (332 lines) is the match loop with the
between-duels window, the sideboard step, the per-duel seed split and a
headless path. `AiProfile` already ships the four Enemy Levels by name.
`decks/*.deck` already exist with a loader and a format checker. **The
missing piece is the outer loop and two windows.** It also (a) gives a
built deck somewhere to go — today the Deck Builder's only consumer is one
duel; (b) is the first end-to-end exercise of the match code, which has
never run more than one match; (c) is M5's rehearsal, since Shandalar is
the same outer loop plus a map.

**The one decision the design left open — TAKEN, the design's own
recommendation.** The sources describe two different gauntlet
configuration screens (`docs/gauntlet-design.md` §5.1): the shell's page
(`&Num opponents:` + a `&Best of:` **spinner** + a five-band computed
difficulty) and the duel program's own (`Best of Three` / `Best of One`,
four Enemy Levels, a hard cap of 20). **We built the second, plus the
first's `&Num opponents:` and `Side&board between duels`** — the second is
the one the decompilation implements, so every behaviour behind it is
checkable rather than reconstructed, and its Match Size pair is the one
the manual describes in prose (p.156). The five-band
`Gauntlet difficulty: %3d (%s)` readout is on it too, with the original's
format string and band names and a **`[QoL]` formula of ours** (§5.2 — no
source has the original's). Reversing the choice would mean a `&Best of:`
spinner and a shell page; nothing else built here would move.

**Deliberately out of scope:** `&Save gauntlet` / `&Load gauntlet...`.
We have no save/load anywhere — not for a duel, not for a match, not for
Shandalar — and it should land as one design across all three when M5
needs it. The gauntlet logs its seed instead, so a run is reproducible
from a bug report.

**Do not confuse this with the Deck Lab's `--gauntlet`**, which is a
round-robin measurement harness (deck A vs each of a pool, N games per
matchup) and shares nothing with the mode but the word. Both keep their
names.

## Deck Lab (SHIPPED 2026-08-30)

Headless AI-vs-AI deck testing at 10k-game scale: `DeckLab/deck_lab.sh` — duel
and gauntlet modes, Wilson-CI statistics with play/draw splits, JSON/CSV/
SVG output, WorkerThreadPool parallelism with seed-stable determinism at
any thread count. Manual: DeckLab/README.md. Owed next: a stall/bug
auto-report bundle (seed + decks + log on any stalled game), matchup
matrices (every deck vs every deck), and Elo-style gauntlet ladders.

## Deck Builder (SHIPPED 2026-08-31; audited, restyled and audited again)

`@SHELLSCREEN_TOOLS`' own "Build or Modify decks", built from the 1997
manual's ch.10, the Menus.txt / Cuecards.txt string tables and s30's
`edit_deck.go`, then styled to the owner's genuine 1997 screenshot of the
in-Shandalar Deck screen (docs/duel-screen-design.md, thirty-fourth pass,
which records what the screenshot corrected). See `game/deck_builder/` and
its file headers.

### [QoL] shipped in the screenshot pass

Each is marked `[QoL]` at its site and in the mini-menu, per the standing
rule that divergence from 1997 is marked and never silently mixed in.

| addition | the repeated cost it removes |
|---|---|
| three in-memory DECK SLOTS (`Deck1/2/3`, and in the screenshot) | trying a variant meant a save, a load dialog and a name |
| one-step UNDO (`Ctrl+Z`) | a right-click empties a whole column and only a status line said so |
| ADD BASIC LAND (`Ctrl+L`) | seventeen lands was seventeen clicks after a filter to find them |
| the Inventory's already-in-deck badge | "how many have I got?" meant scanning the deck area |
| the type-ahead reading card TEXT | "which cards gain life" could not be asked on this screen at all |
| DECK NOTES | why-these-cards lived outside the game or nowhere |
| EXPORT to `.dec` and `.dck` | a deck could not leave the project |
| the Stats window's colour / type / land graphs and average cost | the 1997 matrix says what is in a deck, never whether it will work |
| `Ctrl+S/O/N/Z/L/E/F` | eight commands were three clicks each through a mini-menu |
| "showing (1-9)" on the count line | the reference's one-row Inventory is 88 pages of the pool |

### Second audit pass (2026-08-31, after the restyle)

The restyle moved every region, so the screen was driven again end to end.
Six defects, each pinned by a test that failed first
(`tests/ui/test_deck_builder.gd`, "SECOND AUDIT PASS"):

| defect | what it did |
|---|---|
| **`@SAVE`'s "Yes" did not save** | `Save deck` can stop to ask `@DECKEXISTS` or for a name. `_confirm_discard` called it, got nothing back and discarded the deck immediately — so answering *"yes, save it"* silently saved nothing, and confirming the overwrite afterwards wrote whatever deck had replaced it. `_save_deck` now takes a continuation and runs it only once the file is written. **Data loss.** |
| **dialogs stacked** | `_open_mini_menu` guarded itself; `Stats`, the Deck Header, `Load deck` and the overwrite prompt did not, so a second click put a second copy on screen |
| **dialogs were not modal** | `OriginalDialog` is a panel and draws no blocker, so a click that missed it reached the cards underneath — with the Stats window open a right-click still emptied a column. `_show_dialog` now puts a full-screen blocker under every dialog |
| **`Exit` threw away the other slots** | the three deck slots hold three decks and every prompt only ever looked at the one on the surface. Exit now walks each slot with unsaved work, bringing it onto the surface so the question is about a deck the player can see |
| **a refusal ate the undo step** | `_remember` ran before the mutation, so a refused change (a fifth copy in a full deck, a Remove with nothing to remove) snapshotted the deck anyway and replaced the step the player wanted back |
| **1997 chrome slips** | the Load list's `Delete` wore the Situation Bar's red-brown Telluser stone (a salmon slab with its letters lost in it) and two dialogs carried bare Godot `SpinBox`es; `Deck Info`'s field had no stone at all |

Two 1997 COMMANDS were also recovered, by reading the whole deck-builder
run of `s30/assets/text/Menus.txt` rather than only
`@DECKSURFACE_STANDALONE`. Neither is a [QoL] invention and neither is
marked as one:

- **`Extra Cards`** (`@EXTRACARDSDIALOG`, Menus.txt:36-40) — *"Extra Cards
  / There are too many of the following Cards in your deck. / Remove Extra
  Cards / Edit Deck"*. The screen already said the sentence on its
  legality line and then left the player to find and cut every stack by
  hand. `Remove Extra Cards` cuts them, in one undo step.
- **`Move by color out of deck`** (`@DECKSURFACE_ADVENTURE`:197) with
  `@GROUPMOVE`'s own picker (*"Select Which Color(s) to Move"*: Black,
  Blue, Green, Red, White, Artifact, ticking independently). The `into
  deck` half of that pair belongs to the adventure, where the Inventory is
  a COLLECTION; ours is the whole 800-card pool, so moving a colour in
  would try to add two hundred cards.

**The thrice-corrected medallion cell map was verified independently and
is right.** The eighteen medallions in the owner's screenshot were
correlated against all 27 cells of `sprite_sheet` with a normalised
cross-correlation at a globally fitted alignment; every one has a unique
top match, and Enchantments (1,3) scores 0.635 against a runner-up of
0.437 while Sorceries (2,6) scores 0.651 against 0.529. The on/off
polarity holds too: all eighteen read 115-139 mean luminance against the
normal sheet's 102-128 and the `_pressed` sheet's 38-72. One correction to
the record: **the screenshot's strip has no SET group at all** — it is
six colours, seven types and five Other Filters, and the Set Filters the
manual lists (and the six ringed set medallions in the sheet) belong to
the STANDALONE builder, which is the screen we are building. The "gold
ring = a set" rule is also not quite a rule: `Gold`, a Colour Filter,
wears one.

### [QoL] shipped in the second audit pass

| addition | the repeated cost it removes |
|---|---|
| `Filters` -> `Select All` / `Clear All` (`@LONGLIST`'s own words), on the mini-menu and on a right-click over any plain medallion | the strip has twenty-three toggles and had no way back from them: *"show me only white creatures"* cost twenty-one clicks, and now costs three |
| `Copy deck to` — fork the deck on the surface into another slot | the slots were shipped for *"trying a variant"* and could not start one from the deck you had: a variant meant forty cards again, or a save, a load and a rename |
| the legality line is a BUTTON that opens whatever answers it | it is the only place the screen ever complains and the complaint was inert text; it now opens `Extra Cards` when Shandalar's allowance is exceeded and `Stats` otherwise |
| the `Load Deck` list names the deck and its size (`Big Green - 40 cards - big_green.deck`) | the 1997 list could only show an eight-character DOS name; ours carry a title, and a player with a dozen decks had to LOAD one to find out which it was |
| `Undo` says what it will put back (`Undo Remove all Lightning Bolt`) | `_undo_label` was written by every mutation and read by nothing |
| Escape clears the type-ahead before it leaves the screen | the box is on Ctrl+F and Escape walked straight past it into the save prompt for leaving |

### Optimisation, measured (2026-08-31, second pass)

Every row is an **A/B in one process on the same data with a warm cache**:
the old implementation was kept beside the new one in a throwaway bench,
warmed, and both were timed in the same run. 828-card pool, a 200-unique /
500-total deck, 1280x800 under `xvfb`.

| what | before | after | |
|---|---|---|---|
| `refresh()` — **what every single card click costs** on a 500-card deck | 5.2 ms | **1.0 ms** | 5x |
| — `over_duplicate_limit()` inside it | 5.21 ms | 0.07 ms | 77x |
| — `names()` inside that | 4.91 ms | 0.56 ms | 8.8x |
| one wheel notch on the Inventory (9 cells) | 1.28 ms | **0.18 ms** | 7.0x |
| one wheel notch on an unconsolidated 500-card deck area (48 cells, step 8) | 7.28 ms | **1.34 ms** | 5.5x |
| `matches()` across the whole pool | 2.96 ms | 2.27 ms | 1.3x |
| `DeckFilter.apply` first pass (facts cache cold) vs after | 10.6 ms | 3.8 ms | |
| node count after 40 pages of scrolling | 1330 -> 1331 | 1330 -> 1331 | pass 2's widget reuse intact |

Three changes, no correctness traded (each has a test):

1. `DeckModel.names()` computes each card's sort rank ONCE and sorts
   alongside it instead of doing two registry look-ups inside the
   comparator — 200 unique cards is ~1500 comparisons — and
   `over_duplicate_limit()` no longer calls it at all. Between them they
   were the whole of a card click.
2. `DeckFilter` keeps a per-card table of the facts a card never changes
   (folded name, folded rules text, colour mask, four sort ranks), matches
   colour and type against BIT MASKS rebuilt whenever `revision` moves,
   sorts on an integer key rather than a formatted String, and no longer
   reads `d.power` when the Power filter is off.
3. `CardArea._rotate_cells` slides the page's widgets along by however far
   the surface scrolled, so the ones already showing the right card keep
   it and only the genuinely new slots pay for a `MiniCard.refresh`
   (~0.3 ms each). One notch of the deck area brings in 8 cards out of 48
   and used to rebind all forty-eight.

Idle frame time is unchanged at ~20 ms, which is `llvmpipe` software
rendering the tiled grounds; nothing in this pass moved it either way.

### The pre-duel pass (forty-fifth), deliberately left

Recorded here rather than half-wired, per the pass's own brief.

- **AI sideboarding.** ~~`Side&board between duels` is offered to HUMAN
  seats only.~~ **CLOSED 2026-09-02** — [AiSideboard] sideboards every AI
  seat on what it saw, and `game/match_screen.gd` runs it as each duel is
  recorded. The diagnosis stands as written: until it existed, a best-of-N
  against the AI was a match in which one side adapted and the other did
  not.
- **`&Best of:` and `Side&board between duels` in the Deck Lab.** ~~Left
  out on purpose.~~ **CLOSED 2026-09-02**, and the reason recorded here is
  exactly why they could land: with AI sideboarding the decks are no
  longer fixed, so a best-of-N is no longer N independent duels and its
  match win rate is no longer a closed-form function of the duel win rate.
  `--best-of` and `--sideboard` are in `DeckLab/simulate.gd`; the experiment
  they were added for is above.
- **`<random deck>` in the Deck Lab.** The Lab is told which decks to
  compare; choosing one at random is the opposite of the question it
  answers.
- **`--mulligan` defaults OFF.** The Lab now offers the Shandalar mulligan
  (it never did — `game.start()` is exactly `deal_opening_hands()` +
  `start_duel()`, and the OFFER between them was what was missing), but the
  default is off because turning it on changes every opening hand and so
  invalidates the recorded determinism baseline wholesale. Measured at 200
  games/pair over the five shipped decks, seed 77: every deck's overall win
  rate moves by less than 0.5 points and no single matchup by more than 1.5,
  which is inside the interval — the Shandalar mulligan is a narrow filter
  (no land at all, or nothing but land) and a 40-card deck with 17 lands
  qualifies about 1.4% of the time. Flipping the default is the owner's
  call and should be its own change, so the baseline re-record is
  attributable to it.
- **The `.dck` decks the 1997 game and its expansion shipped.** The two
  empty deck groups (`1997 originals`, `Duels of the Planeswalkers`) have
  the mechanism but no content. Candidates exist on this machine
  (`../mage-go/rogue_dck/*.dck`, `../s30/Cunning.dck`); importing them was
  not done in this pass because most will not load strictly against our
  837-card pool, and because adding files to `decks/` would change what
  `--matrix decks/` measures — the very baseline the same pass had to keep
  byte-identical. Import them behind `--group`.

### Third audit pass (2026-09-01) — the sideboard, and a data-loss bug

The pass before this one was killed mid-flight by a hung screenshot
command; what it had already changed (`card_area.gd`,
`deck_builder_screen.gd`, `deck_filter.gd`, `deck_model.gd`) was read back
and found coherent, with two loose ends finished here: a
`DeckFilter.sort_key` its own optimisation had superseded and left unused
(deleted), and a `CODE_MAP` row still describing the per-area `card_scale`
that the same pass had removed (corrected).

**THE DATA-LOSS BUG, fixed.** `DeckModel.to_text()` wrote the banner,
`name:`, the `# note:` lines and the card counts — no `SB:` lines and no
`# group:` — while `DeckList` parses the first and `DeckGroups` reads the
second. Opening a deck that had either and saving it destroyed it
silently, and both fields had just gone live: `Side&board between duels`
plays the sideboard, and `# group:` decides the heading a deck files under
in the battle-setup list. `DeckStore.load_deck` did not read either field
back either, so the loss began at the LOAD. Both are carried now, and the
test that pins it is a **whole-file round trip** over every shipped deck —
load, model, `to_text()`, re-parse, compare name, maindeck, sideboard,
notes and group — because a test that checks the two fields that were
missing catches this bug and nothing else, while a round trip catches the
next field somebody adds.

`# group:` is CARRIED, never AUTHORED. The builder offers no way to type
one and `DeckGroups.of()` still derives `User-created` from the file's
PATH, so preserving a declaration cannot forge a heading.

**THE SIDEBOARD SURFACE, built.** A third `CardArea` carved out of the
bottom of the deck area (7x5 -> 7x4 slots at 1280x800 — stated rather than
hidden, and the alternative was a MODE, which is exactly what "never
confusable at a glance" forbids). Three cues say which pile a card is in:
the GRID (its own strip, on the Inventory's teal field instead of the
deck's navy quilt), the COUNT (`Sideboard (N)` on its own bar row, plus a
`Sideboard: N` line beside the deck's own numbers), and the CARD (an `SB`
plate on every tile, bottom-left, opposite the count disc). Cards cross by
SHIFT-click or by drag in either direction, each move is one undo step,
and the mini-menu's `Sideboard` entry says how and moves the pile in bulk.

**THE SIZE RULE IS FIFTEEN, AND IT IS NOT 1997's.** Nothing in our code
fixes a number — `MatchScreen`'s Sideboard window requires only that the
DECK go back in at the size it came out, and `MatchState` never counts the
pile — and nothing in the 1997 sources does either: the word "sideboard"
does not occur in `deckdll.cpp`, the `.dck` file's `.v<Colour>` sections
are the adventure AI's per-opponent-colour swaps, and the printed manual's
only "sideboard" is advice about your Shandalar collection (p.140). So
fifteen is modern Magic's convention, it is stated in both places the
builder states its main-deck rule (the legality line and the `Sideboard`
menu) with that disclaimer attached, and like Shandalar's duplicate
allowance it is ADVICE and never a refusal.

**`DeckFormat.legal` NEVER LOOKED AT THE SIDEBOARD — a bug of its own.**
BEFORE: it took one array, every caller passed `DeckList.cards`, and so a
`Restricted (Type 1)` deck could carry four Black Lotus in its `SB:` lines
and pass — on the battle-setup screen, in the Deck Lab's `--format` flag,
everywhere. AFTER: `legal()` and `classify()` take an optional sideboard
and count it with the maindeck; the three call sites pass it; the refusal
says how many copies are in the sideboard, because a refusal naming a card
the player cannot see in the deck area is one they cannot act on. An empty
sideboard is checked exactly as before, which is pinned.

**Three of the five shipped decks failed that rule the moment it existed**
— Black-Red Raiders held six Terror across the two piles, Blue Skies five
Counterspell, White Knights five Disenchant. Their sideboards were
rebalanced (still fifteen cards each, same archetypes) rather than the
rule being softened. Only `SB:` lines moved, so no Deck Lab baseline is
affected.

**Two things a screenshot caught that no test could have.** The command
bar took its position from the deck area, so carving the strip out of that
area's bottom put the bar straight through the strip's top row; and the
`SB` plate was drawn under `MiniCard`'s name label, which carries
`z_index = 2`. The plate is `visible`, a test said so, and it could not be
seen. Both now have tests, and the plate has an explicit z_index.

Measured, A/B in one process on a 200-unique / 500-total deck, warm cache:

| what | before | after | |
|---|---|---|---|
| `refresh()` — no sideboard | 0.514 ms | — | the click cost as it was |
| `refresh()` — 15-card sideboard, strip rebuilt every click | — | 0.543 ms | +0.03 |
| `refresh()` — 15-card sideboard, redraw guarded on a signature | — | **0.503 ms** | the strip costs nothing |
| `DeckFormat.legal(cards)` | 0.346 ms | — | |
| `DeckFormat.legal(cards, sideboard)` | — | 0.345 ms | counting two piles is free |

### [QoL] considered and NOT built, with the reasoning

- **The Inventory badge counting BOTH piles.** It says how many copies are
  already in the DECK, and that is what its doc promises; a card sitting
  0-in-deck / 4-in-sideboard therefore badges nothing, even though the copy
  rules now count five. Left alone because one number cannot say "four,
  and they are on the other pile" and a second badge is more chrome than
  the case is worth — the legality line already reports the combined count
  by name. **Owner's call** if he wants the badge to change meaning.
- **Deck comparison / diff between the three slots.** Genuinely useful
  when iterating a variant, and the slots make it cheap to reach. Left out
  because it needs a two-column list window we do not have (the same
  `@LONGLIST` widget `@CREATURE` is waiting on), and half of it is a
  dialog that is worse than nothing.
- **A suggested mana base.** "You are 3 short of the land this curve
  wants" is one line of arithmetic and the single most common deckbuilding
  mistake. NOT built because every formula for it is an opinion, and an
  opinionated number in 1997 chrome reads as the game telling you your
  deck is wrong. The land-ratio bar and the curve give a player the same
  facts without the verdict. **A written proposal for the owner to rule
  on** — if he wants it, it belongs in the Stats window beside the land
  bar, phrased as an observation.
- **Multi-select / marquee in the Inventory.** The gesture is modern, not
  1997, and `Add basic land` plus the right-click playset already cover
  the cases that made it tempting.
- ~~**Import from the clipboard.**~~ **SHIPPED 2026-09-01** — see
  *[QoL] Import, proxies and the save-time legality warning* below. The
  blocker recorded here was real and is what the proxy is: it *"needs a
  file/paste dialog with real error reporting for a decklist full of
  unimplemented cards"*, and a report is not what those cards want. They
  want to be IN the deck, visible, and refused only at the duel's door.
- **Deck Info's remaining `@TITLEDIALOG` fields** (Description, Name,
  E-Mail, Date, Face, Version) — see the last bullet below; the format
  moves first, and `notes` is the one of them a builder actually wants.

Added by the second audit pass:

- **A deeper UNDO than one step.** Cheap to build (a ring of Dictionary
  copies of at most 200 keys) and the cliff is real: `Add basic land`,
  `Remove Extra Cards` and `Move by color out of deck` are each a large
  change, and two mistakes in a row cannot both be taken back. NOT built
  because the screenshot pass chose one step deliberately — *"a builder
  wants 'put that back', not a history"* — and a test pins the toggle
  (`test_undo_undoes_itself`: a second `Undo` redoes). Deepening it means
  splitting `Undo` from a `Redo`, which is two menu entries where 1997 had
  none. **A written proposal for the owner to rule on.**
- **`Move by color INTO deck`**, the other half of
  `@DECKSURFACE_ADVENTURE`'s pair. In Shandalar the Inventory is your
  COLLECTION, so moving a colour in is a handful of cards; ours is the
  whole pool and it would be two hundred. It would only be honest scoped
  to the FILTERED Inventory — "put everything I am looking at in the
  deck" — which is a different command wearing a 1997 label. **Owner's
  call**; if he wants it, the honest wording is its own.
- **A right-click mini-menu on an Inventory card** (`Add one / Add four /
  Take one back / Take all back`). The single most repeated correction on
  this screen is taking back a card you just added, and it currently means
  finding it in the deck area, which pages. More 1997 than the present
  unlabelled "right-click adds four", but it turns the commonest gesture
  from one click into two, and it redesigns a tested gesture inside an
  audit pass. **Proposal.**
- **A count line for the DECK area** the way the Inventory has one. A
  200-unique deck is five pages of miniatures with nothing saying which.
  Left out because there is no room on the command bar for it and
  shrinking the deck area to make some is the one thing the brief forbids.
- **`@FULLCARD` ("Expand Text Box")** on the Showcase — still owed, still
  `CardPreview`'s, which belongs to the duel.

Owed, and each one is owed for a stated reason — `DeckFilter.OWED` is the
live list:

- `@CREATURE`'s "Summon from list..." and `@ENCHANTMENT`'s enchant-target
  split both want the 1997 LIST WINDOW (`@LONGLIST`: "Enable Filter /
  Select All / Clear All") over `@CREATURENAMES`' 210 subtypes. The data
  is there (`CardData.subtypes`, `CardData.aura_target`); the widget is
  not.
- `@ABILITY`'s fifteen toggles ("&Native / &Gives / &Flying / F&irst
  strike / &Trample / &Regeneration / &Banding / (&Color) Ward / (&Land)
  Walk / &Poison / R&ampage / &Web / &Stoning / Free &Action / &Quick
  draw"). Most map straight onto `Mtg.Keyword` or a CardData field —
  Web is REACH, Free Action is VIGILANCE, Quick draw is HASTE — but
  Native-vs-Gives needs a static-ability scan we do not have.
- `@RARITY` and `@ARTIST` cannot be built at all: `cards/data/*.json` is
  fetched without either field, so this is a card-pipeline job first
  (`tools/fetch_cards.py`), not a UI one. **And `@RARITY` is more than a
  filter** — its five values are `&Common &Uncommon &Rare R&estricted
  &Banned` (`s30/assets/text/Menus.txt:384`), and `@RESTRICTED`
  (`Program/CueCards.txt:81`) letters *"Restricted cards are in the
  list"*. So the 1997 game knew which cards were restricted, and that
  data is the one thing that could settle the list below. It is not in
  `Rarity.csv` (checked: its `Rarity` column is print rarity and
  print-run counts, `C`/`U`/`R`/`U1`/`C3`, across all 1001 rows); it is
  inside `Rarity.dat`, a 943 KB undecoded binary whose Manalink copy
  differs from the `Program/` one, or inside `Deckdll.dll`.

- `@FULLCARD` ("&Expand Text Box"), the Showcase's own right-click
  toggle: it belongs to `CardPreview`, which is the duel's.
- Deck Info collects only the Title. `@TITLEDIALOG` also has Description,
  Name, E-Mail, Date, Face, Comments and Version. **Comments is now
  shipped** as `Deck notes` ([QoL]), carried in the `.deck` file as
  `# note:` lines that `DeckList.parse` already skips — which is the
  pattern the remaining six should follow, one `# key:` line each, so
  every older reader and the two export formats stay unaffected.

## THE ERA-CORRECT RESTRICTED LIST (2026-09-01) — a correctness fix

Not a UI item. `DeckFormat.RESTRICTED` was the **modern Vintage** list,
kept on the recorded reasoning that *"the 1997 card pool does the
historical filtering — what survives the intersection is exactly the
era's list."* **That reasoning is wrong**, and the hole is one-directional:
it filters cards ADDED to the list since 1997 (they are not in our pool,
so they never match) but cannot restore cards REMOVED from it, and those
are in our pool. Eleven were, and the game was telling players their decks
were Tournament (Type 1.5) legal when the era says otherwise.

**Added**, each on the DCI's own Classic (Type 1) list as printed in *The
Duelist* #22, 1 January 1998 — the closest contemporary source that
survives, a printed paper-Magic source and so ranked with the 1998
Advanced Strategy Guide rather than with the game's own artefacts:
Berserk, Black Vise, Braingeyser, Fork, Ivory Tower, Maze of Ith, Mirror
Universe, Recall, Regrowth, Underworld Dreams — plus **Mind Twist**, which
the owner named.

**What it broke:** one shipped deck moved, and nothing was rebalanced.
`big_green.deck`'s single Regrowth makes it Restricted (Type 1) instead of
Tournament (Type 1.5) — a format it is legal in, one copy being exactly
what Restricted allows. `blue_skies.deck` already sat there for its
Ancestral Recall.

**Three findings left for the owner, deliberately not acted on** — each
would LOOSEN or WIDEN a rule, which is not a change to make on a secondary
source's say-so inside another pass:

1. **Mind Twist is on the 1998 BANNED list, not the restricted one** (it
   was banned 1 February 1996 and unrestricted only in 2007). It is on our
   RESTRICTED list because the owner asked for it there, which is the
   conservative half of that reading — it can only make an illegal deck
   illegal.
2. **Channel and Divine Intervention are on the 1998 BANNED list too**,
   and both are in our pool. Channel is currently RESTRICTED here; Divine
   Intervention is on neither list. Not added: the brief for that pass was
   explicit that *"Banned is fine as it stands"*, and widening a ban is a
   real rules change.
3. **Mana Crypt, Mana Vault and Time Vault** are on the modern list, are
   in our pool, and are NOT on the 1998 list. Left restricted. Removing a
   restriction loosens the rules, and `test_the_modern_entries_our_pool_holds_are_recorded_not_hidden`
   pins that we know rather than that we agree.

The list is now the UNION of the two, and the modern half is kept whole
by NAME so a card graduating into the pool later arrives already
restricted — that half of the old argument does still hold.

## [QoL] IMPORT, PROXIES AND THE SAVE-TIME LEGALITY WARNING (2026-09-01)

Three related additions, all marked `[QoL]` on the same evidence: `grep -a`
over `Program/UIStrings.txt`, `Program/Text.res`, `Program/prompts*.txt`
and the genuine 1997 `s30/assets/text/Menus.txt` finds neither "import"
nor "paste" nor "proxy" anywhere. The original moved decks by copying
`.dck` files in DOS — which is why `@DECKLOADERROR` and `@DECKEXISTS` talk
about file names — and its Inventory was the cards the game HAS.

**The proxy** (`engine/proxy_card.gd`, `game/deck_builder/proxy_face.gd`).
A proxy is *a card name the `CardRegistry` does not know* — the whole
definition. Nothing is written to the deck file to mark one, so it
round-trips through `.deck`, `.dec` and `.dck` for free, an older build
reads the same file back unchanged, and a proxy **graduates by itself** the
day its card is implemented. It is drawn as plain paper at the one card
size (`MiniCard.SIZE` small, `CardPreview.SIZE` large), never a coloured
frame — a proxy has no colour to claim. **The original ships no blank
card**: surveyed, and the survey is recorded in `tools/import_original.py`
so nobody repeats it.

**The boundary is the part that matters.** A proxy must never be playable:
`MtgGame._build_library` push_errors and SKIPS a name it cannot resolve, so
a proxy reaching a duel would deal a seat a library quietly short of
cards. `data_for` builds a `CardData` and never registers it;
`ProxyCard.refusal_for` is asked at the battle-setup screen's live note and
its `Go!` gate and at the Deck Lab's loader; `DeckList.load_file(path,
true)` is the floor under all of them. `tests/unit/test_proxy_card.gd` pins
each door.

**Decisions taken, stated because they were left open:**
- **The copy rules DO apply to proxies.** Shandalar's duplicate allowance
  and `DeckFormat`'s four-of both count them, and a proxy whose NAME is on
  the banned or restricted list is treated as that card. A proxy stands in
  for a card, so a deck built with stand-ins should still be a
  legal-LOOKING deck. This needed almost no code: the lists are kept by
  name and a proxy is by definition a card outside the pool.
- **`to_dck_text` writes `.0` for a proxy's MicroProse id** — no new rule,
  the one already there for any card the 371-entry table does not name.
  Ids are ignored on read (names are authoritative in that format), so the
  proxy survives the round trip intact.
- **A proxy sorts LAST** in `S&ort deck` order. It has no colour, so there
  is no column it belongs in, and the cards still to be replaced gathered
  at the end are the easiest to find.
- **`DeckStore.load_deck` keeps proxies rather than dropping them.** It
  used to drop unknown names and report which, so opening a deck in the
  builder and saving it silently shortened the player's own file.

**Import** offers BOTH doors, because a decklist travels two different
ways: `From a file…` (a `.dck` out of a real install, a `.dec` another
program wrote — the only door that reaches a path outside our two deck
directories, and extension routing is free there) and `Paste a decklist…`
(how a list actually moves today, with the format sniffed because pasted
text has no extension). Both end in the same fold. The file half uses
Godot's `FileDialog`, which is the one control on this screen we did not
draw; building a 1997-styled directory browser is a filesystem widget's
worth of work to reach a file the player already knows the path of.

**The save-time legality warning.** The analysis already existed
(`DeckFormat` had all three rules) and the legality line already reported
some of it; what was missing was any check in the SAVE path, which tested
the deck's name and whether the file existed and nothing else. It **warns
and never refuses**, and the ORDER is the guarantee: the file is on disk
before the dialog exists, so there is no branch here that can stop a save
and none that a later edit can turn into a gate. A deck under construction
is illegal most of the time. `DeckFormat.offences()` is the same three
rules asked all at once instead of `legal()`'s first-refusal-and-stop, in
the SAME sentences, so a gate's refusal and the builder's warning are one
vocabulary. A single restricted card is deliberately NOT an offence — that
is `classify()`'s job to report, and warning about a lone Sol Ring would
cry wolf.

## THE ZONE COLUMN, AND WHAT 1997 PUT THERE (2026-09-03) — [QoL]

The owner photographed the sidebar's pile row and asked *"What is this
small number right of the exile stack?"* It was the **graveyard's** count.
`DuelScreen._grave_labels` had been built as a bare `Label` appended to the
piles row AFTER the exile plate — a leftover from when one label read
"Deck N / Grave N" for both piles — so it floated in the black gap in the
default theme's WHITE, while the library's and the exile's counts sat on
their own art in yellow. It belonged to nothing on screen, which is
exactly how it read.

**What changed.** Every count is now a child of the pile it counts and
sits in that pile's own bottom-right corner (`_pile_count_label`), in the
life numeral's `PILE_COUNT_INK` — Color(0.95, 0.85, 0.20), the yellow that
was already here — over a 4px black outline. The outline, not the hue, is
the fix: the library's count had none at all and stood on a busy card
back, and one yellow with a hard floor is legible over a card scan, a card
back, all five painted plates and the black column behind them. The gap
the stray number vacated now carries the seat's CHOSEN portrait
(`DuelConfig.portraits` -> `PortraitLibrary`, resolved through
`DuelIntro.portrait_for` so the duel and the pre-duel splash cannot
disagree) with its name above it for the player and below it for the
opponent, trimmed to the portrait's width. Pinned by
`tests/ui/test_zone_column.gd`.

**Four columns, three even gaps, and a deck that looks like a deck.** The
owner's follow-up asked for the row to read as one row. The sidebar is
fixed at `CardPreview.SIZE.x` = 300 so the examined card fills it 1:1; the
mana panel takes 128*0.85 = 109 and the panel row's own separation 6,
leaving this block **exactly 185**, which the four columns now spend to
the pixel: `50 + 5 + 40 + 5 + 40 + 5 + 40`. The three plates and the
portrait are the 1997 grave plate's own 40px wide and 60 tall; the deck is
50x61 because it is the one column that is bigger on purpose.

**And its thickness is the 1997 readout, not decoration.** `Duel.hlp`
again: the library *"is represented — inexactly"*. So the pile is drawn as
a stack whose depth tracks what is left — `DuelScreen.LIBRARY_STEPS =
[1, 4, 10, 20, 32, 45]`, one card back per threshold reached, nought to
six — with the exact number written on its top card. Stepped rather than
per-card, and the TOP card back never moves (the stack grows and shrinks
behind it, up and to the left) so the count riding the box's corner is
right at every depth. A 60-card library opens at six sheets, a 40-card one
at five, and an empty library draws nothing at all, which is the state
`Duel.hlp` warns about. Every step is pinned by name in
`tests/ui/test_zone_column.gd`, because "how thick is the deck at N cards"
is exactly the kind of number that drifts.

**Where this diverges from 1997, stated rather than hidden.** The original
printed no pile counts at all. `Duel.hlp`, topic **Library**: *"The number
of cards left in your library is represented — inexactly, as in real life.
If you must know, you can right-click on a library to find out the exact
number of cards left in it."* The pile's THICKNESS was the readout, and
`@MENU_LIBRARY`'s `Count library cards` was the exact answer (which
`_on_pile_input` still gives; `@MENU_GRAVEYARD` never had a count entry at
all). The pile's THICKNESS, on the other hand, is 1997's own idea and this pass
restores it rather than diverging from it. Nor did the 1997 table show a
seat's portrait beside the piles —
`Duel.hlp`'s own numbered tour of the screen lists ten parts and the face
appears only on the flipped **Life Register** (topic **Duelist's Face**).
So both halves of this pass are [QoL]: the counts were already a
divergence this screen carried from the day it was built, and the owner's
ask refines it rather than opening it; the portrait is new, and it is the
first thing in a duel to read the face a player chose for themselves.
Neither hides a 1997 affordance — the right-click count, the flip-to-face
and the pile viewers are all still there.

## THE DYING MARK, AND HOW LONG IT STANDS (2026-09-03) — [QoL]

The owner's playtest note was *"Killed creatures should have blood state
graphic over them!"* — and the graphic already existed, unused.
`Dying.pic` has been imported as `state_dying` since §2.10, `MiniCard`
has drawn it since the same pass, and no player had ever seen it.

**What the 1997 state actually is, which is not what our predicate said.**
`@CUECARD_SMALLCARD` (`UIStrings.txt:741`) entry 8 is the word `Dying`,
and the small card's own tooltip handler says exactly when a card wears
it (`shandalar-src/src/functions/windows.c:724`, quoting the 1997 exe's
string at `0x786f08`):

```c
else if (instance->kill_code == KILL_DESTROY)
  strcpy(tooltip, EXE_STR(0x786f08));   // CUECARD_SMALLCARD[7] = Dying
```

`KILL_DESTROY` (`defs.h:428`) is DESTRUCTION — a permanent marked to go to
the graveyard and not reaped yet. It is the same predicate a regeneration
effect targets (`defs.h:2481`, `TARGET_SPECIAL_REGENERATION` *"checks both
the `kill_code` for `KILL_DESTROY` and `token_status` for
`STATUS_CANNOT_REGENERATE`"*), refused with the line three cards carry:
`Illegal target (not dying).` (`prompts.txt:239` Death Ward,
`promptsX1.txt:167` Elephant Graveyard, `:323` Pyramids). `Duel.hlp`,
topic **Regeneration**, says it in words: *"You can use regeneration ONLY
at the time when a creature is about to go to the graveyard."*

So `Dying` is not "lethal damage marked" — it is the window between
destroyed and reaped, and TERROR and WRATH put a creature in it with no
damage at all. Our predicate answered only the damage half, and even that
half is invisible under the default ruleset: `MtgGame.destroy` decides and
moves in one call, and the one place the engine holds that moment open —
`awaiting_regeneration`, the 1997 regeneration step behind
`RulesOptions.damage_prevention_window` — is off by default and auto-skips
when no seat holds a regeneration effect.

**The divergence, stated.** The mark is now raised off
`Mtg.EventType.DIES` (`MiniCard._on_game_event` -> `DeathMark`), which
means it appears one step LATER than 1997's: after the permanent has gone,
not while it is still standing. That is the deliberate choice — a mark
hung on the damage would sit on creatures that go on to regenerate, and a
mark that appears late is better than one that lies. The consequence is
that it must be held artificially: `DeathMark.HOLD = 0.45s` +
`FADE = 0.55s` is **[QoL]**, ours, and it stands in for a step whose 1997
duration was however long the player took to pass it. The mark is a whole
`MiniCard` ghost rather than bare cracks for the same
cannot-lie reason: the board re-flows the instant a creature leaves it, so
cracks alone would end up drawn over a LIVE neighbour.

**Two places it is narrower than 1997, on purpose.** A SACRIFICED
permanent gets no mark (1997's `KILL_SACRIFICE` is a different kill code
and does not read `Dying`, which is also why regeneration cannot answer a
sacrifice; our `sacrifice_permanent` never enters `destroy`, and the
`DIES` event carries the flag). And a creature swept by zero toughness or
buried by the legend rule DOES get one, where 1997's `KILL_BURY` would
not — the `DIES` event does not distinguish those from destruction, and
over-reporting a death that really happened is the safe direction.

Pinned by `tests/ui/test_death_mark.gd`; shot as `shot_death_mark.png`.

## THE DECK BUILDER'S FILTER STRIP AND ITS COUNT (2026-09-03)

Two defects from the same playtest, one of them [QoL].

**1. The filter buttons had no press sprite, and it was not the bug the
rest of the tree had that day.** The owner: *"Filter buttons do not feel
responsive — on click an immediate press sprite should be displayed!"*
`OriginalDialog.button`, `OriginalDialog.dress_bar_button` and
`UiChrome.menu_button` were all fixed the same day for the
`hover_pressed` fall-through — Godot draws that state for a button held
down WITH THE POINTER ON IT and falls back to the default theme when
nobody overrides it. `FilterBar` already named `hover_pressed`, so that
was not it. Two other things were, both measured rather than reasoned
about:

- `_apply_texture` bound **one StyleBoxTexture instance to all five draw
  states** and chose which ART by the latched value, so no draw mode could
  differ from any other. A capture of the Creatures medallion held down
  was pixel-identical to the same medallion at rest — max channel
  difference **0** — in both latch states.
- the `focus` box was that same **opaque medallion**, and Godot paints
  `focus` ON TOP of the draw-mode box. Every toggle here is `FOCUS_ALL`
  and a click focuses it, so the first click on a medallion froze it at
  its resting art for the rest of the session.

The fix is Godot's own toggle arithmetic and not another sprite.
`BaseButton::get_draw_mode` INVERTS `pressing` when a button is latched,
so a held toggle draws the box of the state it is **about to become**
(probed on the pinned 4.7.2 build: latched off + held -> `pressed`,
latched on + held -> `normal`). Binding the OFF medallion to `normal` and
the ON one to `pressed` therefore makes one pair carry both jobs — the
latch at rest and the press under the finger — and `refresh()` no longer
repaints anything at all, which also removes the old reason it could not
have worked: it runs off `pressed`, and a toggle in the default
`ACTION_MODE_BUTTON_RELEASE` emits that on the mouse coming UP. `hover`
and `hover_pressed` are those same two latch states under the pointer and
now differ too, or a release would land back on the look the click started
from. `focus` is a hollow one-pixel ring in the era's own HIGHLIGHT, which
keeps the keyboard cue and covers nothing. The lettered Unlimited/promo
toggles and the **no-skin** flat fallback carry the identical split, so
the strip goes down under the finger with no original art imported at all.
The OFF medallion has no hover cut of its own in DBArt — the original cut
one hover sheet and it is the lit RAISED cell — so it borrows that sheet's
own measured lift, x1.26 (`sprite_sheet_hover` 151-160 mean luminance
against `sprite_sheet`'s 120-127), which leaves both latch states exactly
as much brighter under the pointer as the other.

**2. [QoL] The Inventory's count now sits in the card row's own
bottom-right corner.** The owner: *"The number of cards in the bottom row
should be displayed in the bottom right — if you filter you immediately
see this number get smaller and see the effect of the filter!"* The 1997
cue-card sentence `X cards are in the list` is still on the strip under
the Showcase, where the screenshot pass put it, but that is the LEFT
COLUMN — three regions away from the row it counts, so the filter's effect
had to be looked up rather than seen. `CardArea.tally` letters the number
into the far end of the same bar row `title` starts, and the scroll bar
gives up `TALLY_W` for it so the two never overlap.

**What it counts, stated because the paged case has two honest answers:**
every card the filter leaves standing — the whole list — and **not** the
nine on the page. The number exists to be watched while the medallions and
the type-ahead move; a page-sized one would read "9 cards" from Abu
Ja'far to Zombie Master and report nothing. Where in the list the player
is standing is the `(first-last)` range on the older line, which is a
different question and still answers it.

The voice is the lettering already on that row — the `title`'s pale
`OriginalDialog.HIGHLIGHT` — over a hard dark outline, which is the house
rule the zone column settled the same morning (see **THE ZONE COLUMN**
above): a number over busy art needs a FLOOR, not a new hue, and this
corner has Dekbar1's dithered teal, the scroll bar's stone and the bottom
edge of whatever card art the last column holds. The corner count is
[QoL]: the 1997 screen printed its total in the cue-card sentence and
nowhere else. Nothing 1997 was removed to make room.

Both halves pinned by `tests/ui/test_deck_builder.gd`; every test in its
final section failed before the fix beside it.

## Duel-screen simplifications still to lift (2026-09-01)

Presentation-layer shortcuts, each with a `SIMPLIFIED:` marker at its
site. Card-scoped deviations live in `docs/simplified-cards.md`; these are
screen-wide.

**LIFTED 2026-09-02 — ~~Only the `patt` territory art is imported~~.** The
row that stood here said the other two styles fell back to the pattern
because *"the only copies in `../shandalar-src` are Manalink `.bmp`s"*.
That was true of `shandalar-src` and beside the point: the importer does
not read `shandalar-src` for art, it reads the s30 conversions, and
`s30/assets/art/screens/duel/` was holding all fifteen `Terr_*.pic.png`
files in the same folder as the five `patt` ones already being imported.
Nothing needed decoding — ten MANIFEST rows had simply never been written.
All nine choices now resolve to their own art
(`tools/import_original.py`, `DuelOptions.ground_key`), each of the three
styles is drawn as the thing it actually is
(`game/duel/territory_ground.gd`), and a player with NO imported art gets
all fifteen grounds painted at runtime. Pinned by
`tests/ui/test_territory_ground.gd`; `docs/duel-todo.md` §6.4 carries the
survey.

- **`Advanced` layout is listed and greyed** (`game/duel/duel_options.gd`,
  `DuelOptions.layout`). `@DIALOG_DUELOPTIONS` offers `Standard` and
  `Advanced`; `Duel.hlp`, **Dueling Options**, says Advanced *"streamlines
  the dueling area. The Showcase is removed (though it appears when
  necessary), and the other parts of the interface are rearranged to allow
  the largest possible territories."* That is a screen-layout milestone,
  not a switch. Lifting it means a second full layout for the duel screen
  plus a temporary Showcase — and `src/functions/dialog.c:737-740` adds
  that `option_Layout == 2` also changes the card gesture from right-click
  to right-DOUBLE-click.
- **`Spend 1 mana: <colour>` is listed and greyed** (`CardMenu.MANA_POOL`,
  `@MENU_MANAPOOL`). `Duel.hlp`, **Mana Pool**: *"If there is mana in your
  pool that you wish to use, click on the area next to the appropriate
  color button (or on the button itself) to apply that mana one at a
  time."* In the original the player pays a cost mana by mana; our engine
  settles a whole cost inside one `MtgGame.cast_spell` call, so there is
  no half-paid spell for a mana to be spent INTO. Lifting it is a
  held-open PAYMENT — the shape `duel-todo.md` §1.3 gave the
  mid-resolution questions — and it is also the prerequisite for the
  auto-tap that `@MENU_SMALLCARD`'s `Don't auto tap this card` proves the
  original had.
- **`Show invisible effects` is listed and greyed**
  (`DuelOptions.MENU_TOGGLES`, `ShowInvisibleEffectCards`). *"toggles the
  appearance of those effect cards (the temporary yellow cards that pop up
  all the time) that are not normally displayed."* Our engine has no
  effect-card objects: a continuous effect is a recomputation, not a
  permanent, so there is nothing to reveal.
- **The Spell Chain window does not minimize.** `@MENU_SPELLCHAIN` /
  `@MENU_MINIMIZEDSPELLCHAIN` are tabled in `CardMenu` and dark. The 1997
  restore route is the Phase Bar's window icon (manual p.122), which our
  single icon already spends on the Combat window; lifting it means the
  icon serving two windows.
- **The hand window has no revolving scroll.** `Duel.hlp`, **Hands**:
  *"If there are too many cards in your hand to display all at once, use
  the scroll arrows at the top to see the rest. This is a revolving
  scroll, which means that the top cards cycle to the bottom."* Our ▲/▼
  zones fold the hand instead (s30's idea); the pile has no maximum size
  to scroll past yet. See `docs/duel-todo.md` §3.6.
- **`StackItem.description` names no targets and no X**
  (`engine/mtg_game.gd:1003`, `:1170`). It is the game log's sentence as
  well as the chain window's tooltip, so filling it in improves both —
  `docs/duel-todo.md` §3.9.

## PROVENANCE CORRECTIONS (2026-09-02) — `Program/Text.res` is Manalink's

Found while establishing the gauntlet from the sources. Both entries are
**documentation defects, not code defects** — nothing shipped behaves
wrongly because of them — but a wrong fidelity claim in our own docs is
worth more to fix than a feature, because it is what the next pass builds
on. Evidence: `docs/gauntlet-design.md` §0; the code-level write-up is
`docs/duel-todo.md` §6.21.

**1. `Program/Text.res` is Manalink 3's table.** `docs/duel-todo.md` §6's
provenance box said it was *"a SECOND, LARGER copy of the same table… a
superset rather than a different file. Either may be cited."* It carries
`Momir Basic` (a **2006** format), `&Challenge Mode` where the 1997
gauntlet page has `&Ante`, `Highlander`, the network row
`&Send Parameters` / `&Agree` / `&Disagree`, a tag that does not exist in
1997 at all (`@SHELLPAGE_MULTIDUEL`), and `199 unique / 499 total` cards
where 1997 says `200 / 500`. **The box is corrected. `Provenance.md`'s
Tier 1 table moves it out of Tier 1.** Three shipped citations point at
it — `match_state.gd`, `duel_config.gd:22`, `duel-todo.md` §6.19 — and
each has its 1997 replacement listed in §6.21. **Only one of them is a
wrong claim rather than a wrong file name: `&Free play` is a Manalink
string, and our setup screen shows it.**

**2. `Program/UIStrings.txt` itself is lightly Manalinked; the clean 1997
copy is `s30/assets/text/Uistrings.txt`.** Seven differences, every one of
them 1997 → modern in the `Program/` direction: `Reach` for the 1997
keyword **`Web`**, `View exiled cards` for `View the out-of-play cards`
("exile" is a 2009 word), a shortened `-1/-1 counters`, `,name` for
`,card type`, an expanded `@LANDWORDS`, and an added `@GROUPMOVE`. The two
files are **line-for-line aligned to line 1183** and `Program − 40` after
it, so every existing `UIStrings.txt:N` citation in this project is
correct in both. `Provenance.md` already named s30 as the home of the
genuine `Menus.txt` and `CueCards.txt`; `Uistrings.txt` joins them.

### `MatchState.LENGTHS` — checked, and the 5 is real

The pass that wrote `LENGTHS = [3, 5]` justified it as *"the only two
lengths the original's strings can narrate"*. **That is correct and it is
1997**: `@DIALOG_ENDEXP1DUEL_MATCHPROGRESS` (`Program/UIStrings.txt:558-559`,
and the same lines in s30's genuine copy) ships one record sentence for
`best of 3` and one for `best of 5`, with the number written into the
sentence rather than substituted. **We did not invent the 5.**

What the same check turned up is that there are **three** match-length
surfaces in the sources, not two: the shell pages' `&Best of:` is a
numeric **spinner** (`msctls_updown32` in the 1997 `SINGLEDUELPAGE`,
`GAUNTLETPAGE` and `SEALEDDECKPAGE` templates); the duel program's own
`@DIALOG_GAUNTLETOPTIONS` is the two-way `Best of Three` / `Best of One`;
and the narratable pair is `{3, 5}`. `[3, 5]` is the intersection of the
first and third and stays. **What is missing is the second surface's 1.**

**Recommended, S, one line plus a test** (not built — this was a design
pass): `LENGTHS = [1, 3, 5]`, with **nothing added to `PROGRESS`**.
`MatchState` already does the rest: `wins_needed()` is `best_of / 2 + 1`
= 1, `is_over()` is true after one duel, `progress_line()` already returns
`""` for a `best_of` it has no sentence for, and `verdict()` already
returns the length-agnostic `You've won the match!` for anything that is
not `FREE_PLAY`. `Best of One` and `Free play` are the same single duel
mechanically and **differ narratively** — one is a match with a verdict,
the other keeps no record — which is exactly the difference the strings
draw. Keep `FREE_PLAY` as the internal default so every programmatic
`DuelConfig` (tests, Deck Lab, benchmarks) stays a plain duel, and mark
the setup screen's `Free play` **label** `[QoL]`, because the word is
Manalink's for a 1997 idea (the spinner at 1).

## THE FIFTH-EDITION RULESET, AUDITED AS A WHOLE (2026-09-02)

Seven forks live in `engine/rules_options.gd` and `--rules fifth` has run
them since 2026-08-31, but nobody had ever asked whether the 1997 side is
as FINISHED as the modern one. This pass asked three questions of it: does
each fork's fifth-edition branch work end to end, is it tested to the same
depth, and do the seven interact correctly with all of them on at once.

**The forks are not independent, and that is where the defect was.** Four
of them key off the same phase boundary and two of those write to the same
life total on it, so "each fork works alone" was never the same claim as
"the ruleset works" — and every existing test was a single-fork test.
`tests/unit/test_fifth_edition.gd` is the file that was missing: every
test in it runs `rules.set_edition("fifth")` and nothing else, so it tests
the shipped PRESET rather than a hand-mixed one.

### Fixed

| Finding | Severity | Pinned by |
|---|---|---|
| **Mana burn was charged AFTER the phase-end lethal check**, and both fire on the same boundary (`_advance_step`). A player burned from 3 to −2 lived on through the whole next phase; under the full preset mana burn could not kill at the boundary it was charged on. The manual's own escape clause (*"if you manage to gain back enough life ... before the end of the phase"*, p.174) cannot rescue a burn either way, because the burn IS the end of the phase (p.176). Neither fork was wrong alone, which is exactly why no single-fork test saw it. | **HIGH** (under `--rules fifth`) | `test_mana_burn_kills_at_the_boundary_it_is_charged_on`, `test_both_seats_burning_out_together_is_a_draw` — both failed before the reorder |
| **`attackers_revocable = false` was bypassed by Cancel** — reported by this audit, FIXED 2026-09-02 by the coverage pass below once the file was free. `_toggle_attacker` refused to take ONE attacker back under the 1997 answer (*"attackers are final"*, manual p.86) while `_on_cancel`'s `Mode.ATTACKERS` branch cleared `_selected_attackers` unconditionally, so Escape — and the Situation Bar's Cancel button, which is the same door — un-declared ALL of them. Two conditions in `game/duel/duel_screen.gd`: `_on_cancel` clears only when the flag allows it (the load-bearing one, because `_on_escape` does not consult `_can_cancel`), and `_can_cancel` reads the flag its own doc comment already named. **The fork is UI-only by design** — `MtgGame.declare_attackers` takes the whole list at once and refuses a second call under either ruleset — so the engine was right and only the screen was wrong. | MEDIUM (under `--rules fifth`) | `test_escape_does_not_walk_around_the_1997_attackers_fork` (failed before the fix: 0 attackers left instead of 2), with `test_escape_takes_back_a_declaration_that_is_revocable` and `test_blockers_stay_revocable_under_the_attacker_fork` holding the other two corners |

### Ledgered — a deliberate simplification with no row until now

- **The 1997 pool and life boundaries are PHASE ENDS only.** Manual p.176:
  the pool empties *"at the end of each phase **and at the beginning and
  end of an attack**"*, and p.174 checks life *"at the end of a phase **or
  the start or end of an attack**"*. `_phase_ends_now()` implements phase
  ends, which covers "end of an attack" (the combat phase ending) and
  drops **the start of an attack**. That is the owner's ruling of
  2026-08-31 (*"combat counts as ONE phase that empties only when it is
  over"*) and `RulesOptions.pool_empties_on_attack` documents it — but it
  had no ledger row, so it is one now. What it costs: mana floated in the
  beginning-of-combat step survives to the damage step and is not burned,
  where 1997 would have emptied and burned it at declare-attackers.
  `docs/duel-todo.md` §6.20g describes the same gap and its text is now
  stale (it still says *"We clear at every step boundary"*).

### Measured

`--matrix decks/ --games 60 --seed 4242 --rules fifth`: **600 games, 0
stalled**, so the 1997 ruleset plays end to end at scale with every fork
on. Against the modern control at the same seed, six of the ten matchups
are IDENTICAL game for game and the other four move well inside their
Wilson intervals; games run marginally shorter (avg 16.6 vs 16.9 turns)
and the run is ~20% slower (the damage window is extra priority rounds).

**That near-neutrality is itself a finding, and it is about the DECKS, not
the forks.** The AI taps exactly what it needs, so mana burn almost never
fires; it rarely crosses 0 life mid-phase; and the damage window
auto-skips whenever no seat holds a prevention effect, which is most games
because the shipped maindecks carry their Circles in the SIDEBOARD. So the
Deck Lab is currently a weak exercise of the fifth branch, and a deck with
maindeck prevention would be a much stronger one — worth building before
anyone reads a `--rules fifth` measurement as evidence that the two
rulesets play alike.

### Coverage, before and after

Test references per fork before this pass: `damage_prevention_window` 17,
`mana_burn` 14, `attackers_revocable` 6, `life_checked_at_phase_end` 5,
`free_damage_assignment` 3, `tapped_artifacts_stop` 3,
`pool_empties_on_attack` **2**. The depth was not remotely even, and the
two thinnest are the two that key off the phase boundary the defect above
lived on. The new file adds eight cross-fork tests.

### The levelling pass (2026-09-02, later the same day)

The audit's own measurement was the brief: level the depth, and weight the
effort at the INTERACTIONS rather than at whatever already had seventeen
tests. `tests/unit/test_fifth_edition.gd` went from **8 test functions to
20**, and every one of them runs the whole preset, so each new test
exercises all seven forks at once.

Same metric as above (`grep -rn <key> tests/ | wc -l`), measured
immediately before and after this pass — note the "before" column is the
audit's "after", since the audit's own file had already landed:

| Fork | Before | After |
|---|---|---|
| `damage_prevention_window` | 20 | 27 |
| `mana_burn` | 16 | 26 |
| `life_checked_at_phase_end` | 7 | 10 |
| `attackers_revocable` | 6 | 15 |
| `tapped_artifacts_stop` | 3 | 6 |
| `pool_empties_on_attack` | **3** | **8** |
| `free_damage_assignment` | 3 | 7 |

(`attackers_revocable`'s last five arrived with the Escape fix in
`tests/ui/test_cancel_contract.gd`.) The spread (max ÷ min) closes from
6.7× to 4.5×, and the two forks that key off the phase boundary are no
longer the two thinnest. (The metric
counts comment lines as well as code, which is why a new section header
naming every fork lifts all seven; the real change is the twelve new
tests.)

**What is now covered that was not**, pair by pair — the file's own new
header lists which pairs can interact at all, so a reader can see what is
deliberately absent rather than forgotten:

* `pool_empties_on_attack` × `damage_prevention_window` × `mana_burn` —
  **the reason the 1997 pool rule exists.** Mana floated when blockers are
  declared is still there in the damage step, which is what PAYS for the
  prevention; what is not spent burns when combat ends. Under modern rules
  that mana is gone a step early and there is nothing to answer with.
* The same trio across the SIX-step combat first strike produces: charged
  once for the float, not once per damage step.
* `mana_burn` × `life_checked_at_phase_end` × `damage_prevention_window` —
  one seat burns out and the other bleeds out on the same boundary, and
  manual p.168 makes that a DRAW. Under the pre-audit ordering the burning
  seat would have WON it.
* `mana_burn` × `damage_prevention_window` — a prevention shield raised
  inside the window does nothing about a burn, because burn is life loss.
* `free_damage_assignment` × `damage_prevention_window` — a 2/4 division
  modern rules refuse is what the window then holds, packet for packet.
* `tapped_artifacts_stop` × `mana_burn` — Gauntlet of Might is the card
  that separates one permanent's halves: the anthem is a static and stops,
  the "whenever a Mountain is tapped for mana" TRIGGER is not and does
  not, and the extra {R} it still makes is still charged for.
* `tapped_artifacts_stop` × `damage_prevention_window` — an Icy'd
  Forcefield still arms the window and still works inside it, because the
  manual suspends CONTINUOUS effects only. The fork's tests were all
  statics; this is the other side of its own documented boundary.
* `attackers_revocable` — **no engine interaction exists, and that is the
  finding.** It is the one fork with no engine branch at all, pinned by
  `test_the_engine_has_no_undeclare_which_is_why_that_fork_is_the_screens`
  so that a reader counting coverage knows to look in `duel_screen.gd`.

**Fifth-branch parity gaps closed** (things the modern branch tested and
the 1997 branch did not): every point must still be spent under a free
split; the turn boundary burns and checks like any other phase boundary;
trample's own lethal-first rule holds under the whole preset; poison still
outranks a queued burn as well as the life fork.

**No new defect was found in the engine.** Two candidate seams turned out
to be documented behaviour rather than bugs: the window AUTO-SKIPS when no
seat holds a prevention effect (`_maybe_open_damage_window` — a window
whose only legal action is a prevention effect can only be passed), and a
suspended artifact keeps `cur_activated_abilities` because
`cur_statics_suspended` gates only the static passes. Both are now
asserted rather than merely commented.

**One observation for whoever owns the undo journal** (`engine/undo_log.gd`
and `MtgGame.unmake_to`, both landed the same day and in flux): mana burn
writes `p.life -= burned` and `p.mana_pool.clear()` directly in
`_advance_step` with no `_rec`, while `adjust_life` records `&"life"`. It
is probably out of scope rather than wrong — `_step_index` is not
journaled either, so a search node may deliberately never cross a step
boundary — but the two facts should be reconciled deliberately.
*Reconciled 2026-09-02: the life write now records; the pool is already
recorded at the mark.*

### Checked and found correct

`RulesOptions.IMPLEMENTED` covers all seven, so the Options screen greys
nothing out. Persistence (`Settings.rule`), the Options rows and the duel
screen's application all iterate `RulesOptions.FORKS` rather than naming
keys, so a new fork cannot be half-wired. `set_edition`/`edition`
round-trip per fork direction. The damage-assignment hold and the damage
window are sequential rather than nested (every split is committed before
`_apply_damage_requests` queues a packet), so `free_damage_assignment` and
`damage_prevention_window` cannot interleave. The window cannot be skipped
by a seat dying first: damage waits in `damage_pending` and the
state-based check never sees it.

## OPEN FINDINGS FROM THE 2026-09-01 AUDITS — nobody owns these yet

Four passes ran on 2026-09-01 (the fidelity ledger, the card audit against
the 30th-anniversary tree, a general code review, and the deck-builder
proxy/legality work). Each fixed what it owned and **reported what it did
not**, because three of the four were running concurrently and editing the
same files would have lost work.

**Those reported-only findings are collected here so they are not lost in
report files.** Full write-ups: `docs/audit-vs-s30.md` (the card audit)
and `docs/code-review-2026-09.md` (the review). Every entry below was
verified by the pass that found it — none is a suspicion.

### HIGH — a real cross-card defect

| Finding | Shape of the fix |
|---|---|
| ~~**Cost-payment records live on the PERMANENT, not the `StackItem`**~~ **FIXED 2026-09-02** — `_sacrificed_toughness`, `_exiled_mana_value`, `_discarded_types` occupied one slot each on `CardInstance.memory`, so two stacked free activations of **Life Chisel, Diamond Valley, Necropolis or Land's Edge** read each other's record. They now ride `StackItem.cost_paid`, read back through `MtgGame.cost_paid(key, fallback)` — which is set and restored around each item in `_run_effects`, exactly as `_resolving_targets` is, so a nested resolution cannot see the outer item's record either. A SPELL still keeps `sacrificed_mv` on its own memory and does not need this: a card instance is on the stack at most once. Pinned by `tests/unit/test_cost_records.gd`, whose three "two activations on the stack" tests fail against the old code and whose three single-activation controls pass against both |

### Latent — wrong today, harmless only because nothing exercises them — ALL FIXED 2026-09-02

- ~~A `"mana_color"` text change **drops every `ManaAbility` rider**~~ — `ManaAbility.retuned(was, now)` copies every script property and rebuilds only `produces`; pinned in `tests/cards/test_pool_wave49.gd` (a Plains whose ability costs a life keeps costing it after the retune).
- ~~The **layer-6 silencing pass is indexed by `changes_types`**~~ — `_rebuild_battlefield_index` now lists `silences_abilities` statics too and the general pass skips them; `tests/unit/test_layer_six_first.gd`.
- ~~**Lich** loses you the game on a bounce~~ — the leave-trigger's condition now asks for the graveyard (the zone is live when the event is dispatched); a bounced Lich with a held-up life total loses nothing, a destroyed one still loses the game. `tests/cards/test_pool_wave52.gd`.
- ~~**Martyrs of Korlis** and **Reverse Polarity** read printed types~~ — both sites in `deal_damage` read `source.is_type()`; a Grizzly Bears that a static made an artifact now feeds both. `tests/cards/test_pool_wave42.gd`.
- ~~`DecisionAgent.can_answer`'s doc comment~~ — rewritten.

### A HUMAN COULD NOT CLICK AN ABILITY AS A TARGET — FIXED 2026-09-02

`TargetSpec.Kind.ABILITY` existed, the engine enforced it and the AI could
aim with it, but the duel screen's target picker had NO CASE for the kind:
the chain entry for an activated ability draws the SOURCE permanent's card
(the only picture there is) and clicking it built a `TargetRef.card`, which
`Kind.ABILITY` refuses outright. So Rust and Ayesha Tanaka were two cards
the opponent could play and the player could not.

`DuelScreen._make_card` now takes the chain's `StackItem`, and an entry for
an ABILITY gets `_on_chain_ability_clicked` (which builds
`TargetRef.ability`), `_ability_target_state` and `_ability_highlight` — so
the entry both takes the click and LOOKS like a target, which the second
half of the gap was. The permanent's own widget on the battlefield is
untouched and still behaves like a permanent. Pinned by
`tests/ui/test_ability_target.gd`.

### Untestable by design — worth fixing anyway — FIXED 2026-09-02

- ~~**`ManaPool.pay`'s loop is bounded only by an `assert()`**~~ — the loop now `push_error`s and breaks when it finds nothing to spend. Chasing it also turned up the one real `can_pay`/`pay` mismatch: `_spendable` counted a usage key named twice on one ability twice (`tests/unit/test_mana.gd`).
- ~~`damage_marker_layer.gd:133` tests instance validity **after** the typed test~~ — order swapped.

### Small, real, and cheap — ALL FIXED 2026-09-02

- ~~The options screen writes `settings.cfg` **once per slider tick**~~ — every slider applies per tick and flushes once when the drag ends (`OptionsScreen._flush_when_the_drag_ends`).
- ~~The targeting cursor survives screen teardown~~ (`DuelScreen._exit_tree` puts the cursor back); ~~`_is_human(-1)` returns true~~ (a drawn duel now belongs to no seat and plays neither sting — `windows.c:1229-1230` has only the win and the loss); ~~`Go!` has no re-entrancy guard~~ (`SetupScreen._leaving`); ~~a stale discard pick is still marked "answered by the player"~~ (`HumanAgent.answer_discard` marks only after the stale check). Tests in `tests/ui/test_duel_screen.gd`, `tests/ui/test_setup_screen.gd`, `tests/unit/test_player_choices.gd`.
- ~~**`Ctrl+T` / `Ctrl+I` / `Ctrl+U` … bound to nothing**~~ — three arms in `_unhandled_key_input` through `DuelScreen._accelerate_toggle` (gated on `menu_toggle_live`, silent behind a dialog or modal), and the same keys shown right-aligned on both menus through `DuelOptions.menu_toggle_accelerator` + `PopupMenu.set_item_accelerator`, so they fire from an open menu too. Four tests in `tests/ui/test_card_menus.gd`.

### The one place a reference is AHEAD of us — ADOPTED 2026-09-02

- ~~**Enchanted Being** prevents *combat* damage in mage-go (`WithCombatOnly()`); ours has no combat flag~~ — checked against the higher tiers first: the Scryfall oracle, `Program/Cards.dat` and `legends.c` (`combat_damage_being_prevented`) all say COMBAT damage, so the immunity entry carries `"combat": true` and `deal_damage` skips such an entry for noncombat damage. Marble Priest ("all combat damage … by Walls") got the same flag. An enchanted Prodigal Sorcerer pinging the Being pins it (`tests/cards/test_pool_wave37.gd`).

### Two unmeasured performance candidates

Recorded as candidates, **not** as regressions, and deliberately not claimed: the review declined to call them regressions without a measurement taken off a loaded machine. Anything timed while several agents are running is timed under load — re-measure against a control before acting.

### A gap in a guarantee we rely on — CLOSED 2026-09-02

`tests/test_simplified_ledger.gd` now pins BOTH directions: every marked
file is named in the ledger, and every card a row names carries the
marker (names matched longest-first as whole words, so a row for
`Mountain Stronghold` does not vouch for `Mountain`). The paragraph below
is kept for the record of how the hole was found.

`docs/simplified-cards.md`'s invariant — *"`grep -rl SIMPLIFIED cards/sets/` must always agree with this table"* — is **one-directional**. It catches a marked file with no row; it does not catch a ROW that names a file carrying no marker. `master_of_the_hunt.gd` is exactly that case (a prose pointer, no literal token), which is why the grep never saw it. The row count (55) and the marked-file count (86) differ legitimately because rows cover families, so the counts cannot be compared directly either.

### Noted by the 2026-09-02 engine sweep — verified, harmless today, not fixed

The sweep fixed its four real findings (`tests/unit/test_engine_sweep_2026_09_02.gd`: Blaze of Glory's grant expiring, blocks and two zone helpers in the search journal, Time Vault's roll after the hold, and a refused must-block declaration writing nothing). These three it verified and left, because nothing in the pool can reach them:

- **Time Vault's untap fires `BECAME_UNTAPPED` before the turn is skipped** (`MtgGame._begin_turn`: `untap_permanent` then `_skip_turn`). Every listener for that event today is scoped to its own permanent, so the ordering has no observer; a "whenever a permanent becomes untapped" card would hear the Vault untap during a turn that then never happens.
- **Season of the Witch's census is taken after attack costs are paid** (`declare_attackers`: costs paid, then `could_attack_this_turn` is computed, and it asks `can_pay` against the pool the payment just drained). The pool's attack costs are Brainwash's {3} and Leviathan's two Islands: with two Brainwashed creatures and {3} in the pool, attacking with one leaves the other censused as "couldn't attack" — which is also what it could not do alongside the first, so the count is arguable rather than wrong. A census taken before payment would need the pool's state saved and compared; not worth it for that case.
- **Takklemaggot returns under `source.owner_id`, not its controlling seat** (`cards/sets/leg/takklemaggot.gd:119,123`). Right unless the aura had been stolen; the pool has no enchantment-steal, so it cannot be.
- **`CombatState.forget(attacker)` leaves `blocks[blocker] = attacker` standing** — reviewed and kept deliberately: the blocker remains a blocking creature (CR 506.4; glossary "Blocking Creature"), which `blocks.has(id)` is the engine's word for, and the damage step walks `all_bands()` so it deals no damage. Documented on `forget` itself.

### Noted by the 2026-09-02 card bug sweep — verified, left for a later pass

The sweep fixed its real findings (`tests/cards/test_fidelity_2026_09_02_sweep.gd`: Lesser Werewolf, the three "for as long as this remains tapped" cards, Tawnos's Coffin's per-activation records, Fork's copy memory, Halfdane's negative power, Spitting Slug under Blaze of Glory, two oracle texts). These it verified and left, each because the fix is an engine question or a rules-option fork rather than a card edit:

- **Gauntlets of Chaos under stolen control never exchanges.** `cards/sets/leg/gauntlets_of_chaos.gd` re-judges `yours` / `theirs` against `source.controller_id` on resolution — by then the sacrifice cost has reset the Gauntlets' controller (it is in a graveyard, owned by its owner), so a Gauntlets activated by a thief compares the wrong seats and finds no exchange. The right reading is last-known information of the controller AS THE ABILITY WAS ACTIVATED (CR 113.7a); the engine has no LKI of a sacrificed cost source's controller to hand a filter. An engine-level `StackItem` field for the activating controller (already `controller` on the item — the filters would need to read the item rather than the source) is the fix.
- **Magical Hack / Sleight of Mind reach LESS than Duel.hlp's ruling.** Their word-pair filters (`cards/sets/2ed/magical_hack.gd`, `cards/sets/2ed/sleight_of_mind.gd`) only offer cards whose implementation registered a `land_word` / `color_word`; Duel.hlp (1997) lets Sleight of Mind change the colour word on a Circle of Protection, which ours cannot reach. Their `docs/simplified-cards.md` rows now say so plainly instead of claiming the whole 1997 reach.
- **Glyph of Delusion's granted upkeep ability is a turn-based tick, not a trigger.** "At the beginning of your upkeep, remove a glyph counter" (`cards/sets/leg/glyph_of_delusion.gd`) is done by the upkeep step itself (MtgGame's upkeep walks the glyph counters) rather than by a granted `TriggeredAbility`; nothing in the pool can respond to it or counter it, so no observer today — a granted-ability mechanism would make it a real trigger.
- **Jade Monolith's `CardInstance.damage_redirect_to` is a single int** (`engine/core/card_instance.gd:220`): two Monoliths both naming the same creature's next damage keep only the last; the pool's decks never run two.
- **Earthbind: Oracle vs 1997.** The Scryfall oracle ("if it has flying, it loses flying") is implemented; 1997 Duel.hlp says the enchanted creature loses flying unconditionally — the difference shows only for a creature that gains flying later. A candidate `RulesOptions` fork, like the other 1997-vs-Oracle switches.
- **Axelrod Gunnarson and same-wave deaths.** A creature Axelrod damaged that dies in the same state-based wave as Axelrod himself does not trigger him (the engine has no CR 603.10a look-back for leaves-the-battlefield triggers of a source that left at the same time). Engine-level.
- **Sword of the Ages clamps a NEGATIVE power to 0** (`engine/mtg_game.gd`, the "sacrifice any number" cost record: `total_power += maxi(body.cur_power, 0)`). The CR sums the raw powers (a -2/2 Wall of Wood sacrificed alongside a 4/4 makes X = 2, not 4). A one-line engine change, held back because it lives in the cost-record code the ledger agent owns.

### Noted by the 2026-09-02 test/tool-wrapper sweep — verified, left

The sweep fixed what it owned (`run_tests.sh` now times out and fails on any `ERROR:` line, a risky test or a leak; `duel_soak.sh` keeps the .gd's exit codes and refuses non-numbers; `tools/duel_soak.gd` gained `--rules` and a "never started" stall; the Deck Lab exits 1 on a crashed or unwritten run and refuses `--seed abc`, `--best-of 1 --sideboard on` and a gauntlet that contains its own deck under test; the rules preset writes the settings file once). One coverage item it left:

- **The soak's `HumanClicker` (`tools/duel_soak.gd`) never reaches five of the human seat's paths.** It never presses number keys or the overlay's own buttons (it calls `duel._on_choice_option` directly, so `OriginalDialog.choice_line` wiring is only built and destroyed); never clicks a chain ability (`_click_ref` uses `_try_take_target`, never `_on_chain_ability_clicked`); never declares a many-to-one block (`_tick_blockers` is one attacker per blocker); never opens the graveyard (it only closes it); and never opens the territory menu, the concede dialog or the hand toggle. Each is a small addition to the clicker's tick, gated on the seeded RNG so a failure still replays; the STALL clock would already catch an overlay that opened with no labels.

## THE 2026-09-03 PLAYTEST PASS — six defects, and only one of them [QoL]

The owner played a duel and wrote down six things. Five of the six turned
out to be places where we had **diverged from 1997 without meaning to**,
and the fix in each case was to go back to what the shipped help file
says. The sixth is a genuine `[QoL]` addition. This section is the record
of which is which.

**1. The opponent's turn now runs itself.** *"I should not be clicking
through AI opponent phases, they should go automatically — as it is
opponent playing (in a human pace of course)."*

`DuelScreen._drive_advance` returned on its first line unless a STANDING
ORDER was in force, and only Done, `Run to` and `Go to` arm one. Nothing
armed one by itself, so the human's priority window in every step of the
opponent's turn — one per step, eight steps a turn — waited for a click
that carried no decision.

`[1997]`, and the licence is `Duel.hlp`, topic **Stop**, which defines a
Stop by what it takes away: *"that phase does not end until you tell it to
manually; IT CANNOT PASS AUTOMATICALLY."* A phase with no Stop on it can
therefore pass automatically, and that sentence is the only place any 1997
source says what the duel does when nobody is holding it. Where it stops
is the union of the two lists the sources give — the Phase Bar's three
(*"any required actions"*, *"your opponent does something that requires or
permits a response"*, *"a Stop on a phase"*, `Duel.hlp` topic **Phase
Bar**) plus manual p.112's Done condition (*"you are able to use a fast
effect"*), which is also the owner's own *"priority with something
castable"*. Scoped to the OPPONENT'S turn: your own turn is never passed
for you, and a hotseat duel never auto-passes at all. No new timer: the
active player takes priority first in every step (CR 117.3a), so the duel
cannot reach the human's window without going through the AI's pacing
dwell first. `DuelScreen._auto_pass_applies` / `_auto_pass_opponent_turn`,
pinned by `tests/ui/test_opponent_turn.gd`.

**2. No attackers, no combat sub-phases.** *"If no attackers are declared
the combat subphases should not show."*

The ENGINE was already right — CR 506.4 / 508.1, and `MtgGame._advance_step`
has carried *"Skip blockers/damage when no attackers were declared"* all
along (now pinned by `tests/unit/test_combat.gd`). The SCREEN was not:
`CombatBar.covers_step` is the engine's span (combat-begin to
end-of-combat) and `_update_combat` swapped the Phase Bar out on that
alone, so a combat nobody attacked in still paraded the seven-icon strip
through its attacker-fast-effects and end-of-combat steps.

`[1997]`: `Duel.hlp`, topic **Combat Bar**, is one word — the bar *"appears
during an ATTACK"*, not during combat — and topic **Combat** says when the
attack starts to exist (*"as soon as you add the first creature to the
attack, the Combat window opens"*). `CombatBar.shows_attack` is that
sentence: up while the attack is being declared, and after that only while
one exists. Pinned by `tests/ui/test_combat_bar.gd`.

**3. A permanent can be dragged where the player likes — `[QoL]`.**
*"Summoned mini cards on the table should be freely movable on the table as
per player choice — selected one over the others."*

This is the one addition of the six, and it is a small one: the 1997 table
plainly HAD movable cards (*"**Arrange Cards** straightens up the cards in
play"* — nothing needs straightening unless it can be crooked), but no
source we hold describes the gesture that moved them, so ours is ours.
Marked `[QoL]` for that reason and for that reason only.

A placement is the widget's top-left inside its own board HALF, kept per
instance id and per duel; a placed card leaves its row for an absolute
layer drawn over the rows, and the dictionary's insertion order is the
draw order, so the card last moved is on top (the owner's *"selected one
over the others"*). A press that never travels `DRAG_SLOP` is still a
CLICK, so a drag can never tap the land it moved or take it as a target.
**`Arrange your cards` clears the placements of the territory it
straightens**, which is what the command means. `DuelScreen._placements` /
`_begin_drag` / `_commit_drag` / `_place_card`, pinned by
`tests/ui/test_card_placement.gd`. **Known limit:** only the
individually-laid-out widgets can be picked up — a card inside a
five-card `CardPile` is mouse-transparent (the pile's row holder takes the
click), so lands in a pile cannot be dragged out of it yet.

**4 and 5. The 1997 casting flow, both halves of it.** *"If you click on a
spell you should be able to tap lands also AFTER, to cast it"* and *"if you
double-click a spell with a yellow name that can be cast, suitable lands
should auto-tap and the card is cast quickly."*

Both are `[1997]`, and `Duel.hlp` states them in one paragraph, topic
**Spells**: *"Any card you can cast is highlighted. Click on it to cast it.
You're prompted to provide mana to pay the casting cost. At this point, you
can draw from your mana pool, directly from land, or from any other source
you have. Any X cost is defined by the amount of mana you tap now.
Alternatively, you can double-click on a card in your hand to AUTO-CAST it.
The casting cost is taken from your available mana sources automatically.
If there is an X in the cost, all of your available mana is funneled into
the spell."* Topic **Hands** repeats it and adds *"you momentarily give up
control over which of your mana is used"*; topic **Territory** carries the
opt-out, `Don't Auto Tap`.

The Tier 2 decompilation names the routine and its flags:
`try_to_pay_for_mana_by_autotapping(player, &amt, &v46,
AUTOTAP_NO_CREATURES|AUTOTAP_NO_ARTIFACTS|AUTOTAP_NO_DONT_AUTO_TAP|
AUTOTAP_NO_NONBASIC_LANDS, v47)` at `Magic.exe:0x42e26b`, replaced by
`shandalar-src/src/patches/patch_autotap_artifacts_and_creatures.pl`,
whose header calls it *"the logic for human left-double-click mana
autotapping"*. So the gesture, the auto-tapper and the per-card lock are
all 1997's; Manalink widened the source set to artifacts and creatures and
ours is Manalink-wide, which is the set the AI planner already used.

What landed: `DuelScreen.Mode.PAYING` holds an unpaid cast open instead of
throwing it away (`MtgGame.is_unpaid_refusal` is the one refusal that is
not a mistake), with `@PROMPT_GRABMANA` entry 1's own words on the bar —
`Tap %s`. The AI's planner MOVED to `engine/mana_planner.gd` so the human
seat could use the same one rather than growing a second (`AiPlayer` now
delegates); `MtgGame.spell_payment` / `ability_payment` hand out the three
numbers `cast_spell` prices with, so an auto-tapper cannot plan a payment
the engine will not accept. `@MENU_SMALLCARD`'s `Don't auto tap this card`
went LIVE with it. Pinned by `tests/ui/test_casting_flow.gd` and
`tests/unit/test_mana_planner.gd`.

**PAYING is only ever entered while the cost is still REACHABLE** from
what the seat has untapped (`DuelScreen._pending_is_reachable`): a spell
the player simply cannot afford is refused in the engine's own words
exactly as before. That rule exists because `duel_soak.sh` found the
alternative — its fuzzer clicks an unaffordable card one try in ten, sat
in the mode, and tripped the 240s stall detector. The soak's `HumanClicker`
learned the mode too.

**6. The Situation Bar wears its own chrome.** *"In the central message I
am missing the lighter border, and the correct button, and the blue-like
text like in the photo."*

Three separate things, all `[1997]`, and all of them assembled from parts
this project already had:

* **The rule was a hairline.** `OriginalDialog._rule` drew a 1px INK
  outline at the very edge with ONE pale pixel two in from it. Remeasured
  on `Winbk_Startduelbutton` (`assets/original/button_normal.png`, 131x36):
  rows 0 AND 1 are pure `HIGHLIGHT` right across the top, columns 0 and 1
  down the left, the last two rows and columns pure `SHADOW`, and there is
  no black outline anywhere. The corners are MITRED and the art settles the
  step. `RULE_WIDTH = 2`, and every ruled ground (the bar, the Combat
  window's `attack_panel`) reads as built rather than drawn.
* **The buttons were outside the box.** Done and Cancel floated to the
  LEFT of a separate panel, so the border ran round the sentence only.
  `Duel.hlp`, topic **Situation Bar**: *"AT THE RIGHTMOST END OF THIS BAR
  is a Done button, a Cancel button, or both"* — they are at an end OF the
  bar. One `PanelContainer` now holds button, button and sentence; ours sit
  at the LEFT end because the sentence grows rightward and a control that
  moves is one you cannot aim at.
* **Done is the era's raised button, and this REVERSES a reading.** On
  2026-08-31 the owner's photograph was read as a lightened patch of the
  bar's own stone (`OriginalDialog.bar_button_texture`, which `ArrangeButton`
  still wears); *"the correct button"* settles it the other way — it is
  `Winbk_Startduelbutton`, the one piece of generic button art the 1997 game
  ships. A phone photograph of a CRT is not a colour reference; the art is.
* **The sentence was white because of us.** Its colour was already
  `OriginalDialog.HIGHLIGHT` (207,209,209, taken off that button art's own
  top rule), but the label carried `bold`, which weights every stroke with
  a hairline outline IN THE SAME COLOUR — at 16px that doubles the
  coverage and the pale blue-grey reads as flat white. The outline is gone;
  the colour never changed. Pinned by `tests/ui/test_situation_bar.gd` and
  `tests/ui/test_original_dialog.gd`.

**And one correction that came with the pass: the phase machine is
SILENT.** The owner: *"The changing phases or combat phases have no sound
by themselves. Card action and other actions that happen in phases have
sound effects."* Two call sites went: `DuelScreen` played `sfx_end_turn`
off `game.turn_number` moving, from inside `_refresh` — the coarsest phase
boundary there is — and `DuelAudio` played `sfx_untap` on
`BECAME_UNTAPPED`, once per permanent during the untap step, which is the
clock sounding. `WAV_UNTAP = 19` has no call site in any 1997 source we
hold, so nothing sourced is lost; the cost is the rare effect-driven untap
(Candelabra of Tawnos, Tawnos's Coffin), which IS an action but whose event
carries no cause to tell it apart by.

## THE TAP TURN, AND WHERE THE ANGLE LIVES (2026-09-03) — [QoL]

The owner, on the second playtest of the day: *"Mini cards do not tap
visually now? They should tap with a beautiful and smooth tween to rotate
them 90 degrees to the right."*

**Two claims, and the first one is only half true.** A tapped permanent
that the board lays out INDIVIDUALLY — every creature, and a lone land —
does turn, and has been turning through a tween since the twenty-first
pass: screenshotted 2026-09-03 at 22°, at 90°, and still at 90° after a
later rebuild. What does NOT turn is a permanent inside a five-card
`CardPile`, which is where lands and non-creature permanents live as soon
as there are two of them — and a land is the card a player taps most. The
pile draws each card in a `Button` holder CLIPPED to its title bar, so a
card turning inside one would be sliced; it is the same population, and
the same holder, as the *"card on board still cannot be dragged"* limit
already recorded under defect 3 above. **Neither the angle nor the press
reaches a piled card.** Both were left open here and BOTH ARE CLOSED
BELOW — the press in "THE BOARD DRAG, AND WHY THE FIRST PASS MISSED IT",
and the angle in "THE TAPPED CARD IN A PILE", which answers the question
this paragraph declined ("what IS a strip stack?") instead of making the
strip turn.

**The `[QoL]` is the tween, and only the tween.** `Duel.hlp`, topic
**Tap**: *"Tapping a card means turning it sideways. This indicates to you
and your opponent that the card effects have been temporarily used up."*
Both RESTING looks are 1997's; no source we hold shows an in-between
frame, so the sweep between them is ours. 0.22s, `EASE_OUT`, `TRANS_QUAD`: the shortest span in
which a 90° sweep still reads as a sweep at 60Hz (13 frames), with most of
the travel in the first third so the click feels answered at once, on the
mildest curve that does it. `TRANS_QUAD` and not the `TRANS_BACK` it began
as, because the curve has to be MONOTONE — see below.

**The angle moved into `MiniCard`, where the card that knows it is tapped
can own it.** `MiniCard.tap_turn()` / `turn_angle()` / `turn_holder()` and
the static `_turn_book`. Three things the move buys:

* **The turn is RESUMED across the board's rebuilds.** The battlefield is
  immediate-mode: tapping a land for mana fires several refreshes inside
  the 0.22s, and each one frees the turning widget and builds another. The
  book records WHEN each tap happened (keyed by the instance's object id,
  holding nothing but ints — CONTRIBUTING.md forbids a `static var` that holds a
  `CardInstance`), so the replacement starts at the angle its predecessor
  reached instead of jumping or restarting. A card tapped a minute ago
  arrives square with nothing animating, which is what keeps the table
  from spinning on every state change. This is also why the ease must be
  monotone: an overshoot resumed from inside its own overshoot wobbles.
* **It is interruptible.** A second turn KILLS the first rather than
  joining it, so a card tapped and untapped inside the 0.22s, or a board
  that re-flows mid-sweep, retargets instead of being left at 47°.
* **Headless lands it at once.** A headless run draws no frames, and a
  tween there is state half-applied: measured on the live screen the same
  day, the same board read 0° immediately after the refresh, 79.9° one
  frame later and 87.5° after two — `test_the_whole_table_is_one_card_size`
  has been asserting "0° or 90°" against that lottery and passing on the
  luck of a long first frame. `MiniCard.animate_turn` is off when
  `DisplayServer` is headless, so the FINAL angle is true whether or not
  anything is ever drawn. Tests turn it back on to exercise the tween.

A parent declares "you are the thing that turns" by giving the card a
CENTRE PIVOT — nothing else in the game gives one, the fan tilts about a
card's bottom-middle and a pile leaves the default corner — and
`MiniCard.turn_holder()` builds the plain holder the turn needs, because
`Container.fit_child_in_rect` zeroes a child's rotation outright on every
sort. Pinned by eleven tests in `tests/ui/test_mini_card.gd`.

**Still to land: `DuelScreen._make_widget` should call the two methods
instead of keeping its own copy of the arithmetic** (`_tapped_seen`,
`TAP_TURN_SECONDS`). The file was another agent's while this was written,
so both copies run today; they are the same curve from the same clock, and
the card's own turn is created last and therefore wins every frame. The
patch is in the pass report.

## THE THREE DEFAULT STOPS (2026-09-03) — [QoL], and 1997 shipped three of its own

The owner, playtesting the auto-advance that landed the same day: *"My main
phase precombat, combat and main phase post-combat should be selected to
stop (red dot) by default. If nothing happens on a phase (no card needs it)
and I DON'T have it selected for stoppage by red dot — then it should go
automatically even for me."*

**WHAT THE ORIGINAL SHIPPED, established by disassembly.** The question
"did 1997 pre-mark any phases?" had never been asked here, and the answer
is in `Magic.exe`'s duel-options loader, not in any string table.
`option_PhaseStoppers` lives at `0x62c374` — the address
`shandalar-src/src/manalink.lds:62` links Manalink *against*, which is the
proof the array is the EXE's and not Manalink's — and the loader zeroes all
of it and then sets exactly three cells, in both the
no-registry-key path (`0x45e0b4`) and the no-`PhaseStoppers`-value path
(`0x45df38`):

| write | cell | seat (`src/defs.h:2362` — `HUMAN = 0`, `AI = 1`) | phase | our slot |
|---|---|---|---|---|
| `mov BYTE PTR ds:0x62c388,1` | `[0][0x14]` | yours | `PHASE_MAIN1` | YOURS 3 |
| `mov BYTE PTR ds:0x62c392,1` | `[0][0x1E]` | yours | `PHASE_MAIN2` | YOURS 5 |
| `mov BYTE PTR ds:0x62c3b9,1` | `[1][0x1F]` | the opponent's | `PHASE_DISCARD` | OPPONENTS 6 |

and when a stored value IS read back it still forces your own pre-combat
main on (`0x45deea`: `movsx eax,[0x62c388]; or al,1`) — that one Stop was
**mandatory** in the original. The stored form is two rows of 37 `S`/`-`
characters, so 1997's default serialises as
`--------------------S---------S-------------------------------S-----`.

*Tier note, because it matters:* no 1997 `Magic.exe` survives in any tree
here — both copies (`shandalar-src/Program/`, 2011; `shandalar-xp/MagicTG/`,
2009) are Manalink builds. The loader is **byte-identical between them**
(md5 `4292a393158b515e44fe76027b498773` over `0x45DA10..0x45E0E2`) at the
same virtual addresses despite different section layouts and seven years
apart, it sits interleaved with the fourteen 1997 `DuelOptions` value
names, and Manalink's own C never writes the array except two debug-mode
save/restore sites. So it is Tier-2-grade evidence — the binary read back —
taken off a Tier-3 build, and it is stated as such.

**OURS IS THE OWNER'S SET, and the divergence is `[QoL]`:**
`PhaseStops.DEFAULT_SLOTS = [3, 4, 5]` on the lower half — we **add** your
combat icon, and we do **not** ship the opponent's Discard stop.
`PhaseStops.ORIGINAL_1997_YOURS` / `ORIGINAL_1997_OPPONENTS` carry the
original's set beside ours so the choice stays one edit wide, and
`tests/ui/test_phase_stops.gd` pins the difference rather than leaving it
to be rediscovered by disassembling `Magic.exe` twice.

**THE SETTINGS CONTRACT, which is the part that could quietly go wrong.**
"Default" has to mean the ABSENCE of a stored value — writing defaults into
a player's file is a bug this project has shipped once (the "fan" hand
style) — but "the player cleared every Stop" also has to survive. So:
no key at all means the three defaults; a stored row means
exactly what it says, **including four zeroes**; and `save()` clears the
key when the marks equal the defaults and writes them otherwise. A player
who deliberately clears all their Stops does not get them handed back next
duel. (The stored row gained a fifth int, a generation stamp, on
2026-09-04 — see the next section for the report that forced it.)

## WHY THE THREE DOTS DID NOT REACH THE OWNER (2026-09-04) — the same report, twice

The owner, a day after the three defaults landed and were shipped: *"My
main, combat and second main still do not have red dots enabled by default
— fix. I still have to click through opponent phases."* The suite was
green, the defaults were right, and the exported build carried them. What
was wrong was that **the owner's profile was not a fresh one**, and the
contract above has no way to tell a stored row apart from a decision.

`~/.local/share/godot/app_userdata/Shandalar/settings.cfg` held

```
phase_stoppers=PackedInt32Array(0, 0, 8, 0)
```

— index 2 is the `Half.YOURS` / `Bar.PHASE` lane and `8` is `1 << 3`, the
single Stop on your own Main pre-combat. That is the one the owner set by
hand with `Mark this phase to always stop`, back when the game shipped no
defaults at all and setting one yourself was the only way to have one. It
has outranked the three defaults ever since, because "a stored row is the
player's decision" cannot distinguish *a choice made against the defaults*
from *a row written by a build that offered none*. Fed that exact row, a
duel drew one dot (`PhaseBar._dots` visible at index 11 alone); with the
row deleted it drew three (11, 12, 13). Both measured from a clean profile
in a real duel, 2026-09-04.

**THE FIX is a generation stamp** — `PhaseStops.DEFAULTS_GENERATION`, a
fifth int on the persisted row. `save()` appends it; `load_saved()` treats
a row without it (or with an older one) as a leftover rather than an
opt-out and hands back [`default_masks`]. The rest of the contract is
untouched: no key still means the defaults, and a **stamped** `[0, 0, 0,
0, 1]` still means "I cleared them all and meant it". Bump the constant
only to RE-OFFER a changed default set; it discards the choice a profile
had made, which is a thing to do deliberately and rarely.

**THE TEST THAT WAS MISSING.** Every earlier test in
`tests/ui/test_phase_stops.gd` either cleared the key first or built a
`PhaseStops` by hand, so all of them measured a profile that had never
been played, and all of them passed while the owner's bar showed one dot.
The new ones feed `load_saved` the owner's row verbatim and then ask the
**bar** what it draws (`PhaseBar._dots`), not the model what it holds.

**THE COMBAT DOT is drawn but never consulted**, and this is worth knowing
before anyone edits it. `DuelScreen._phase_key` sends every step from
`COMBAT_BEGIN` to `COMBAT_END` to the **Combat** bar
(`CombatBar.covers_step`), so no phase key is ever `[half, Bar.PHASE, 4]`
and the middle of the owner's three dots — `Your Main phase (declare
combat)`, Phase Bar slot 4 — marks a phase nothing asks about. It is not
missed in play: what actually holds the duel at combat is
`_required_action_reason`'s *"attackers must be declared"*, which stops it
dot or no dot. Pinned by
`test_the_middle_default_is_a_dot_the_combat_bar_answers_for`. Fixing it
properly means either keying the un-attacked combat steps to the bar that
is actually on screen (`CombatBar.shows_attack`, not `covers_step`) or
defaulting `Bar.COMBAT` slot 0 as well — the second would stop the duel
twice at the same moment, so it is the first or nothing.

**THE DEV TREE WRITES THE PLAYER'S PROFILE, and that is why a manual
deletion did not stick.** `run_tests.sh`, `duel_soak.sh` and every tool
run in this checkout share `user://` with the exported game — same project
name, same `app_userdata/Shandalar`. Two things were observed on
2026-09-04: `tests/ui/test_phase_stops.gd` writes
`PackedInt32Array(0, 0, 8, 0)` into the live file for the length of one
test (it restores it, but a run killed in that window does not), and
`Settings` keeps a cached `ConfigFile` for the process's life, so ANY
later `set_value` rewrites the whole file from that cache and puts back
rows deleted behind its back — `hand_stack_pos` was seen moving from
`1279.1146` to `646` between two agents' test runs, carrying
`phase_stoppers` along untouched — and half an hour later the owner's
chosen `Portrait1` and their dragged hand-window position were *deleted
outright* by a third run.

**FIXED the same day.** `run_tests.sh` and `duel_soak.sh` now export
`XDG_DATA_HOME` (`$TMPDIR/shandalar-test-data`, overridable with
`SHANDALAR_TEST_DATA_HOME`), which moves `user://` out of
`~/.local/share/godot/app_userdata/Shandalar` for every run they start.
Safe because the whole suite is green from an empty one — 234 scripts /
4089 tests and a clean soak, measured before the change went in — since
`GameSkin` falls back to `res://assets/original` in a dev checkout and
nothing else reads the player's own files. `build_release.sh --skin` is
deliberately NOT isolated: linking the skin into the player's profile is
its whole job.

## THE OPPONENT'S TURN: "permits a response" READ LITERALLY (2026-09-04) — [1997]

The second half of the same report, and NOT a consequence of the first:
with the owner's row loaded, nothing at all is marked on the opponent's
half, so no Stop was doing it. Measured in a real duel from a clean
profile: across eleven turns the opponent's turns needed **five** clicks,
and every one of them was a moment with something on the chain.

`_auto_pass_applies` clause (b) stopped for ANYTHING on the chain, so every
spell the AI cast cost the player a Done click even with an empty hand and
tapped-out lands. `Duel.hlp`, topic **Phase Bar**, says *"if your opponent
does something that requires or PERMITS a response… movement through
phases stops so that you have a chance to respond"* — and a chain item you
hold no answer to permits nothing. The clause now asks
`DuelScreen._could_respond`: an instant in hand or an activated ability
whose cost the **untapped sources** could still reach
(`MtgGame.could_afford`, the same query the castable highlight uses).
Potential mana, deliberately, not the floating pool
`_has_affordable_fast_effect` reads — passing a window the player could
still tap a land into would take a play away from them, and no saving of
clicks is worth that. Same duel, same seed, after: **zero** clicks on the
opponent's turns; the only clicks left are your own two main phases, which
is what the red dots are for.

## THE BLOCK THAT WAS NEVER DECLARED (2026-09-04) — [1997]

The owner, from a playtest: *"Opponent attacked with Mahamoti Djinn (5/6)
and I blocked with Giant Spider (2/4). Spider was not killed and all damage
went to my life directly."* Two wrongs in one combat, and both of them are
what an **unblocked** attacker does.

**THE ENGINE WAS NOT WRONG, and that had to be established before anything
was changed.** `tests/unit/test_combat_evasion_2026_09_04.gd` is that
sweep, twenty-five cases: reach against flying, fear against a black and an
artifact blocker, landwalk with and without the land, protection, the
printed "can't be blocked by" clauses, both power thresholds, the
open-ended "can't be blocked except by" predicate (Elven Riders) — and
every damage-assignment path: one blocker, two, trample over one and over
two, defensive banding handing the division to the DEFENDER, a
first-striking attacker, a first-striking blocker, the 1997
free-division fork (`RulesOptions.free_damage_assignment`), the attacking
**AI** dividing its own damage, a DecisionAgent that answers with
`DAMAGE_TO_PLAYER` and is overruled, and the three ways a blocker can
LEAVE between the declaration and the damage (bounced, killed, or removed
from combat the way regeneration removes it — CR 509.1h / 701.15a).
Twenty-four of the twenty-five passed on the UNMODIFIED engine; the
twenty-fifth is the one engine change this pass makes (below). Twenty-five
whole AI-vs-AI games were mined for the same invariant on top of that —
"a blocked attacker damaged a player" — and every raw hit turned out to be
two copies of one card, one blocked and one not. The Djinn's damage can
reach a player only when `CombatState.blocked_attackers` never learned
about the block.

**SO THE BLOCK WAS LOST BETWEEN THE SCREEN AND THE ENGINE, and here is
how.** `DuelScreen._combat_lineup` puts a creature that has been PICKED UP
into the Combat window's shield lane — it leaves its territory the moment
you click it, which is right and is what the window is for. But a creature
that is merely HELD is not blocking anything, and nothing on screen said
so: the Situation Bar went on showing whatever it had said before, a
second click that missed the attacker was swallowed in silence, and
**Done then declared NO blockers and threw the held creature away without
a word**. A gesture that ended one click early therefore *looked* exactly
like a finished block — same lane, same place, only the red arrow
missing — and the attacker arrived unblocked. Measured before the fix, on
the owner's own pairing: the Spider held, `_combat_lineup` listing it as a
blocker, `_on_done()` leaving `combat.blocks` empty and the Djinn
unblocked. Two more doors into the same room: a **tapped** creature could
be lifted into that lane and then have every attacker click refused, and
a double-click on your own blocker put it down again in silence.

**THE ORIGINAL SPEAKS THREE SENTENCES HERE AND WE WERE SAYING ONE.**
`@PROMPT_DEFENDWHOM` (`shandalar-src/Program/UIStrings.txt:993`) is

```
Block which attacker?
Illegal block.
That isn't an attacker.
```

and `@PROMPT_CHOOSEBLOCKERS` (`:1139`) is `Choose blockers` / `Block which
attacker?` / `Illegal block.` We had `Illegal block.` and neither of the
others — and the missing one, *"Block which attacker?"*, is precisely the
sentence that tells a player their block is not finished. The 1997 game
asks it from the moment a blocker is in hand until it is aimed.

**THE FIX — one line of rules predicate, the rest in `DuelScreen`:**

* `_pick_block` says `Block which attacker?` while a creature is held, and
  puts the standing `Combat phase: Choose blockers.` back the moment it is
  aimed or put down;
* a click on something that is not an attacking creature answers with
  `That isn't an attacker.` instead of nothing;
* a creature that can legally block **none** of the declared attackers is
  refused at the pick-up (`_cannot_block_anything`, which asks
  `CombatState.block_illegality` — the engine's own rule, only asked at a
  new moment) rather than being lifted into the blocker lane to stand
  there as a blocker that every click refuses. The gate skips a creature
  that already has a block pencilled in, so the take-back gesture stays
  reachable for a multi-blocker that has run out of legal targets;
* `CombatState.block_illegality` answers honestly for a blocker that is
  not on the battlefield (CR 509.1a). `MtgGame.declare_blockers` always
  checked the zone itself, so no illegal declaration was ever accepted —
  but the PREDICATE said yes, and the predicate is what the pick-up gate
  and the AI's block planning ask. A creature card in the defending
  player's HAND could therefore be picked up as a blocker, and the
  declaration it produced was refused **as a whole**, taking the player's
  real blocks down with it;
* and `_on_confirm` will not declare while a blocker is held: the first
  Done puts it **down**, keeps every block already made, and says
  `<name> is not blocking. Press Done again to declare.`; the second
  declares. One extra click, never a lost block. Refusing outright was the
  other candidate and is worse: a Two-Headed Giant of Foriys with no
  second attacker to take would never be able to leave the step, which is
  a hung duel and exactly what `duel_soak.sh` exists to catch.

**WHY 4089 TESTS DID NOT CATCH IT.** Two blind spots, and they are worth
naming exactly rather than in general.

*The engine's.* `tests/unit/test_combat.gd` does assert *"blocked attacker
deals no player damage"* — for a 2/2 blocking a 2/2, and again for
trample's excess. Those are its only two, and both are GROUND creatures.
Its evasion tests stop at LEGALITY (`test_ground_creature_cannot_block_flyer`
declares and reads the refusal; `test_flyer_can_block_flyer` checks the two
graveyards) and never look at the life total that follows. The word
`REACH` does not appear in the file at all. So the whole matrix of
"evasive attacker, legal blocker, whose damage went where" was untested,
and a blocked flyer punching through would have left every one of the 4089
green. The new engine file asserts the defending player's life in every
case it runs.

*The screen's.* Every existing block-gesture test
(`tests/ui/test_block_picker.gd`) drives a gesture that COMPLETES: pick,
aim, done. Nothing anywhere asked what the screen does with a gesture that
stops halfway — which is the only kind a real hand makes — so the state
the owner was actually looking at had no test at all.

## AN UNSTOPPED PHASE RUNS ITSELF, ON EITHER TURN (2026-09-03) — [1997]

The second half of the same ask, and it stopped being an extrapolation the
moment `Readme.txt` was read properly. **MicroProse's own** Readme for
*Duels of the Planeswalkers* version 3.0, 14 January 1998, present twice
and byte-identical (md5 `660aa64926f1f293e2c38f7dfa750955`) in
`shandalar-xp/MagicTG/` and `s30/assets/text/` — under **Dueling Table**,
`:70-80`, and note that every example in it is a card of YOUR OWN on YOUR
OWN turn:

> *"If you do not put a Stop (the red marker) on a phase, play will BYPASS
> THAT PHASE without bothering to ask you if you want to use optional
> effects (a Brass Man's untap or Land Tax, for example). This is a handy
> way to prevent the duel from bogging down, but if you are not careful,
> you could accidentally miss an opportunity."*

and its FAQ (`:645-659`) states the safety rule with equal force:

> *"You must put a Stop marker on your upkeep phase for the program to stop
> there. OTHERWISE, THE GAME WILL ONLY STOP AT YOUR UPKEEP PHASE FOR
> MANDATORY EFFECTS (such as a creature getting a counter for Unstable
> Mutation or taking damage for Cursed Land)."*

So `DuelScreen._auto_pass_applies` dropped its *"your own turn is yours to
drive"* clause and is now seat-agnostic, with the safety list checked
BEFORE any Stop is consulted: a required action (attackers, blockers,
discard, damage division, the prevention and regeneration windows, a held
`awaiting_choice`, any mode but NORMAL), something on the chain the
player can actually answer (2026-09-04 — see above), a modal or
a pending cast, a Stop, and an affordable fast effect. One further clause
was added with it — `_rested_at`, the phase a `Run to` / `Go to` / `Done`
order came to REST in. *"The duel blithely skips through all the
intervening phases, THEN STOPS"* (manual p.116): naming a destination is
telling the duel manually where you want to be, so the automatic pass must
not walk on in the frame it arrives. Without it the second half of the
feature ate the first, on the opponent's turn as well as your own.

**ONE READING WE DID NOT TAKE.** The same FAQ answer adds that a Stop means
*"the program will stop there IF YOU HAVE A VALID ACTION"* — i.e. a marked
phase with nothing to do in it might still pass. `Duel.hlp`, topic
**Stop**, is flatly unconditional (*"that phase does not end until you tell
it to manually; it cannot pass automatically"*), it is the more specific
source, and a Stop that sometimes ignores you is worse than one that always
waits. Recorded, not built.

## THE PAUSE WINDOW (2026-09-03) — [QoL]

*"When a player types Q or ESC keys during a duel, a menu should pop up
with buttons: concede the duel (you lost), exit duel (return to duel
config), return to main menu, exit game"*, then *"And another button:
return to game. Pressing Q or ESC again would close the menu. The menu
should be named Pause on top!"*, and *"This Q or ESC button menu should
reuse the brown portraits window with buttons on the bottom."*

Squarely ours: the 1997 duel has no pause and no menu on any key —
`Duel.hlp`'s topic **Territory** puts leaving behind **Concede** (*"You
must confirm this decision"*) and **Minimize**, and `Esc` in the original
is *"just like Cancel"*.

**Which is why Esc keeps that job first.** The precedence, pinned as three
tests: the window is open → Esc closes it; something to cancel → Esc
cancels it (the 2026-09-02 ladder, `_can_cancel`, unchanged); nothing
pending → Esc opens the window. `Q` carries no 1997 duty and so toggles
unconditionally.

**The marble is shared, not cloned.** `DuelIntro`'s board became
`VersusPanel` — the art, the two wells, the portrait fallback, the pale
lettering, an optional title in the 59px band above the wells — and both
windows extend it, so the next person to move a well moves one of them.
The five entries do not fit a column in the 104px band below the seat
names (five 30px rows plus gaps is 166px), so they are laid out as the safe
one alone on its own row and then two rows of two; checked on a
screenshot, not on arithmetic. `Return to game` holds focus, so the reflex
press is the harmless one.

**And "Pause" is a promise about time, not a label.** The window counts as
a modal (`_modal_open`), so the automatic pass above cannot fire and no
card, phase icon, territory or order button answers; and
`_maybe_schedule_ai` neither arms the AI's pacing dwell nor lets an
already-armed one act while it is up. Unlike `DuelIntro` it carries no
timer of its own. `tests/ui/test_duel_pause.gd` advances the clock under
the open window and asserts the turn, the step and both life totals are
where they were.

## THE BOARD DRAG, AND WHY THE FIRST PASS MISSED IT (2026-09-03)

The owner, on the build that already contained the drag: *"Card on board
still cannot be dragged across the board. My hand stack can."*

The first pass recorded one limit — *"a card inside a five-card `CardPile`
is mouse-transparent, so lands in a pile cannot be dragged out of it yet"*
— and that limit turned out to be the whole feature from the player's
seat. **Lands, artifacts and enchantments group into a pile the moment
there are two of them**, and a real board is mostly lands, so "nothing on
the board moves" is exactly what a creature-only drag looks like.

Diagnosed with a throwaway probe under Xvfb that synthesised a real
press-move-release over four permanents and printed which node saw what.
Before: a creature among three moved, a tapped creature moved, a piled land
did not arm at all, a tapped piled land did not arm at all. The reason was
one line — `CardPile._make_card` gives each row a holder `Button` carrying
`pressed` and nothing else, with a `MOUSE_FILTER_IGNORE` `MiniCard` inside
it as the picture — so the press that starts a gesture reached nothing that
knew how to start one. **The existing tests all drove `_begin_drag` /
`_commit_drag` directly and set `_dragging` by hand, so not one of them
asked the only question that mattered.**

`populate` now takes an optional `look_cb` and connects it to each row's
holder; `DuelScreen._on_piled_card_input` owns the gesture, arming
`_begin_drag_node` on the ROW (not on the pile — `_layout_root` would hand
back all five cards), taking the holder's clip off the moment the press
becomes a real drag so the whole card slides out of the stack, and
clamping the drop by a whole card rather than by a 17px title strip. The
pile's own `pressed` still taps the land: a press that never travels is
still a click. All four probe cases move now, and the board case is pinned
in `tests/ui/test_card_placement.gd` at the level that broke — is there a
`gui_input` connection on the row at all, and does a press arm the gesture
on the row rather than the pile.

**This corrects one sentence in "THE TAP TURN" above:** the press now does
reach a piled card. The ANGLE still does not, and never will — a piled
card is clipped to its title bar. What a strip stack IS, and what a tapped
card looks like inside one, is answered in "THE TAPPED CARD IN A PILE"
below.

## THE TAPPED CARD IN A PILE (2026-09-03, ANSWERED AGAIN 2026-09-04) — [QoL]

**Read the second half first: the 2026-09-03 answer below was OVERTURNED
the next day, by the owner and by the sources together.** It substituted a
lettered cue for the 90° turn, on the premise that a pile row was 17px of
CLIPPED title bar and a card turning inside one would be sliced. The
premise was ours, not 1997's — the clip was our own drawing choice — and
the owner rejected the substitution on sight:

> *"Upon tapping my lands — they show a blue tapped symbol — ok, they are
> darker — ok, but they do not rotate 90 deg. Please fix this — they must
> look tapped! Make a smooth tapping tween anim."* (playtest, 2026-09-04)

and then settled what happens to the substitute:

> *"Cards should tap even in the stack — and show tapped symbol along with
> being darker."*

So: **all three cues at once, on every tapped permanent**, and the pile
learned to turn. The research below stands unchanged and is what the new
answer is built on — it is the same evidence, read the right way round.

The original problem, for the record. The other half of the owner's *"Mini
cards do not tap visually now?"*, and the half the tap-turn pass above
left open on purpose. **A tapped permanent inside a five-card `CardPile`
had no cue at all.** Measured on
the live screen: an unpiled permanent turns (0° -> 22.3° mid-sweep -> 90°,
tween and all) and a piled one reads `tapped=true rot=0.00 parent=Button`.
The documented substitute was broken too — the lettered mark sat at
`offset_top = 21` on a card whose covered row is clipped to
`CardPile.OVERLAP` = 17, i.e. **off the bottom of every covered row** — so
what actually signalled a tapped land under another land was a 25% dim on
a 17px strip and nothing else. Lands, artifacts and enchantments go into a
pile the moment there are two of them, so this was most of what a player
taps.

### What the sources say, and it is more than "nothing"

Searched fresh and wider (the register in `Provenance.md` decides the
order). **No 1997 source shows or describes a COVERED tapped card in a
territory stack** — the earlier note stands. But the search returned two
Tier-1 negatives and one mechanism, and together they settle the *shape*
of the answer:

* **`Duel.hlp`, topic **Tap**:** *"Tapping a card means turning it
  sideways. This indicates to you and your opponent that the card effects
  have been temporarily used up."* Rotation is the ONLY rendering the help
  ever ascribes to tapping, and it says so twice. The help has no
  **Stack**, **Grouping**, **Small card** or **Card states** topic at all;
  topic **Territory**'s only layout item is `Arrange Cards`.
* **`@CUECARD_SMALLCARD` (`UIStrings.txt:732-743`) is the game's own list
  of everything a small card can be MARKED as** — ten entries: `Damage to
  player`, `This card will untap`, `Damage: %d`, `Card is not controlled
  by owner`, `Is a target`, `Can't target this`, `Is a target, can't
  target again`, `Dying`, `Summoning sickness`, `Phased`. **"Tapped" is
  not one of them.** Nor is there a tap toggle in `@MENU_TERRITORY` (25
  entries), `@MENU_SMALLCARD` (8) or `@DIALOG_DUELOPTIONS`.
* **The 1996-97 art ships no tap glyph.** `MagicTG/Cardart/` is the whole
  overlay set — `Abilities`, `Canttarget`, `Cardcounters`, `Damage`,
  `Dying`, `Manastripes`, `Manasymbols`, `Poison`, `Summon`, `Target`,
  `Willuntap` — and a whole-tree search for `*tap*` returns exactly
  `Willuntap.pic`, `Tap.wav` and `Untap.wav`. **`Willuntap.pic`
  (1996-11-27) is the contrast that proves the point:** when 1997 wanted
  to flag a tap-RELATED state it shipped a dedicated `.pic` *and* a
  cue-card string. For "tapped" it shipped neither, because tapped is read
  off the card's orientation.
* **The mechanism** (Manalink's C against the exe's own addresses —
  below the decompilation, which is a URL in `Provenance.md` and not in
  this tree). `draw_smallcard_normal` (`shandalar-src/src/functions/
  windows.c:1591-1689`) paints stripes, P/T, the summon spiral, the
  oubliette, the dying cracks, abilities, damage and counters: **the
  tapped bit of the display bitfield (`windows.c:62`, bit 2) is never
  consulted.** Tapping changes nothing about a card's painted CONTENT.
  What it changes is orientation, inside a SQUARE window
  (`set_smallcard_size`, `windows.c:1088`: `width = height =
  mainwindow_width / 8`), 90° clockwise — solve the hit-test's own
  un-rotation at `windows.c:637-647` and the card's top edge maps to the
  window's right column, its LEFT edge to the top row. And a 1997 pile is
  not a clipped widget at all: `update_hand_window`
  (`windows.c:1108-1178`) `MoveWindow`s full-size card windows stepped by
  a global offset and z-orders them, so a covered card is OCCLUDED, never
  cropped.

**Which yields the deflationary reading, and it is worth stating because
it is probably the truth: the original did nothing.** If a covered card
keeps the strip its neighbour leaves showing, and the neighbour is always
placed 17px BELOW it, then a covered TAPPED card shows a sliver of its
LEFT border — *a nameless strip*. The disappearance of the name is the
only "cue", it is an accident of the rotation, and it is exactly the kind
of ambiguity that explains why the help never mentions the case and why
`Arrange Cards` exists at all. **We are not porting that**, and the
2026-09-04 answer does not have to: the nameless strip comes from
stepping DOWNWARD past a card whose title bar has moved to its right-hand
edge, so the fix is to step LEFT instead. See "The cascade" below. Where
the sources run out the convenience is ours and is labelled, hence
`[QoL]` — but note how little of it is convenience: 1997's card window is
SQUARE (`set_smallcard_size`, `windows.c:1088`), so 1997 could rotate
inside a stack for free and ours (132x106) cannot. The cascade is what
paying for that difference costs.

(Tier 3, for the record and for nothing more: **s30** has no pile — it
shrinks the horizontal step and sorts untapped before tapped
(`duel.go:1452-1463`) so a rotated silhouette is never obstructed, i.e. it
sidesteps the question. **mage-go**, in a terminal, hits the identical
problem — a name-only row — and answers it with `name + " (T)"`
(`internal/tui/view.go:473`). Two reimplementations, two different dodges,
no authority in either.)

### The first answer (2026-09-03), and what was right about it

**A PILE IS A LIST, AND A LIST CANNOT TURN — so it says it in the row.**
A tapped card that is drawn where it cannot rotate wears two things at
once, in the one band a covered row shows:

1. **The title bar goes DARK** — `MiniCard.TAPPED_WASH`, a 55% wash over
   the bar, drawn OVER the mana slashes and UNDER the name. Over the
   slashes on purpose: `Duel.hlp` calls a tapped card one whose *"effects
   have been temporarily used up"*, and a land's slashes ARE the effect it
   has spent, so an untapped Mountain shows a bright red slash and a
   tapped one a dull one. That is a colour difference the eye finds
   without being asked, which is what makes the cue work AT A GLANCE down
   a stack of five. Under the name, because a 17px row has exactly one job
   and it is being readable.
2. **`TAPPED_MARK` — `(T)` — in front of the name**, which is what makes
   it unambiguous once the eye lands. It is not a new mark: it is the one
   that was already there, moved off the status line (`offset_top = 21`,
   clipped away) and into the bar (`offset_top = 2`, always visible). The
   name gives way by `TAP_MARK_W` and takes the room straight back on
   untap, so every marked row starts on the same rule and they read as a
   column. ASCII for the reason the thirty-eighth pass measured: `⟳` is
   glyph 0 — missing — in all three fonts this widget can end up with.

Both halves of that were right and both survive. What did not survive was
the sentence they were derived from.

### The answer that stands (2026-09-04): THE CASCADE

**A pile is a list, and a list CAN turn — one entry at a time.** Two
changes, and the second is the whole idea.

**1. The cards are whole again.** Every row is a full `MiniCard` drawn at
its own place and OCCLUDED by the row in front of it (`z_index`
ascending), never cropped. That is 1997's own mechanism, and the line
numbers were already in the research above: `update_hand_window`
(`windows.c:1108-1178`) `MoveWindow`s full-size card windows stepped by
one global offset and z-orders them with `BringWindowToTop`. Our
`clip_contents` on a 17px holder was the divergence, and it was the entire
reason a card in a pile could not tap: a rotation inside a 17px window is
a rotation nobody can see. Hidden and collapsed piles (the opponent's
hand, the player's rolled up) keep the clipped strip, because they have no
front card to end them and a whole card would spill out of the window.

**2. The stack steps along each card's own TITLE EDGE.**
`CardPile.layout_boxes` — pure, no widgets, no frame, so the geometry is
measurable headless. A flat card wears its title bar across the TOP, so
the next card goes 17px DOWN and the bar stays showing: the list every
pile has always been. A turned card wears the same bar down its RIGHT
edge — rotate 90° clockwise and the card's top edge maps to the
right-hand column, which is exactly the map `windows.c:637-647` inverts to
hit-test a tapped card — so the next card goes 17px LEFT instead, and the
bar stays showing there too. Cross-axis the two cards share a centre line.

What that one rule buys:

* **a pile with nothing tapped is laid out exactly as it always was** —
  one column, 17px apart, 132x174 for five. Untapped boards and every
  hand window are untouched;
* **a pile with everything tapped is that same pile turned 90°
  clockwise** — five cards stepping left, each showing its own title bar
  as a vertical column, 174x132. Which is what `Duel.hlp`, topic **Tap**,
  says tapping looks like, said of a whole stack;
* **no row is ever hidden.** Every card keeps a FULL 17px of its own
  title bar — name, mana slashes, wash and mark — clear of every card
  drawn after it, in all 32 arrangements of five cards. The "nameless
  strip" the deflationary reading predicted is exactly what stepping left
  avoids;
* **the cost is bounded and was measured, not hoped for.** Worst
  footprints: 200x132 (the first four tapped) and 132x200 (only the front
  card tapped), against 132x174 flat — at most 68px more in ONE direction,
  never both, because room spent going left is room not spent going down.
  The live board under Xvfb, seven lands and three creatures out: the
  lands row is 670px wide with 264 in use, and 102px of vertical slack sit
  under it before the creature row. Both directions are paid out of slack
  the board already had.

**The tween is the one that already existed.** `MiniCard.tap_turn()` —
0.22s, `EASE_OUT`, `TRANS_QUAD`, monotone, interruptible, resumed across
the board's rebuilds from the static `_turn_book`, landed at once when
headless. The pile writes no animation of its own; it only says WHERE.
The pivot contract is unchanged and now has one implementation,
`MiniCard.aim_turn(card, box)`, which `turn_holder` and `CardPile` both
call: size stays `MiniCard.SIZE` (a tapped card is TURNED, never resized),
pivot is the card's middle, position centres it on the box its parent
reserved. `turn_holder`'s own holder also stopped being
`MOUSE_FILTER_STOP` — a bare `Control` defaults to STOP, and this one was
a 4px ring of dead pixels round every tapped permanent on the board.

**And all three cues now ride every tapped permanent**, on the owner's
instruction. `MiniCard.shows_tap_mark()` is simply `wants_rotation()`; the
mutual exclusion is gone, and with it the subtle bug it caused (the cue
depended on the PIVOT, which a parent sets between the constructor and
`_ready`, so a card built flat and turned a moment later came out
lettered — `_ready` had to re-derive the whole cue to cover it). The three
do different work at different distances: the turn reads across the table,
the wash reads down a column of overlapping bars (a dull mana slash among
bright ones), the letters read when a card is half covered. All three ride
the card, so they turn with it and a turned card carries its bar down its
right-hand edge.

Rejected on the way, with the reason:

* **Keeping the strips and letting only the FRONT card turn**: it is one
  turned card in five, and four lands that still do not look tapped. This
  was the 2026-09-03 shape of the problem and it is what the owner
  rejected.
* **Giving a tapped row the full room to turn and reflowing the stack
  around it** (the brief's second option): a fully-visible turned card is
  132px of height instead of 17, so five tapped lands cost ~660px against
  the 102px of slack the board actually has. Dead on the measurement.
* **A separate turned SHELF for the tapped cards**: it reorders the list,
  so a land jumps out of its place when it taps and back when it untaps —
  and `_rebuild_field` deliberately arranges BEFORE it slices into piles
  so that membership does not re-shuffle every time a land taps.
* **Sorting untapped before tapped**, which is s30's dodge
  (`duel.go:1452-1463`): the same objection, plus it is a dodge — s30 has
  no pile to solve.

Pinned by seventeen tests in `tests/ui/test_card_pile.gd` (new) and the
rewritten §2.9b block of `tests/ui/test_mini_card.gd`. The pile file
carries the geometry — the flat pile unchanged, `pile_height` and the
cascade agreeing, the title-edge step, the transpose, "no row is ever
hidden" and the bound over all 32 arrangements, the real pile reserving
exactly its cascade — and the STRUCTURE the mouse depends on, because
**headless Godot does no GUI picking at all**: the drag hook still finds a
`MiniCard` as the DIRECT child of every holder `Button`, the pile PASSes
(its empty corners belong to the board), the holder STOPs, the card
IGNOREs. The live press was verified under Xvfb instead: pressing each of
seven rows across two piles on its own title edge, turned and flat, armed
the gesture on exactly that card — which is what proves the overlapping
full-size holders hit-test in drawing order — a press that travelled
carried a TURNED covered land out onto the free layer still at 90°, and a
press that did not travel still tapped the land under it. Photographed
too: a stack with two tapped lands, the same stack mid-tween at 50°, five
tapped lands as the transposed pile, a realistic board, and a turned land
dragged out of one.

## THE PLAYFIELD BOUNDARY FOR MOVED CARDS (2026-09-04)

The owner, on the build that already contained the drag and the pile
drag: *"The mini-cards can be moved out of the playfield and hide — make
the playfield boundary for mini cards so they cannot possibly be moved
and hidden out of the playfield!"*

**There WAS a clamp, and it was green, and it was wrong in three ways at
once.** `_place_card` pinned the widget's TOP-LEFT inside
`layer.size - span`, with `span` read off the node being dragged
(`max(node.size, MiniCard.SIZE)`). Everything that node did not know then
walked a card off the table, and the half's `clip_contents` made "off the
table" mean INVISIBLE:

1. **A card that taps LATER.** `MiniCard.turn_holder` is 114x140 against
   a card's 132x106, so a card parked flush with the bottom of its half
   while upright grew 34px DOWNWARD the moment it tapped.
2. **An enchanted card.** The aura fan is drawn at `-AURA_PEEK.y` per
   attachment ABOVE the host's own box (`_make_widget` reserves width for
   it and deliberately overflows in height), so a host at the top edge
   had its auras cut off.
3. **A RESIZE.** A placement lives for the whole duel in half
   coordinates, and nothing re-measured it when the half changed size.
   Under this project's `canvas_items` / `expand` stretch a 1920x1080
   window is a 1422x800 canvas and a 1280x800 window is 1280x800 — the
   board really does lose 142px.

**The bounds now, and why.** A placed card must lie WHOLLY inside the
visible table of its OWN half (`_placement_bounds`): the half inset
exactly as its rows are (`BOARD_INSET` / `BOARD_INSET_V`), and nothing
subtracted for chrome. `_placement_span` is the
box a card ever sweeps: the UNION of upright and turned (so a placement is
a promise and a card does not shuffle itself when it taps) plus the aura
fan's upward overflow. `_half_of` keeps every drop in its owner's
territory, which is a rules statement and not a nicety — a card in the
other half would say something false about who controls it.

The rest of the chrome needs no bound and the code says why: the zone
column, the seat portraits and the phase/combat bar are SIBLINGS of the
board in the root `HBoxContainer`, beside the halves and never over them;
the Situation Bar floats over the seam but is ~36px against a 106px card,
cannot hide one, and already overlaps the opponent's creature row in the
ordinary layout; and the FAN hand is a row INSIDE the half, under the free
layer, so a card dropped over it is drawn on top of it and stays visible.

**And the boundary is now visible while the drag happens**, not a
snap-back on release: `_drag_motion` clamps the card as it moves, so it
stops dead at the edge and the pointer runs on without it. `_rebuild_placed`
re-clamps and writes back on every rebuild, and each half's `resized`
re-measures every placement it holds (`_reclamp_placements`, deferred —
freeing the layer's children inside a layout notification is how a duel
screen gets a condition error at teardown).

### ...AND THE HAND WINDOW IS NOT PART OF IT (2026-09-04)

The first cut of the bounds above ALSO subtracted the floating hand
window's band (`_hand_reserve`, shared with the rows'
`_apply_hand_reservation`), on the reasoning that the stack hand is
opaque, taller than a card and draggable — the one piece of chrome that
can swallow a mini-card whole. The owner's next playtest: *"When I move
my hand stack, also other cards move on the table. They shouldn't."*

`item_rect_changed`, which drove the reserve, is emitted when a `Control`
**moves**, not only when it resizes. Every drag of the hand window
therefore redrew the boundary and shoved the placements that fell outside
the new one. Measured with a real press-move-release on the window's grip
under `xvfb-run`: one 480px drag fired `_reclamp_placements` twelve times,
moved two of three placed cards onto the same x, and slid all four of the
row's lands 385px. (The other suspect, `_arm_pile_drag` walking the hand
window's own `CardPile`, was refuted in the same probe — zero handlers are
armed on it.)

The owner settled the policy: *"Yes, the hand stack can be present
anywhere — only cast mini-cards are bound to the playfield."* So
`_hand_reserve`, `_apply_hand_reservation` and `HAND_GAP` are gone, each
half keeps its full inset width wherever the window sits, and nothing on
the board listens to the window. A card the window covers keeps its place
and is uncovered by dragging either object — the player owns both.

**The rule this leaves, which outlives the diff: a placement is a
statement of intent.** A re-clamp is a rescue for a card that would
otherwise be off-screen and unreachable — so it fires on a half's own
`resized` and nothing else. It is never a tidy-up, and no piece of chrome
the player is free to move gets to trigger it. The maths was right the
whole time; the trigger was wrong.

Proved with a throwaway probe under Xvfb: four real press-move-release
drags shoved hard past each corner of the player's half land at
(8,6) / (546,6) / (8,254) / (546,254) — the tapped one 114x140 and still
inside — and a card parked at x=916 in the wide canvas is pulled to
x=774 by the narrow one with no click at all. Nine assertions in
`tests/ui/test_card_placement.gd` fail on the old code.

## THE AUTO-CAST NOBODY COULD REACH (2026-09-04)

The owner, on the build that contained the whole casting pass of
2026-09-03: *"I cannot double-click a castable card and lands do not
automatically auto-tap."*

**The third defect this week whose whole cause was which node receives a
press.** `DuelScreen._auto_cast` had exactly one caller — `_on_card_look`,
which `_make_card` connects to a [MiniCard]'s own `gui_input`. That covers
the battlefield and the FAN hand. **It does not cover the STACK hand**,
which is the original's window, the default (`Settings.hand_style`) and
the one the owner plays with: a `StackHand` is a `CardPile`, and a pile
draws each card as a `MOUSE_FILTER_IGNORE` picture inside a holder
`Button` carrying `pressed` and nothing else. Nothing between the pointer
and the card ever looked at `double_click`.

Measured under Xvfb with real press/release/press/release on the row.
Before: `could_afford=true`, `Highlight.CASTABLE` (the yellow name was
never the problem), the row's `pressed` fired twice, `_pending_card` was
the spell and `mode` was PAYING — with `tapped=0` and `stack=0`. The
second click was an ordinary click for the second time. After:
`tapped=2`, `stack=1`, `mode` back to NORMAL.

`DuelScreen._arm_hand_auto_cast` / `_arm_hand_row` / `_on_hand_card_input`
own it, armed from the duel screen because `card_pile.gd` belongs to
another pass. It hangs on the pile's `child_entered_tree` rather than on a
sweep after `populate`, and that is load-bearing: **the first click
rebuilds the board, which frees the very row the second click is about to
land on**, and `StackHand._set_collapsed` re-populates without going
through `_rebuild_hand` at all. `accept_event()` on the second press stops
`BaseButton` seeing it, so the auto-cast is not followed by a stray single
click; the FIRST press is untouched, which is what keeps a click a click.

`tests/ui/test_casting_flow.gd` gains five tests, three of which fail on
the old code — including the invariant a headless suite CAN check (every
row of the hand window carries a `gui_input` connection, and keeps it
across a rebuild and a collapse) and the gesture driven through the row
widget the player presses rather than through the screen's internals.

## THE ENLARGED CARD'S LETTERING (2026-09-04) — [1997] on the colour, [QoL] on the outline

The owner's playtest: *"Large card generator: card text, type,
illustrator, power/defense are hardly readable in black — make text
bigger, white with black border, and readable as original."*

**The tension the brief expected — fidelity against legibility — did not
survive the measurement.** Four of the five strings on the Showcase (name,
type line, illustrator credit, P/T) ride the card's OWN BODY, and the 1997
frame art paints that body dark on five of its six colours. Mean luma of
`assets/original/card_frame_*.png` over the exact rectangles those labels
occupy — and those files are `Cardart/Cardbk_*.pic`, dated **1997-01-22**,
i.e. **Tier 1**:

| frame | type strip | bottom border |
|---|---|---|
| white | 188 | 184 |
| blue | 113 | 104 |
| red | 82 | 73 |
| artifact | 68 | 64 |
| green | 49 | 43 |
| **black** | **22** | **19** |

Our ink was `Color(0.10, 0.08, 0.06)` — **luma 25** — and the class doc
said why: the frame is a *"light marble frame"*. That was measured on
`Cardbk_White.pic` alone, and it is the only frame it is true of. Luma 25
on luma 19 is not hard to read; it is invisible. **So the 1997 art itself
rules dark ink out**, and white-on-the-body is not a deviation from 1997 —
it is the only reading of these files. `Duel.hlp`'s **Background** topic
names the region as what it is: *"The background of a spell card
(experienced players will remember this was called the border in previous
editions) serves as an easy visual reminder of the color of the spell."*

Manalink's replacement for the original `drawcardlib.dll` (Tier 3) agrees
on all four strings and on the fifth:

    TXT_AND_SHADOW(fullcard_title_txt, "Title", 255,255,255, 47,47,47, 4,4);
    TXT_AND_SHADOW_ALL_DEFAULT(fullcard_powertoughness_txt, ... , fullcard_title_txt);
    TXT_AND_SHADOW_ALL_DEFAULT(fullcard_type_txt, ... , fullcard_title_txt);
    get_cfg_colordef(config, &config->fullcard_rulestext_color, section, "RulestextColor", 47,47,47);

(`shandalar-src/src/drawcardlib/config.c:817-822`.) **The RULES TEXT is the
other case entirely**: it stands on the frame's own light plate — luma
126-223 across the six frames — which is exactly the ground 1997 used, so
it keeps 1997's `47,47,47` and only grows. This is the brief's "same
ground, just too small" branch, and it is the one string that gets no
outline (the original draws it with a bare `SetTextColor`; no shadow key
for it exists anywhere).

**[QoL] — the outline.** The original backs its body text with a SHADOW,
offset (4,4) in its 800x1200 logical space, which its isotropic map scales
to about **1.4 px** on our 428-tall card. We spend that as a symmetric
outline of 3 instead (4 for the P/T pair, matching `MiniCard`'s), the
standing house finding of 2026-09-03: a one-sided shadow dies on a pale
ground, and the white card body IS a pale ground.

### The sizes, and the ratio behind each

`Duelart/Duel.dat`'s `[fonts]` table is the original's mechanism — the
1997 exe carries the `Fonts`/`size`/`bold`/`font` key literals — but **both
surviving copies of the file are dated 2004 and they disagree**
(`shandalar-xp/MagicTG/…:23-37` says 17/15/18/14 for
title/subtitle/PT/text; `shandalar-src/Program/DuelArt/…:34-58` says
14/13/16/14). The MagicTG copy is the one ported, for a reason internal to
the layout: `cfg_font` makes each `size` a cell of `4 * size` in the same
800x1200 space the rects live in, and on those numbers the `Type` rect
(height 60) is **exactly one** subtitle cell and the `Powertoughness` rect
(height 72) **exactly one** P/T cell. A strip precisely as tall as the
line it carries is a layout drawn around those fonts. Against the
1152-unit card frame that gives a share of the CARD'S HEIGHT, which is the
portable number — the same port `MiniCard.PT_FONT_SIZE` made ("0.241 of
the card's height"):

| element | 1997 cell | / 1152 | on our 428 | was | now |
|---|---|---|---|---|---|
| name | 68 | 0.0590 | 25.3 px | 13 | **22** |
| type line | 60 | 0.0521 | 22.3 px | 11 | **20** |
| P/T | 72 | 0.0625 | 26.8 px | 15 | **26** |
| rules text | 56 | 0.0486 | 20.8 px | 12→10 | **18** |
| illustrator | — | — | — | 9 | **13** |

The rules text is the one sized by LINE COUNT rather than by the raw
ratio, because that is the invariant the layout states and the one both
copies of `Duel.dat` agree on: `Rulestext` is 336 units tall over a
56-unit cell — **exactly six lines**. Ours holds six too, and not a
seventh. The illustrator credit is the one element **no** source sizes
(neither file has a `sizeBigCardIllus`), so it is [QoL]: three quarters of
the rules line, the smallest thing on the card, as the printed card sets
it.

### Three bugs the measurement turned up on the way

* **Godot's default `line_spacing` is 3**, and the old fitting arithmetic
  never counted it — so six lines of text needed the height of nearly
  seven, and a card as ordinary as Nova Pentacle lost its last line. The
  spacing is now explicitly 1 (1997 advances one font cell a line and adds
  no leading) and every fit measures `lines * height + (lines-1) *
  spacing`.
* **`Expand` grew the box for every card**, where `Duel.hlp` says the text
  area grows *"when necessary"* and the code that implements it agrees —
  it measures the text and moves the top up by exactly the overflow
  (`fullcard_exclude_expanded_text_box`). `TEXT_TOP_EXPANDED` is now a
  ceiling on that growth, not the one expanded position, so a Forest with
  Expand on keeps its printed box.
* **A grown box left dark text on bare art.** The original blits the
  frame's own rules-plate band into the enlarged box
  (`fullcard_expand_text_box`, source band `ExpandTop` 6050 /
  `ExpandHeight` 3220 = 60.5-92.7% of the frame image); ours now cuts the
  same band out of the `Cardbk` texture and stretches it. That is what
  keeps 1997's dark rules ink safe at the expanded size.

### What it costs, measured on real Labels over all 897 cards

685 cards read at the full 18 in the unexpanded box and 7 lose a line to
the clip the original also does; **with Expand on, 810 read at 18 and NOT
ONE card in the pool loses a line.** Every card name and every type line
now fits its strip (three did not before the ladders were given a last
step). `tests/ui/test_card_preview.gd` pins all of it.

## THE SMALL-CARD CATALOGUE'S SIX DEFECTS (2026-09-04) — and what it left open

`docs/card-states.md` catalogued every mark a `MiniCard` can wear and
found six defects. All six are fixed and each entry in its §5 says how.
The two shortest summaries worth having here:

* **Three of them were one shape** — a fact the widget could draw that
  nothing handed it: `CardInstance.face_down` never reached
  `MiniCard.face_down` (a masked Illusionary Mask creature showed its
  name, art, tooltip and mana stripes); `MiniCard.castable` was set in
  exactly one file, so the FANNED hand never yellowed a castable card;
  and the help screen still taught a `+N aura` chip deleted two passes
  ago.
* **One was about what a `StyleBox` can express.** `StyleBoxTexture` has
  no border width, so with the 1997 skin imported `COMMITTED` and
  `TARGET_CHOSEN` rendered byte-identically and s30's one width
  distinction was invisible. `MiniCard._highlight_ring` draws the width
  over the frame instead.

### Left open, deliberately — nobody owns these yet

* **A face-down permanent does not draw its 90° TAP TURN.**
  `MiniCard.wants_rotation()` refuses a face-down card, and it was
  written that way when nothing could set the flag. Tappedness is PUBLIC
  information about a face-down permanent, so this hides something it
  need not — an omission in the safe direction, unlike the leak it sits
  beside, and it is why it was not changed in the same pass. Whoever
  takes it also has to decide what a turned card back looks like in a
  `CardPile` cascade.
* **CR 708.2: a controller may look at their own face-down permanent.**
  Ours are card backs to every seat, because `engine/` has no per-seat
  visibility model — no `may_look_at(pid, inst)`, no viewer on
  `MtgGame`, and `CardInstance.face_down` blanks the card's
  characteristics for everybody. `DuelScreen.hidden_hands` is the nearest
  thing the UI holds and it is EMPTY in hotseat and in an AI-vs-AI demo,
  so keying off it would draw every masked creature face up in those
  modes. The day the engine can answer, this relaxes at one line in
  `DuelScreen._make_card`.
* ~~**`GameSkin._texture_cache` has no bound.**~~ **CLOSED 2026-09-06**:
  the card art has its own cache, `GameSkin._art_cache`, least-recently-
  used and capped at `ART_CACHE_CAP` = 256 pictures; missing pictures are
  remembered apart so they cost a search and no slot. Measured under
  Xvfb, a browse of 600 arts: **267 MB held (256 kept) against 608 MB
  unbounded** — the 909 MB at the whole pool becomes a ceiling of about
  270 whatever is browsed. See THE 2026-09-06 PASS. (As written: a static
  dictionary that never evicted — 682 MB across the pool's 897 crops, 909
  MB with mipmaps; the mipmaps were +33%, the cache was the cliff.)

## THE DECK BUILDER PLAYTEST PASS (2026-09-04) — eight items, five of them [QoL]

The owner drove the Deck Builder and asked for six things, then two more
after the next drive (items 5c and 7 below). Items 1 and 7 have 1997
answers — 7 is the manual quoting itself at us — and the rest are `[QoL]`
and are marked so at every site. This is the record of what each one
diverges from, so nobody has to re-derive it.

**1. ONE BED, LOOPING — [1997] in shape, [QoL] in the choice of bed.**
*"Deck builder: only the first song you now use should loop over."* The
original loops exactly one track on this screen (`deckdll.cpp:2040-2056`,
slot 1 with `SND_SetSndMarker`), so LOOPING ONE BED **is** the 1997
behaviour and what shipped before this — a shuffle of all twenty-seven —
was not. What is `[QoL]` is WHICH bed: 1997 draws it with
`RANDRANGE(1, 19)` on every entry to the screen, and the owner asked for a
stable one. `MusicLibrary.single_for` therefore takes the LIBRARY's own
first available candidate. The player's Options track choice still
outranks both.

**2, 3. THE ARROWS AND THE COUNT — [QoL].** The 1997 Inventory has a
scroll bar and nothing else (*"At the bottom of the Inventory area is a
scroll bar you can use to move through your inventory"*), and its card
count is a sentence in the cue-card line, not a numeral in the corner. Both
additions are ours; the corner numeral's size is now a ratio of
`MiniCard.SIZE` rather than a number, which is the rule the duel screen's
own numerals already follow.

**4. LOADING FROM ANYWHERE — [QoL].** `@LOADDECKDIALOG` lists the game's
own decks and nothing else; the original moved decks between machines by
copying `.dck` files in DOS, which is why `@DECKLOADERROR` and
`@DECKEXISTS` are about file NAMES. A file browser onto the whole machine
is ours, and it shares one implementation with `Import deck`'s own door.

**5. THE Q/Esc MENU — [QoL], on the duel's own precedent.** The 1997 Deck
Builder answers no key with a menu; `@DECKSURFACE_STANDALONE` is a
RIGHT-CLICK mini-menu and still is. This window is the same idea as
[DuelPause] (2026-09-03, recorded above), and it keeps Esc's 1997 cancel
duty ahead of itself, which is the one part of it that is not a
divergence.

**5b. THE TWO SCREEN-SCOPED SOUND SWITCHES — [QoL].** The original has
exactly two audio settings, `&Music` and `Sound &Effects`, they are
GAME-WIDE, and they are persisted by name (`cfg_write_int(global_cfg_music
? 1 : 0, "Music")`). This screen's own pair is a second, narrower pair
underneath them, and the precedence is stated in [DeckAudio]: the global
switch can only ever take sound away. A player who silences the builder
still hears a duel.

**5c. ITS GROUND MOVED THE NEXT DAY, and the lesson is the ink's, not the
window's.** It shipped on the blue knot `Winbk_Changetext.pic` the owner
had named. The era's tan list colour is illegible on that ground — a knot
is a PATTERN, light and dark inside a single glyph — so the pass that
built it changed the INK instead: pale letters under a hard dark outline.
The owner drove it and still could not read it: *"Deck builder — window
upon Q or Esc key-press: texture makes the text unreadable. Change to sand
from the main menu!"* (2026-09-04).

So the ground was wrong, not the ink, and this is the SECOND time that
diagnosis has been made about this project in two days — the first was
`UiChrome`'s own (*"all white text is unreadable on sand-colored menu
boxes"*, 2026-09-03), which settled the rule the whole game now follows:
`Winbk_Options` sandstone with `UiChrome.INK` on it and `UiChrome.ACCENT`
for emphasis. The window wears exactly that now (`DeckBuilderScreen`'s
`MENU_PANEL`), so the main menu, the Options screen, the Help screen,
`explain_popup` and this one are one voice. **The generalisation worth
keeping: a lettering trick that has to be invented for one window is
evidence about the GROUND.** Two tests hold the pair together
(`tests/ui/test_deck_menu.gd`), because moving one without the other is
how it was unreadable in the first place.

**6. THE STONE GRIND — [QoL], and the only sound this project ships.**
Every other cue in the game comes out of the player's own copy of the 1997
install. This one is the owner's sample, trimmed; it therefore lives inside
the pack rather than in the skin, and its source and licence are recorded
in `Provenance.md` under "Our own assets" — including what could NOT be
established about the original freesound.org entry.

**7. THE GAME'S OWN DECKS ARE NOT OVERWRITABLE — [1997], and the strongest
1997 answer in this whole pass.** *"Default decks of the game should not be
overwritable by the deck builder! (To keep provenance of deck builds from
1997.)"* (owner, 2026-09-04). The manual says the same thing at p.148 —
*"If you load and change one of the creature decks used in the full game,
you must save your version of the deck under a new name."*

Half of it was already true and nobody had said so: `DeckStore.save`
builds its path out of `USER_DIR` and nothing else, so a `res://decks`
file was never reachable. The half that was MISSING is shadowing — save a
changed `Cleric` as `Cleric` and `user://decks/cleric.deck` appears beside
`res://decks/1997/originals/cleric.deck`, two decks with one name and no
way to tell which is 1997's. **Refusing the name is what keeps the
provenance**, and refusing it is what the manual asks for; the Deck
Builder turns the refusal into a save-as with the manual's sentence and a
name that works (*"My Cleric"*, in the field, selected). The comparison is
by `DeckStore.file_stem` over BOTH the shipped file name and the shipped
TITLE — 233 of the 317 shipped files have a title that does not slugify to
their file name, and the Load list shows the title. Pinned door by door,
plus an md5 of all 317 shipped files before and after every door, in
`tests/ui/test_deck_provenance.gd`.

### Left open by this pass

* ~~**`Import deck` does not ask before it replaces the deck on the
  surface.**~~ **CLOSED 2026-09-04** by the provenance pass, which owned
  every other door that can lose a deck. `_open_import_dialog` is now
  `_confirm_discard(_show_import_dialog)`, the same shape `Load deck`
  has, and `tests/ui/test_deck_provenance.gd` pins both halves (it asks
  when there is unsaved work, and it does not when there is none).
* **The 1997 deck surface's fifth sound slot has no file.** `deckdll.cpp`
  loads a cancel cue on slot 5; neither `DuelSounds/` nor `Sound/` holds a
  `Cancel.wav`, so [DeckAudio] plays nothing for a dismissed dialog rather
  than borrowing a sound that was never that.

## THE FRONT DOOR PLAYTEST PASS (2026-09-04) — two items, both [QoL]

> *"Play a suitable soothing music at the main menu."*
> *"Splash screen could be a bit longer."*

**1. THE SHELL'S BED — and the provenance answer that made it `[QoL]`.**
This was asked as a *"what did the original play?"* question before it was
a taste question, and the survey settles it: **the 1997 shell screen
played no music at all.** The finding is written up in `Provenance.md`
("The shell screen's audio"); in short, the shell belongs to `Magic.exe`
(`wndproc_MagicShellClass`, `Magic-trace.c:4124`, entry `4CC770`), that
program's whole audio vocabulary is the 68-entry ONE-SHOT table at
`windows.c:1181-1266`, and the only shell entries in it are seven cues
(`defs.h:2232-2252`) of which the five page cues measure 2.8-6.1 s —
stingers, one per `@SHELLSCREEN_*` page. Every looping bed literal in the
original lives in `Shandalar.exe`, the adventure. So there is nothing to
be faithful TO here, and the bed is ours.

**WHICH BED, and it is a judgement made without hearing it.** Nobody
working on this can listen to audio, so all 27 beds were MEASURED instead
— duration, peak, RMS, crest, the spread between the 10th and 90th
percentile of a 20 ms loudness envelope, transients per second,
zero-crossing rate and a high-frequency energy ratio. `music_location_15`
wins on the axes that mean "soothing": 0.06 transients/s over 36.0 s
(joint lowest of the twenty location beds), 816 zero-crossings/s and
-19.2 dB of high-frequency energy (second darkest in the library), 8.3 dB
of loudness spread and not one frame below -50 dBFS, and the second
longest bed there is, so the loop wraps least often.

**The two obvious guesses measure WORSE, which is why the numbers were
worth taking.** `Tmplmus1` — a temple, so surely calm — is the SHORTEST
bed at 24.9 s, spends only 43% of its length within 3 dB of its own median
and carries an 18.2 dB crest: a struck, bell-like shape, not a sustained
one. `Ucastle` (the blue castle) is **30.6% silence**, an ambience file
with holes in it, which would loop as a tune that keeps stopping.

The bed is deliberately NOT the Deck Builder's `music_location_1` — which
is measurably the steadiest bed of all and already spoken for — because
sharing it would mean the same track restarting from zero every time the
player crossed between the two screens. `MainScreen.MENU_BEDS` is the
list, in measured order, and **changing the owner's mind about it is one
line**.

**2. THE SPLASH — one project setting, no code, no scene.** Godot 4.7.2
registers `application/boot_splash/minimum_display_time` (int, hint
`0,100,1,or_greater,suffix:ms`, default 0), which was checked against the
pinned engine rather than assumed, so the picture is held by the ENGINE
where it already lives. **No scene was added ahead of `run/main_scene`**,
so the title screen is still the first thing that runs and everything that
assumes so — `tools/screenshot_tour.gd`, the `--quit-after` smoke in
`build_release.sh` — is untouched, and there is nothing a player could get
stuck in and need to skip.

**THE NUMBER IS MEASURED, because the setting is not free.** Under Xvfb
with `--quit-after 3` on this project, the wait is **added** to the
engine's ~1.0 s start rather than overlapped with it: 0 ms reaches the
title screen in 1.5 s, 1000 ms in 2.0 s, 1500 ms in 2.5 s, 2000 ms in
3.0 s. The owner asked not to make the game slower to reach than about two
seconds, so **1000 ms** is the largest value that fits — it doubles the
time the artwork is up (~0.5 s to ~1.0 s) and holds the total at 2.0 s. It
also makes that second DETERMINISTIC: on a machine faster than this one
the load shrinks and, without the setting, the splash would shrink with
it. A headless run pays the same wait (0.6 s on the suite and the soak,
once per process), which is the price of the setting being the engine's
and not ours.

Both items are pinned in `tests/ui/test_title_screen.gd`, including the
ceiling on the splash wait — a later "make it a bit longer again" that
pushed past two seconds would fail a test rather than pass a review.

## THE 2026-09-06 PASS — three playtest reports, two AI capabilities, one window

> *"analyze all work done and all recent patches also and whole codebase
> and do a bug hunt, optimization pass and implement any key and
> low-hanging fruit features that would really benefit the player and
> improve the game. Do also an AI game engine pass over everything."*

Three things the owner saw at the table came first; then the two AI
capabilities the control sweep had left open with numbers against them;
then one `[QoL]` window the design doc had promised since v1 and the
audio cue it turned up. Everything measured is measured the sweep's way:
the candidate on ONE seat against the shipped pilot with the knob off on
both, same seeds, and a control pair on decks the change cannot touch
that must land byte-identical.

### The three playtest reports

**1. The deck builder's left edge (photo).** *"Backgrounds still do not
align from the left side."* The deck's block of columns was CENTRED in
its area — a leftover strip split between both ends, which is right for
the Inventory's teal field — and the quilt of carved frames was laid from
where the block started, so on a 2560-wide window thirty pixels of bare
weave stood between the sideboard's edge and the first carving. Under it
a SECOND copy of the weave, grown three pixels past the area "so it reads
as a panel", repeated a 32x32 tile on a different phase from the one
beneath it and drew a hard seam three pixels off the quilt. Both gone:
a quilted surface lays its carvings from the area's own top-left corner
edge to edge, the first card sits half a gap inside the first frame
(`CardArea._lead`), the leftover is on the RIGHT under a partial column
of carvings, and the sideboard's slate takes the deck area's own left and
right edges so the two panels read as one column. `tests/ui/
test_deck_builder.gd` pins the lead, the edge and the seam's absence.

**2. Untamed Wilds asked for its land twice, and the land never came.**
The library picker opens BEFORE the cast, parks the pick on the
`HumanAgent`, and the resolution spends it. Paid from a full pool that
worked (the Demonic Tutor test of 2026-09-02 pays that way). Paid ONE
LAND AT A TIME it did not: the engine emits `state_changed` from inside
`cast_spell`, `_refresh` answers it with `_retry_payment`, and with the
cast in `Mode.PAYING` that found the pool moved and submitted the SAME
cast again — from inside the first, with the card already on the chain.
The engine refused the echo, the refusal cleared the pending cast the
way a real refusal does, and the parked pick went with it, so the
resolution asked all over again and the answer had nowhere to land.
`_submit_pending` is not re-entrant now (`_submitting`), and
`tests/ui/test_tutor_payment_2026_09_06.gd` plays the cast both ways —
tapping lands one at a time and by the double-click's auto-tap — through
the live screen, asserting one ask, one Mountain on the battlefield.

**3. "A 1/1 blocker kills a bigger creature"** — the owner asked for this
to be *checked and asserted* on creatures wearing several auras. It was
checked and it holds: `tests/unit/test_combat_auras_2026_09_06.gd` pins
that a body's LIVE toughness — printed plus every aura, every
until-end-of-turn pump, every counter — is what its damage is measured
against, in every combat shape the table produces: a single block, a
gang block, first strike, the 1997 damage-prevention window with a human
on both seats, and the human dividing their own damage. The rules half
of the same afternoon's aura reports (all 1326 creature-aura pairs, and
an aura on a permanent its caster does not control) is in
`tests/cards/test_auras_2026_09_06.gd`. The Hurr Jackal report — the
prevention window with no life change — is still waiting on the owner's
answer to one question (did life not move at all, or drop by 2?) and is
not closed by this.

### The AI: two capabilities the control sweep had priced and left

**4. A sacrifice is a price, not a refusal — `AiProfile.pays_sacrifices`.**
The sweep's own row: *"2,733 battlefield-turns of Strip Mine produced
zero activations"*, because `_ability_available` refused every ability
with a sacrifice rider outright. It is a CAPABILITY now, gated like
`plays_engines` (Sorcerer and Wizard have it; the Apprentice and the
Magician not holding it is the same honest weakness as the Apprentice
never holding an instant), and nothing it gates is card-named:
`_sacrifice_price` says what the body that goes is worth — the source
itself for "Sacrifice this", the cheapest legal body for "Sacrifice a
<desc>", both on `_own_value`'s scale, where a land counts the lands
still in hand and carries a surcharge when losing it would leave the
hand's biggest spell uncastable — and the scorer's bar says whether the
effect buys more. `_best_victim` looks past creatures for it: a land, an
artifact or an enchantment is only ever *finished* by removal, so those
are shopped when the effect `removes` and priced by `_victim_value`,
which is what lets a Strip Mine take the dual over the basic and a
Scavenger Folk the Disk over the Ring. The pump paths — combat, shield,
attack-time — still do not see a sacrifice-priced ability at all, and
must not: a Fallen Angel or an Atog read as a pump eats the board one
Serra at a time, which is what it did before the gate existed. "Sacrifice
any number" (Sword of the Ages) is one optional ask per body and stays
outside the model. `tests/ai/test_ai_sacrifice_2026_09_06.gd`, 11 tests.

**MEASURED** (2,000 games a pair, seed 11, `wizard` on seat A against
`wizard:pays_sacrifices=off` on both):

| Matchup | null | candidate |
|---|---|---|
| Dracur (Strip Mine, Sinkhole, Ice Storm) mirror | 49.8% | **52.0%** |
| Dracur vs Big Green | 25.3% | **27.2%** |
| Sedge Beast mirror | 48.5% | 49.0% |
| Big Green vs White Knights (no sacrifice card in either) | 527/1000 | 527/1000 — **byte-identical** |

The instrumented 200-game run against Big Green: 45 Strip Mine
activations where there were none, and the three sorceries around it
cast at the same rate (Ice Storm 187 vs 191, Sinkhole 134 vs 135, Stone
Rain 168 vs 166) — the Mine is played on top of the land destruction,
not instead of it.

**5. The life a tap costs — `ManaAbility.pain`, `AiProfile.minds_pain`.**
The sweep's other open row: The Deck dying on turn 27.8 with 8.4 lands
untapped, and *"4 City of Brass paying a life a tap over 28 turns is the
first thing to instrument next"*. Instrumented: 3.3 self-inflicted
damage a game against 17 from the opponent. **A tax, not the loss** —
the 96% against White Knights is the matchup (The Abyss cannot target a
White Knight), not the mana. The tax is still real and the planner had
no model of it: every point of mana was equally free, and City of Brass
was deferred by colour-flexibility ordering for the wrong reason. Now
a mana ability can say it `hurting(1)` (City of Brass, Elves of Deep
Shadow), `ManaPlanner.cheapest_source_first` sorts pain LAST, the planner
never taps a source whose damage meets our life total
(`_pain_excluded`, `{id: true}` — the same shape as the 1997 `Don't auto
tap this card` mark), and `_try_activate` prices the life an ability's
taps would cost at `_life_price` (cheap at 20, dear under 8) against
what the ability buys. On for EVERY profile — an Apprentice that kills
itself tapping for a Grizzly Bears is not weak, it is broken; the knob
exists so the Deck Lab can run the null. A first cut that REFUSED every
painful source at the sink measured the same within noise (7.2% /
13.4%) but would not draw off a Jayemdae Tome through a City at 20 life,
plainly the trade to make, so the sink prices the life instead.
`tests/ai/test_ai_pain_2026_09_06.gd`, 10 tests.

**MEASURED** (2,000 games a pair, seed 11, `wizard` against
`wizard:minds_pain=off` on both):

| Matchup | null | candidate |
|---|---|---|
| The Deck vs White Knights | 6.2% | **7.1%** |
| The Deck vs Big Green | 12.6% | **13.1%** |
| Saltrem Tor (four Cities) mirror | 50.6% | 50.7% |
| Saltrem Tor vs Big Green | 23.4% | 23.6% |
| Big Green vs White Knights (no painful source) | 1076/2000 | 1076/2000 — **byte-identical** |

Small, in the direction the model says, and the point was never the
percentage: it was the planner tapping the LAST City at 1 life for a
spell that could wait, which the engine allowed and the null run does.

**The Deck Lab learned to name a null.** Every measurement in this file
before today needed a scratch patch on the tree to turn a capability off
on one seat. `--profile-a wizard:pays_sacrifices=off,counter_threshold=4`
now applies knob overrides to a preset (`AiProfile.apply_overrides`:
booleans read on/off, numbers as the knob's type, an unknown knob is a
refusal at parse time and not a silent Wizard). The parser first accepted
the spec and then dropped it on the floor — which is why the first
control pair above was run twice.

**Still open, and now the only row:** the counter threshold is an
absolute card value, so against White Knights The Deck counters almost
nothing (Savannah Lions 3.0, Crusade 3.0, a Wizard's bar 5.0). Weissman's
rule — counter what your hand cannot answer LATER — is a capability of a
different kind and needs its own measurement.

### The window, and the cue it turned up

**6. THE DUEL LOG — `L` — `[QoL]`.** The engine has kept a full audit
trail (`MtgGame.log_lines`) since the first commit, and the design doc's
§5 said *"Full game log (the engine's log, scrolling, always visible)"*
shipped in v1 — while the table, under the complete-reimplementation
rule (the 1997 screen had no log pane), showed none of it and the
sidebar's comment promised *"a QoL log viewer returns later"*. It has
returned as a WINDOW, not a pane: `game/duel/duel_log.gd`, on the
`CombatWindow`'s pattern — the knot ground, the Situation-Bar title,
drag by the bar, clamped on screen, its position remembered
(`Settings` `duel_log_pos`) — with the text inset on the library
picker's dark-stone list ground because the first screenshot showed pale
lettering on the busy knot unreadable. Turn headers are lit; everything
else is the choice colour; `bbcode_enabled` is off so a `[QoL]` in a log
line is text and not markup. Three doors onto one window: the `L` key,
a page-of-lines glyph on the reserve strip beside Expand (the pause
window measured full at five buttons; the strip had room), and the
window's own `×`; the button's pressed state follows the window whichever
door was used. **Not a modal**: the duel runs on under it, `_modal_open`
and `_dialogs_open` leave it out, Space/Return/Esc keep their jobs, `Q`
still pauses over it. `Copy` puts the whole log on the clipboard, `Save`
writes `user://duel_log_<ticks>.txt` and says where on the bar. 16 tests
in `tests/ui/test_duel_log_2026_09_06.gd`, checked by looking under Xvfb.

**7. `Discard.wav` for every discard — `Mtg.EventType.CARD_DISCARDED`.**
Wiring the window meant reading the sound table again, and the discard
cue was played BY THE SCREEN, on the human's confirmed cleanup discard
only: a Hymn to Tourach, a Mind Twist, a Hypnotic Specter's hit, the
AI's own cleanup — all mute. The 1997 site is `functions.c:14861`,
INSIDE the discard, once per card. So the engine announces it: one
`CARD_DISCARDED` event per card, after the move, from all three paths
(`discard_cards`, `discard_random`, `discard_hand`, the cleanup discard
through the first), carrying `{player, instance, by_effect, to_library}`;
`DuelAudio.cue_for` maps it to `sfx_discard`; the screen's hand-played
cue is gone. No rules code reads the event — `CardData.on_discarded` is
the card hook — and milling (`deck.c:2015` reuses the WAV there) stays
quiet, as it was. `tests/unit/test_card_discarded_event_2026_09_06.gd`
(every path, the cleanup one `by_effect == false`, an empty hand
announcing nothing) and a row in `test_duel_sound.gd`.

**8. No sting for a duel nobody is in.** `Shell_WinDuel.wav` and
`Shell_LoseDuel.wav` are addressed to the player, and the title screen's
demo (`DuelConfig.demo_default`, two AIs) ended on the LOSE sting
whichever AI won, because "not the human" was the lose branch. A duel
with no human seat now ends in silence, like a draw.
`tests/ui/test_duel_screen.gd`.

**Three audio ideas looked at and dropped, for the record.** An
untap-step cue: `BECAME_UNTAPPED -> ""` is the owner's own 2026-09-03
rule, *"a phase makes no noise by itself"*. `Cancel.wav` on the cancel
paths: the file is in Duelsounds but the 1997 duel enum
(`defs.h:2179`) has no `WAV_CANCEL` and no call site, so there is nothing
to be faithful to. Re-hanging `EndTurn.wav` on the AI's end-turn ACTION
(`ai.c:588`, the row above): a defensible reading of the source but the
same owner's rule read literally says no, and it stays unplayed.

### The optimisation, measured

**9. The art cache has a bound.** The card-state catalogue's own note:
`GameSkin._texture_cache` never evicted, so a full browse of the Deck
Builder's grid held every art it had ever shown, 909 MB across the pool
— on a game that calls a Raspberry Pi a first-class target. The card art
now lives in its own least-recently-used cache, `_art_cache`, capped at
256 pictures (a duel's two decks are about 60 distinct cards, a Deck
Builder page about 40), with the names that have no file remembered
apart so a missing picture costs one search and no slot. A hit re-inserts
the key, so the card the player keeps looking at is never the one that
falls off the end; an evicted texture still on a card stays alive on
that card — the cache's claim is the only one dropped. **Measured under
Xvfb over a browse of 600 arts: 267 MB held (256 kept) against 608 MB
unbounded**; the whole pool would have been 909 and is now a ceiling of
about 270. The 1997 sheets stay in `_texture_cache` unbounded: they are
few, sliced by pixel coordinates and wanted for the whole run. Four rows
in `tests/ui/test_skin.gd`, driven with stand-in textures so the bound
is tested in a checkout with no art.

**The AI's speed, for the record.** The pain model costs the Deck Lab
about 2% (Saltrem Tor's mirror 173 -> 170 games/s, The Deck against Big
Green 80 -> 77) and the sacrifice arm nothing measurable (Dracur's
mirror 177 both ways); the wide runs below held 130 games/s on eight
threads. No hot path was changed for speed in this pass — the planner's
new work is one pass over the battlefield per plan.

**10. The well under the Showcase, checked by looking.** The 1280x800
render taken for the owner after the release showed two things the
suite could not: every message the screen writes under the count line
("Added 4 Lightning Bolt", "There is nothing to undo") was lettered in
`OriginalDialog.INK` from when the strip was a pale face — near-black on
the dark inset the strip became on 2026-09-05 — and cut off at the
baseline, because a Label that wraps and trims asks for one pixel of
height and the well's 42px floor left it ten. The well's lettering is
`WELL_INK` / `WELL_WARNING` now (pale, and a light warm red), each line
asks for its own height, and `_fit_the_well` gives the message two lines
where the column has the room (the shipping 800) and one where it does
not (720), decided on the column at its fullest so it never jumps as the
complaint comes and goes. The move messages spell "to the sideboard" —
MPlantin has no U+2192 and the arrow drew as a gap. And the owner's own
crop: the marble title slab took the column's 252 and stood twelve
pixels proud of the 240 Showcase card it names; it is the card's width.
Two rows in `tests/ui/test_deck_builder.gd`.

### The gate, and the bug hunt's wide net

Full suite green before and after (`./run_tests.sh`), both soaks
(`--rules fifth`, `--rules modern`, six duels each through the live UI,
exit 0), the Python tools (88), a boot smoke; counts in `README.md` and
`docs/CODE_MAP.md` are from this run. The wide net — the Deck Lab over
decks this pass could not have tuned for: Big Green against all 55 of
the 1997 originals, White Knights against all 55 of the Ancients,
Mountain Artillery against the five proxy-free tournament decks, 20 games
a pair at seed 7 — **2,300 games, zero stalled, zero refusals, zero
engine errors**, on top of the ~24,000 games of the measurements above.

## Standing quality gates

- `./run_tests.sh` green on every commit; new code ships with tests.
- Every file's header doc comment explains its role; CODE_MAP.md stays exact.
- Engine stays Node-free and headless-runnable — no exceptions.

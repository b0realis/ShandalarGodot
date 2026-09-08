# The four opponents — what each difficulty's AI can do

The 1997 game had four difficulty levels and gave them wizards' ranks —
`@DIFFICULTYLEVELS` in `Advstrings.txt` is the whole list, *Apprentice,
Magician, Sorcerer, Wizard* — and its own account of how they differed at
the table was one sentence: the AI makes fewer mistakes (Dana Huyler's
FAQ, cited at the top of `engine/ai/ai_profile.gd`). Everything else the
level changed in 1997 was the ADVENTURE's — starting gold, the smallest
legal deck, the wizard's life, the bonus every enemy creature carried,
Arzakon's life — and that table is in `../docs/SHANDALAR_LORE.md` (FAQ
v1.2). This file is about the duel: what the AI in each seat knows how to
do, and what it deliberately does not.

Where the player meets it: the Setup screen's *AI difficulty* row (one per
AI seat, Wizard by default), the Gauntlet's *Enemy Level*, and the Deck
Lab's `--profile-a` / `--profile-b` (`apprentice`, `magician`, `sorcerer`,
`wizard`). All three build the same four presets from `AiProfile`.

## 1. The rule of the ladder

**One decision code, four profiles.** There is no "easy AI" and "hard AI"
in the engine — every seat runs `AiPlayer` with the same evaluator, the
same combat maths and the same plans, and the profile is a bag of knobs
that code reads. Difficulty is made of two things, in this order:

1. **The mistake rate.** `mistake_chance` is the probability that an
   intended action degrades — a cast skipped, an attacker left home, a
   block dropped. It is rolled on the game's own RNG, so a seeded duel
   replays the same fumbles. This is the 1997 model exactly: weak AIs
   know how to play and sometimes don't; strong AIs stop fumbling.
2. **Capabilities.** A handful of whole LAYERS of play are switched off
   below a rung — holding instants, sideboarding, reading the opponent's
   crack-back, the seven "does it understand…" knobs of the control sweeps
   and The Deck's passes. Each one is an honest weakness rather than a
   rule bent: an Apprentice that never holds mana open is playing
   sorcery-speed Magic, not cheating.

Two constraints every knob has obeyed since the first one landed, and
every future one must:

- **Monotone.** Each knob is as good or better one rung up; the ladder is
  never inverted in any single number. `tests/ai/test_ai_crack_back_2026_09_05.gd`
  pins this for the search budget; the pattern is the same for the rest.
- **Not a second difficulty concept.** A capability gates a layer of play;
  it does not carry its own strength dial. Difficulty scales through
  `mistake_chance` and through which layers are on.
- **Nothing card-named.** What a capability gates is priced from numbers
  the AI already had (`EffectIntent`'s fields, the evaluator's scale, the
  board). The only card-named things in the profile's reach are READINGS
  of card-local effects (`EffectIntent.LEVELLERS`, `WINDOW_SHAPES`), never
  a decision.

And one owner's ruling, 2026-09-07, when the question was whether the
Magician should be given `counts_cards` too: *"no, we want difficulty
ramp"*. The capabilities of The Deck's second pass stay on Sorcerer and
Wizard; the Magician's ceiling is part of the ramp, not a gap to close.

## 2. The presets, knob by knob

`engine/ai/ai_profile.gd`, `apprentice()` … `wizard()`. The Deck Lab can
override any knob on any preset for a measurement
(`--profile-a wizard:pays_sacrifices=off`, `AiProfile.apply_overrides`).

| knob | Apprentice | Magician | Sorcerer | Wizard | what it is |
| --- | --- | --- | --- | --- | --- |
| `mistake_chance` | 0.35 | 0.20 | 0.08 | 0.00 | share of intended actions that degrade |
| `aggression` | 0.75 | 0.60 | 0.50 | 0.50 | combat and burn-to-face risk appetite; 0.5 is balanced |
| `chump_threshold` | 3 | 4 | 5 | 6 | the panic line: life at which it chump-blocks and prevents damage — higher panics EARLIER |
| `holds_instants` | off | on | on | on | the whole reactive game: counters, Fog, tricks, mana held open, the 1997 prevention and regeneration windows |
| `counter_threshold` | (5.0) | 7.0 | 5.5 | 5.0 | smallest threat worth a Counterspell; the Magician's 7.0 lets a tier more through |
| `sideboard_swaps` | 0 | 2 | 3 | 4 | cards it may move between duels of a match |
| `combat_search_nodes` | 0 | 0 | 1 500 | 3 000 | the crack-back search's budget; 0 never looks past its own combat |
| `plays_engines` | off | off | on | on | a permanent that pays over time — a Mishra's Factory, a Disrupting Scepter, a Jayemdae Tome |
| `pays_sacrifices` | off | off | on | on | an ability whose cost is one of its own permanents — Strip Mine, a Digging Team |
| `casts_timed_spells` | off | off | on | on | a spell whose only moment is outside its own main phase — a Festival, a Siren's Call |
| `minds_pain` | on | on | on | on | a City of Brass is not a Plains; on everywhere (see below) |
| `fits_auras` | on | on | on | on | hangs a friendly aura only on a creature it gives something to — no vigilance on a Wall; on everywhere, for the same reason |
| `mulligans` | on | on | on | on | judges the opening hand under the Paris rule by its lands (`AiMulligan`: none, all, too few or too many for the hand's size, or lands that cast none of its spells; nothing below four cards goes back); on everywhere — keeping a no-land seven is a malfunction, not a weakness |
| `counts_cards` | off | off | on | on | sizes X draws and discards to the hands and libraries in front of it; aims a draw at an empty library |
| `levels_boards` | off | off | on | on | prices Balance by what each side would lose |
| `paces_draws` | off | off | on | on | refuses an optional draw that would hand the opponent the library race |
| `holds_duplicates` | off | off | on | on | keeps a second legend or world in hand instead of burying the first |
| `animates_to_attack` | off | off | on | on | buys a Factory's animation only when the attack it would declare sends the body; until then the body is no mana source, and on their turn a creature-until-end-of-turn is no blocker |

`minds_pain`, `fits_auras` and `mulligans` are the three knobs that are
on at every rung, and the reason is the line between weak and broken: an
Apprentice that taps City of Brass for its last life to cast a Grizzly
Bears is not a worse player, it is a malfunction — and so is one that
puts Eternal Warrior on a Wall of Swords, or keeps a seven with no land
in it (the owner's playtests, 2026-09-08). They are knobs only so the
Deck Lab can run the null; with `mulligans` off the pilot falls back to
`DecisionAgent`'s plain rule, which throws back only the two hands the
1997 game named — no land, all land — down to the same floor of four.

The Apprentice's `counter_threshold` is in brackets because it never
reads it — with `holds_instants` off there is no counterspell to price.

## 3. Rung by rung, in the player's terms

**Apprentice.** Knows every play and fumbles a third of them. Swings
recklessly (`aggression` 0.75): attacks that trade badly, burn at the
face. Plays "my turn only" Magic — it never holds mana open, never
counters, never Fogs, never casts a trick in your combat, and lets the
automatic damage-prevention order apply. Panics late (life 3). Never
sideboards between duels, never looks past its own combat, and treats
every permanent as what it is worth today: a Factory is a land, a Tome is
an artifact, a Strip Mine is never cracked. What you see is the shape of
the 1997 game's easiest table — a wizard with good cards and no patience.

**Magician.** Fumbles a fifth. The reactive game switches on: it holds
instants and the mana for them, blocks with tricks, and counters — but
only the biggest threats (`counter_threshold` 7.0), so most of your
spells resolve. Sideboards two cards. Still no crack-back read, still no
engines, sacrifices, timed spells or card-counting: it will cast a Mind
Twist for X into an empty hand, and a Braingeyser sized past its own
library, because those layers are the Sorcerer's. This is the rung the
owner's ruling keeps as it is — the visible step between "reacts" and
"plans".

**Sorcerer.** Fumbles one action in twelve. Balanced (`aggression` 0.5),
panics at 5, counters a tier smaller (5.5), sideboards three. Reads your
crack-back before committing an attacker — 1 500 leaf evaluations, half
the Wizard's, so its search truncates on the wide boards the Wizard still
resolves. Every capability is on: it activates engines and knows what
they are worth over time, pays a Strip Mine or a Digging Team for a
better body, casts a Festival at your upkeep and a Siren's Call before
your attackers, sizes its X spells, prices a Balance, paces its draws to
the libraries, keeps a second The Abyss in hand, and animates a
Factory only for an attack it will actually declare.

**Wizard.** No mistakes at all. The same decision code, the same
capabilities as the Sorcerer, with twice the search (3 000), the pickiest
panic line (6), the widest counter net (5.0) and four sideboard swaps.
Every difference between a Wizard and a Sorcerer is a number, not a
layer — which is what "no mistakes" means here: it never degrades its own
choice.

## 4. What the ladder measures as

Numbers from `docs/ROADMAP.md` (the control sweep, 2026-09-06), Big Green
in the pilot's seat against a Wizard on Big Green, 1 000 games a rung:

| pilot | wins vs Wizard |
| --- | --- |
| Apprentice | 15.8% |
| Magician | 37.6% |
| Sorcerer | 45.1% |
| Wizard | 51.7% (a true mirror; the excess is the seat bias) |

Monotone, and byte-identical to the null at every profile on a starter
mirror, because the starters cannot reach any of the capability arms.
The same section records what the ladder looked like on The Deck's own
mirror BEFORE the capabilities existed — inverted, an Apprentice beating
a Wizard 87.8% of the time, because neither seat could win and the one
that did less took less City of Brass damage doing it — and what it
looks like since (34.3 / 48.8 / 60.6 / 49.7; the Sorcerer-over-Wizard
residue is the `counter_threshold` question, open). The Deck's second
pass (2026-09-07) is four of the capabilities: The Deck playable
against the five starters went from 12.7% to 40.3%. The third pass
(2026-09-08) re-measured that with the mulligan on — 40.1% — and added
`animates_to_attack`, a wash on the totals with the wasted animations
gone (29 of 834 before, 0 of 808 after, in the census).

Every change to a profile is measured before it ships — `DeckLab/deck_lab.sh
--sweep KNOB=on,off` against a control pair, the same seed — and
`docs/ROADMAP.md` keeps the runs. `CONTRIBUTING.md` has the rule.

## 5. Where the ladder still ends short

- `counter_threshold` is an absolute evaluator number, so a Wizard on a
  deck with pain lands spends life on counters a Sorcerer keeps; that is
  the open knob question above, to be instrumented before it is touched.
- The mana planner does not know that a Mishra's Factory, a Library or a
  Strip Mine is worth more untapped than a Forest: among equal sources
  it takes them in battlefield order, so a second animation can be paid
  by tapping the first animated body when the Factories come before the
  plain lands. `animates_to_attack` excludes the body it has already
  animated; the tie-break itself is open (`docs/ROADMAP.md`, the third
  pass). And no rung animates a Factory to BLOCK on the opponent's turn.
- The Magician has no crack-back search and no capabilities — by ruling.
  Anything that turns out to be a malfunction rather than a weakness
  (the way `minds_pain`, `fits_auras` and `mulligans` did) goes on everywhere;
  anything that is a layer of play stays a rung.
- The 1997 adventure's difficulty (gold, deck minimum, life, the creature
  bonus, Arzakon's 100/200/300/400) is not a duel-profile matter and is
  not modelled here; it belongs with the adventure.
- What the engine should eventually know about the old loops a player
  brings to the highest table — Channel-Fireball, the infinite turn, the
  Vise behind a Moat, decking — is `docs/arzakon.strategy`, section 4.

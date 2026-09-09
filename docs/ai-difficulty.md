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
| `feeds_worst` | on | on | on | on | asked which of its own to give up when the giving is no cost it chose — The Abyss's meal, Lord of the Pit's tribute, Mana Vortex's land, a Sylvan Library's discard — it gives the least valuable, not the best; on everywhere, the same reason |
| `spares_own` | on | on | on | on | never fills a harmful spell's slots with its own permanents unless the evaluator prices giving them up below zero — no Detonate on its own Mana Vault, no Winter Blast padded with its own creatures (the owner's playtest, 2026-09-08); on everywhere, the same reason |
| `prices_liabilities` | on | on | on | on | knows that a permanent of its OWN can be worth less than nothing: the reckoning (a permanent whose printed line says losing it loses the GAME is never given up — a Lich), the dead weight (tapped, not untapping, every ability needing the {T} it cannot pay — a Mana Vault with no {4}, a creature under a Paralyze) and the toll it still takes each turn, priced for the turns our mana needs to reach the price the card itself prints. It is what opens `spares_own`'s one door: with it the AI Detonates the Vault it cannot untap and keeps the one it can; on everywhere, the same reason |
| `counts_cards` | off | off | on | on | sizes X draws and discards to the hands and libraries in front of it; aims a draw at an empty library |
| `levels_boards` | off | off | on | on | prices Balance by what each side would lose |
| `paces_draws` | off | off | on | on | refuses an optional draw that would hand the opponent the library race — a Tome's tick, an Ancestral, a tutor's card, and since the third pass the extra draw step a Time Walk buys |
| `holds_duplicates` | off | off | on | on | keeps a second legend or world in hand instead of burying the first |
| `animates_to_attack` | off | off | on | on | buys a Factory's animation only when the attack it would declare sends the body; until then the body is no mana source, and on their turn a creature-until-end-of-turn is no blocker |
| `times_sweeps` | off | off | on | on | prices a board wipe by the damage it keeps off its life as well as the permanents it trades — lethal-worth when the sweep is the out, a creature its Abyss will eat never counted — and fires one it can activate in the opponent's combat, after the attackers are declared and before the damage (the Disk as a Fog) |
| `trusts_abyss` | off | off | on | on | keeps its counterspell when the creature spell on the stack is the next meal of a feeder on its table — The Abyss will destroy it at their upkeep — and spends it on what the feeder cannot eat |
| `pumps_to_attack` | off | off | on | on | judges its own creature at the size its OPEN MANA can reach when a combat declaration is made — a Carrion Ants behind four Swamps is a 4/5, not a 0/1 — attacking AND blocking (the name is the half it was born for), with the second main phase's cast kept whole on its own turn and the held instant on both, a capped breath counted at its cap, and the two card-local firebreathers (Dragon Whelp, Nalathni Dragon) read at last — three breaths and never the fourth unless that attack ends the game; and since the third pass the breaths the pilot BUYS are the ones the declaration was priced with — the split of the one pool is spent as it was allotted, and a trampler's overflow is measured against the toughness that will actually be there |

`minds_pain`, `fits_auras`, `mulligans`, `feeds_worst`, `spares_own`
and `prices_liabilities`
are the six knobs that are on at every rung, and the reason is the
line between weak and broken: an Apprentice that taps City of Brass for
its last life to cast a Grizzly Bears is not a worse player, it is a
malfunction — and so is one that puts Eternal Warrior on a Wall of
Swords, or keeps a seven with no land in it (the owner's playtests,
2026-09-08), or feeds its Serra Angel to The Abyss with a Grizzly Bears
standing beside it (The Deck's third pass, the same day: every "choose
one of yours to lose" that is not a cost the pilot chose to pay was
answered with its BEST card, because the one answer for card questions
was written for the tutors), or pays {1}{R} to Detonate its own Mana
Vault (the owner's playtest that evening: the reader had no row for the
card and the picker's fallback for an unclassified effect shopped its
own side; the row closes the Detonate, and `spares_own` is the rule the
fallback was the one exception to, keeping a Winter Blast from being
filled out with the caster's own creatures — 112 of the 293 it named in
sixty Ape Lord games, then none), or answers "which of your own
permanents do you give up" with the Lich (2026-09-09: a four-mana
enchantment prices at 3.2, below a Grizzly Bears, and *"when this
enchantment is put into a graveyard from the battlefield, you lose the
game"* ends the duel on the spot — three of two hundred Azaar Lichlord
games, and the knob's other half is what those two hundred games moved).
They are knobs only so the Deck Lab
can run the null; with
`mulligans` off the pilot falls back to `DecisionAgent`'s plain rule,
which throws back only the two hands the 1997 game named — no land, all
land — down to the same floor of four.

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
the libraries (a Time Walk's extra draw step among them), keeps a
second The Abyss in hand, animates a Factory
only for an attack it will actually declare, sends a firebreather at the
size its open mana can reach instead of at its printed 0/1 — and blocks
with it at that size too, so a Carrion Ants behind six Swamps eats a
Craw Wurm instead of watching it go past — and holds
its Nevinyrral's Disk for the attack it answers — priced by the damage it keeps off the
pilot, fired once the attackers are named and before they connect —
and keeps its Counterspell in hand when the creature on the stack is
one its Abyss will eat at their upkeep.

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
gone (29 of 834 before, 0 of 808 after, in the census). `feeds_worst`
is measured from the other seat — it is the STARTERS that face The
Deck's Abyss — and every one of the five gains against it with the knob
on (+2.3, +2.0, +2.0, +0.3, +1.0; 26 games flipped to a win against 3
flipped away, of 1 500), which is to say The Deck's own rate against the
field drops by about a point and a half now that its Abyss is fed a
Llanowar Elves instead of a War Mammoth. The starter matrix is
byte-identical with the knob on and off: no starter owns a card that
asks the question. `times_sweeps` is a wash on the totals in the right
direction (+0.7, 0.0, +1.3, +0.7, +1.3 against the five starters; 16
games flipped to a win, 4 away, of 99 that differed) with the Disk
fired in the opponent's combat five times in 150 census games where it
had been fired there never, and the two lethal attacks it used to sit
through gone. Its first cut left the Disk's own body out of the sum and
LOST (−3.7, −2.3, −0.3, −0.3, −0.3; 17 flipped to a win, 38 away): the
sweeper went off at twenty life to kill a lone 3/3, and at one life to
kill a Llanowar Elves its own Abyss was about to eat. The starters own
sweepers too — Hurricane, Earthquake, Wrath of God — and their matrix
moves by no more than two games in twelve hundred a deck. The Time
Walk's draw step under `paces_draws` is one card once a game and
measures like it: the shipped Wizard before and after it, the same
seed, differs in 40 of 1 500 games against the five starters and The
Deck wins 11 of those it had lost against 1 the other way (+0.3, +0.3,
0.0, +1.3, +1.3). `trusts_abyss` is a wash in the right direction
(+0.3, +1.7, −0.3, +1.0, +1.3 against the five starters; 33 games
flipped to a win, 21 away, of 602 that differed) with the counters
spent about half as often — 215 Counterspells and 75 Mana Drains cast
in 150 census games with the knob off, 122 and 40 with it on, the same
64 wins either way: a creature the Abyss was going to eat was never
worth the counter, and the counter kept is the one that meets the
Disenchant. The Weissman list is byte-identical: it plays Moat, not
The Abyss. The whole third pass, the shipped Wizard against the
gauntlet at the same seed: 40.1% before (49.7, 41.7, 48.7, 35.7,
25.0) and 40.6% after (44.7, 41.3, 48.0, 39.0, 30.0) with the
mulligan on, 40.3% to 40.5% with it off — a wash on the total because
both seats got better: the tribute is the starters' gain, the Disk,
the Factory, the Walk and the kept counter are The Deck's, and White
Knights' +5.0 is where those land.

`pumps_to_attack` is the one knob so far that is not a wash, and the
reason is that it does not tune a decision the pilot was already making
— it hands two working routines an attacker they had never been given.
Vampire Lord (the 1997 original list: four Carrion Ants, four Vampire
Bats) against the five starters, 1 000 games an arm at seed 11: 19.8 to
24.6, 28.7 to 34.7, 5.7 to 13.0, 18.0 to 25.7, 5.8 to 12.8 — every
matchup a gain, and every one of the five clear of zero on its own
interval (+4.8 ±3.6, +6.0 ±4.1, +7.3 ±2.5, +7.7 ±3.6, +7.0 ±2.5), with
the two the deck could barely win (Blue Skies, White Knights) more than
doubled. Warlock's two Frozen Shades in sixty cards move it less and all
the same way (+0.7, +4.0, +3.7, +4.9, +2.5, three of them clear),
and Mountain Artillery — one Shivan Dragon and three Granite Gargoyles
whose +0/+1 buys no attack and is refused — is the wash it should be
(+0.6, 0.0, 0.0, +0.5). The control pair Big Green vs White Knights is
byte-identical in every arm of all three runs: no starter but two owns a
card the reader can see.

THE SECOND HALF, later the same day: the BLOCK declaration and the two
card-local firebreathers, both under the same knob. Measured the same
way, seed 11, 1 000 games an arm, and this time against the morning's own
code as a third arm, so each half can be read on its own.

- The BLOCK half is a WASH in win rate, on both pairs, and it is worth
  saying so plainly. Vampire Lord's `on` arm moves 24.6 → 24.0, 34.7 →
  36.0, 13.0 → 11.7, 25.7 → 25.6, 12.8 → 12.6, and Kzzy'n's 33.3 → 33.7,
  31.7 → 31.8, 31.1 → 30.9, 24.3 → 23.9, 34.1 → 33.9 — not one of the ten
  outside the interval a 1 000-game delta can see (±3 to ±4). The reason
  is visible in the code it replaces: `_combat_self_pumps` was already
  buying the breaths AFTER the blockers were declared, so most of the
  value the planned block wins was being recovered a step later by
  accident. What it fixes is the case that recovery cannot reach — a
  block never declared at all, the Carrion Ants behind six Swamps that
  watched a Craw Wurm walk past for six — and that is the one the owner
  sees at the table.
- The READER half is the whole of the afternoon's gain. Kzzy'n — The
  Dragon Lord (four Dragon Whelp, four Nalathni Dragon, four Shivan) was
  a deck the morning's knob did NOTHING for: +0.7, +0.1, +1.1, +0.1,
  +1.5 against its null, not one clear of zero, because its Shivans were
  already 5/5 attackers and the eight bodies that were not read were the
  eight the reader could not see. With the two rows in, against the same
  null: 32.6 → 42.5, 31.6 → 37.0, 30.0 → 38.3, 24.2 → 29.1, 32.6 → 40.4
  (+9.9 ±4.2, +5.4 ±4.1, +8.3 ±4.1, +4.9 ±3.9, +7.8 ±4.2), every one of
  the five clear of zero, and against the morning's `on` arm +8.8, +5.2,
  +7.4, +5.2, +6.5. Two rows in a table, three Mountains a turn the deck
  was never spending — three and not more, because the fourth breath is
  the fuse.
- The Ancients Vampire Lord (two Carrion Ants and two Vampire Bats
  rather than the originals' four and four) is the third pair, and reads
  the whole knob at +3.6 ±3.6, +2.6 ±4.3, +6.5 ±2.5, +5.5 ±3.6, +4.0
  ±2.6 — the same shape at half the copies.
- The control pair Big Green vs White Knights is byte-identical to its
  own null in every arm of all five runs (1 000 of 1 000 games each) —
  including the two arms run against the morning's tree, which is how
  the null was proved unmoved: it replays the published attack-half
  numbers to the decimal (19.8/24.6, 28.7/34.7, 5.7/13.0, 18.0/25.7,
  5.8/12.8). That is what the gate on the card-local reading buys.

THE THIRD PASS, later the same day: what the declaration PROMISES, the
recovery now DELIVERS — the trampler's overflow and the one pool — and
both were §5 items rather than new capabilities, so the knob's meaning
grew a third time and its null did not move. Measured the same way, seed
11, 1 000 games an arm, each pair run twice: once against the morning's
tree and once against this one, so the `on` arms can be laid side by
side.

- It is a WASH in win rate on every pair, and by a wider margin than the
  block half was — because the two faults are RARE, not because the
  readings do nothing. Vampire Lord against Big Green (three War
  Mammoths): null 19.8%, `on` 24.0% before and 23.9% after, 3 games of
  1 000 different at all and one of them a win lost. Kzzy'n against Big
  Green: null 14.3%, `on` 18.4% either way, 2 games different and neither
  a flip. Against **Summoner**, which is where the tramplers are — three
  Force of Nature, two Colossus of Sardia, four War Mammoth — null 39.9%,
  `on` 53.3% either way, 2 games different and neither a flip. Against
  War Mage's four Ball Lightning: null 22.9%, `on` 56.0% either way, and
  not one game of the thousand different. The control pair Big Green vs
  White Knights is byte-identical to its own null (525-475, 1 000 of
  1 000) in every arm of all eight runs, and every NULL arm is identical
  between the two trees game for game — 1 000 of 1 000 on all four pairs,
  not merely the same rate — which is the proof that neither fix reaches
  the pilot the Deck Lab measures the knob against.
- THE CENSUS says the readings fire and the games rarely turn on them.
  Over 200 logged games of Vampire Lord against Summoner the trample
  reading returned a different number 19 times and the plan's cap bound a
  breath 55 times; against Big Green, 14 and 68. So it is about one
  trample reading every ten games and one capped breath every three — and
  two or three of a thousand games end differently for it.
- WHAT IT FIXES IS WHAT THE TABLE SEES, which is the block half's own
  precedent. On the board the report was written from — a Force of Nature
  and a Hill Giant into a Carrion Ants behind six Swamps, a Scathe
  Zombies and one spare, at eight life — the shipped pilot read the swing
  as three points through, kept its spare, took eight and DIED. It now
  reads five, throws the spare in front of the Hill Giant and lives at
  three. And on the pool: four Swamps split two and two between a Carrion
  Ants and a Vampire Bats, both blocking, used to see the Ants take three
  of them to save itself while the bats stayed a 0/1 and died for
  nothing; both trades are made now and the fourth Swamp is spent.

THE LIABILITY (2026-09-09, `prices_liabilities`) is a WASH where the
Detonate is and a small gain where the Lich is, and the two halves want
reading apart. Seed 11, the sweep's own three pairs, control Big Green vs
White Knights.

- THE NULL IS EXACTLY THE NULL, and it was proved by replay rather than
  by argument: the `pays_sacrifices` sweep of the manual (Dracur, Spells
  of the Ancients vs Big Green, 1 000 games an arm) was run on the tree
  before this landed and on the tree after it with `prices_liabilities=off`
  forced on both seats, and all **6 000 games are identical game for
  game** — the same log fingerprint, the same winner, the same turn
  count, 24.9% / 27.3% / 24.9% either way, with the published control
  record 525-475 replayed to the game. Every sweep below also carries its
  own control verdict, and Big Green vs White Knights is byte-identical
  to its own null in every arm of all eight runs (525-475 at 1 000,
  1075-925 at 2 000). That is the point of putting the reading in
  `AiPlayer._own_value` and leaving `Evaluator.permanent_value` alone: the
  board score, the combat maths, the blocks, the sweeps and the counter
  threshold read the floored number they always did.
- THE DETONATE HALF IS A WASH. War Mage (four Mana Vault, three Detonate)
  against Crag Hydra: 45.3% → 45.5% at 1 000 games an arm (+0.2 ±4.4) and
  45.8% → 45.6% at 2 000 (−0.2 ±3.1). Against Big Green, 11.7% → 11.5%
  (−0.2 ±2.8). Ape Lord vs Elvish Magi — two Vaults and one Detonate in
  sixty cards — is EXACTLY null, 32.0% both ways at 1 000 games. The
  census says why, and it is the honest answer rather than "the reading
  does nothing": over 150 logged War Mage games the pilot Detonated its
  own dead Vault **13 times where it had done so 0 times**, its Vaults
  burnt it 159 times instead of 187 — twenty-eight points of its own life
  it no longer pays — and it spent 84 Detonates on the enemy where it had
  spent 92. Thirteen own-side Detonates bought back twenty-eight life and
  cost eight enemy artifacts, and at 1 000 games those two cancel.
- THE LICH HALF IS A GAIN, or nearly one. Charles' Lich Deck (Baxter,
  1995) against Mountain Artillery: 33.2% → 34.6% at 1 000 (+1.4 ±4.1)
  and 33.9% → 35.2% at 2 000 (+1.4 ±2.9). Azaar - Lichlord (Spells of the
  Ancients — two Lich, four Demonic Hordes, four Hypnotic Specter)
  against the same burn: 55.7% → 58.8% at 1 000 (+3.1 ±4.3), 55.3% →
  58.1% at 2 000 (+2.7 ±3.1) and 54.9% → **58.0% at 4 000 games an arm
  (+3.2 ±2.2), which is clear of zero** — the same sign at all three
  sizes and DECIDED at the last. Against Black-Red Raiders the same Lich
  deck is a wash (23.2% → 23.5%, +0.4 ±2.6 at 2 000): the Raiders' clock
  is creatures rather than burn, the Lich's damage trigger fires half as
  often, and the ask this reading answers is rarely put.
- WHAT THE LICH CENSUS SHOWS is not mainly the sacrifice that ends the
  game — that is rare, three of two hundred Azaar games with the knob off
  and one with it on. It is what the seat does with the four or five
  earlier asks. Two hundred logged Azaar games, the same seeds: with the
  knob OFF the seat loses 87 games at zero life, 3 to the Lich's own
  reckoning and 1 with the Lich unfed; with it ON, 54 at zero life, 1 to
  the reckoning and 31 unfed. The Lich prices at 3.2 — below a Grizzly
  Bears, below a Strip Mine, and below its own controller's last two
  Swamps once `land_value`'s scarcity term has lifted them — so the old
  seat handed it over while it still had a board, lost the bargain that
  says it cannot die of life loss, and then died of life loss. The new
  seat keeps the enchantment and feeds the board, and loses only when the
  board is gone. Ninety-one losses become eighty-six.
- SO IT IS TWO READINGS WITH TWO VERDICTS, and they want saying
  separately. The Detonate half is a WASH that fixes a visible
  malfunction — the same shape `feeds_worst` and `times_sweeps` shipped
  in. The Lich half is a GAIN, decided at four thousand games. The knob
  is on at every rung for the Lich's sake and not the Vault's: giving up
  the permanent you cannot lose is not a weaker way to play.

Every change to a profile is measured before it ships — `DeckLab/deck_lab.sh
--sweep KNOB=on,off` against a control pair, the same seed — and
`docs/ROADMAP.md` keeps the runs. The control pair is chosen by what
FIRES the knob, not by what the last knob used: a pace knob's control
holds no draw spell, tutor or Time Walk (Big Green vs White Knights),
a sweeper's no Hurricane, Earthquake or Wrath (Blue Skies vs Black-Red
Raiders) — the third pass's Time Walk sweep FAILED its first control
on exactly that (Blue Skies' Ancestral Recall), and a failed control
makes the deltas beside it no measurement at all. `CONTRIBUTING.md`
has the rule.

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
- `times_sweeps` holds an activated sweeper only from the moment it is
  offered in the opponent's combat; a Disk that is worth firing at its
  own main phase still fires there, when waiting for their attack would
  cost nothing but a Disenchant's window. The relief's "after" board is
  the sweep's survivors under the statics as they stand — a Moat the
  Disk takes with the board still holds the ground creatures the Disk
  did not kill. Both open (`docs/ROADMAP.md`, the third pass).
- Time Walk is cast for its printed worth — a generic three, the same
  as a Hill Giant — once the pace allows it; the turn's own value (the
  untap, the attack, the land drop) is not priced, so a Walk goes off
  on an empty board when holding it for a Factory attack would have
  been the play. Open (`docs/ROADMAP.md`, the third pass).
- `trusts_abyss` reads the table as it stands: a creature it lets
  through because it is the next meal can be sheltered before their
  upkeep by a cheaper creature cast after it (Blue Skies' one-drop
  fliers, the −0.3 there), and a second copy of a creature already on
  the table is let through as level with it although only one of the
  two dies. Open (`docs/ROADMAP.md`, the third pass).
- ~~`pumps_to_attack` measured a TRAMPLER's overflow against the toughness
  the probe put on the blocker, and split one mana pool among several
  bodies that `_combat_self_pumps` then priced against as a whole.~~
  **Closed 2026-09-09 — both FIXED** (§4, the third pass). The trample
  reading was worse than "up to one pump": a gang buys NOTHING, because
  `_combat_self_pumps` asks each blocker whether it kills the attacker
  alone, so a Carrion Ants and a Scathe Zombies in front of a Force of
  Nature read a five-point swing as nought and the pilot died of it at
  eight life. `AiPlayer._absorbed_by` asks the recovery's own ladder
  instead — the probe's toughness when the probe's size saves the body,
  the breaths that win the trade when it does not, and nothing when
  nothing it can reach kills — and the panic line and the chump rung's
  price both go through it. The pool fix is in the RECOVERY and not in
  the probe, because the probe already reserves per body and a second
  reservation beside it is two plans that can disagree: the split is
  written down where the declaration is made (`AiPlayer._pump_plan`) and
  spent one activation at a time, with a second uncapped pass so that
  mana no plan wanted is still spent. What is left open is smaller and
  named at the site: a body in a GANG is priced at no breath because that
  is the question the recovery asks it, which reads the swing as MORE
  dangerous than it is — the safe direction — and
  `_offensive_combat_response`, which breathes on an unblocked attacker
  after `_combat_self_pumps` has had its turn, spends the leftovers
  without consulting the plan.
- ~~Whether a RANDOM bonus can be priced at all — its floor, its mean, or
  a distribution the evaluator carries — with Rainbow Knights as the
  card that asks it.~~ **Closed 2026-09-09 — RULED, not built: the floor,
  and therefore no row.** The argument, so that it does not have to be
  had again. Every reader of `EffectIntent.CARD_LOCAL_PUMPS` is a
  DECLARATION — the attack cohort, the block ladder, the lethal probe —
  and a declaration cannot be taken back once the roll happens, so the
  only number that never turns a declaration into a blunder is the one
  the activation GUARANTEES; the share of games any higher number
  blunders in is exactly the probability mass below it, a third of them
  at the mean of a uniform roll of three. Rainbow Knights' floor is +0,
  and a row that grants no power is refused by `AiPlayer._self_pump_of`
  anyway — so the honest row and no row are the same behaviour, and no
  row is the one that does not pretend. A DISTRIBUTION is not one card's
  worth of work and is not blocked on this card: `_dies_to`,
  `_damage_from` and the crack-back search's power arrays are integers,
  and carrying a distribution means every leaf of the search becomes an
  expectation over the rolls. The ruling is pinned by
  `tests/ai/test_ai_pump_plan_2026_09_09.gd`, roll and all. Where a
  random bonus could be priced above its floor is AFTER every
  declaration — an unblocked attacker breathing for face damage risks
  nothing but the mana — and that is a different reader from this table;
  it stays unbuilt because the mana it would spend is the held instant's.
- ~~`Evaluator.permanent_value` never returns below zero, so a permanent
  worth LESS than nothing to its controller cannot be expressed and
  `spares_own`'s one door never opens.~~ **Closed 2026-09-09 —
  `prices_liabilities`** (§4). The reading lives in
  `AiPlayer._own_value` and NOT in `Evaluator.permanent_value`, which has
  seventy-six callers and every one of them is a board reading; the
  question "what is giving this permanent up worth to us" has four
  callers and they are the four that wanted it. WHAT IS LEFT OPEN, and
  named at the sites:
  * A TOLL WITH NO PRINTED PRICE TO STOP IT is not read at all — a
    Serendib Efreet's point a turn, a Juzám Djinn's, an Erg Raiders' two,
    a Yawgmoth Demon's. `permanent_value` is a SNAPSHOT and a stream with
    no end cannot be subtracted from it without pricing every drawback
    creature in the pool out of its own deck; pricing one properly means
    an evaluator that knows how long the game has left, which is a
    different piece of work.
  * A ROLL is not read (Mana Crypt's coin flip), by the same ruling that
    keeps Rainbow Knights out of `CARD_LOCAL_PUMPS`: what a card
    guarantees is the only number a decision can be made on. Here the
    sign is flipped, so the ruling is conservative rather than safe —
    a Mana Crypt keeps its printed worth.
  * A SYMMETRIC toll ("deals 1 damage to that player" — Copper Tablet,
    Manabarbs, Storm World, Power Surge) is not read: our half of it is
    not the whole of it, and a reading that saw only our half would call
    a Copper Tablet a liability while it beats the opponent down beside
    us. The two-sided race those cards are is a `counts_the_race`
    question (wave 4).
  * THE UNTAP PRICE PRINTED ON THE AURA rather than on the host is not
    read, so a creature under a Paralyze reads as dead weight even on a
    turn we could pay the {4} to free it. It understates what we could
    get back, which leaves the worth at zero rather than below it, so it
    cannot give the creature away.
  * `EffectIntent.damage_to_target_controller` exists now and Detonate
    has its row, but only the OWN-side half is priced (the sting we pay
    to relieve ourselves). An enemy Detonate's X is still an unpriced
    bonus — pricing it would move the shipped pilot on both arms, so it
    stays the wave-5 row it was named as.
- The Magician has no crack-back search and no capabilities — by ruling.
  Anything that turns out to be a malfunction rather than a weakness
  (the way `minds_pain`, `fits_auras`, `mulligans`, `feeds_worst` and
  `spares_own` did)
  goes on everywhere;
  anything that is a layer of play stays a rung.
- The 1997 adventure's difficulty (gold, deck minimum, life, the creature
  bonus, Arzakon's 100/200/300/400) is not a duel-profile matter and is
  not modelled here; it belongs with the adventure.
- What the engine should eventually know about the old loops a player
  brings to the highest table — Channel-Fireball, the infinite turn, the
  Vise behind a Moat, decking — is `docs/arzakon.strategy`, section 4.

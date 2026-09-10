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
| `plays_engines` | off | off | on | on | a permanent that pays over time — a Mishra's Factory, a Disrupting Scepter, a Jayemdae Tome, and since 2026-09-10 a TOKEN MAKER, which is the same sentence with a body in place of the card: The Hive, Boris Devilboon, Master of the Hunt, Serpent Generator and Necropolis of Azar turn mana the turn has nothing else to do with into a creature that stays. The scorer had no arm for a payload that is a permanent which did not exist a moment ago, so all five fell through it and not one token had ever been made in this AI's life. Priced as the BODY (`AiPlayer._token_value`, the evaluator's own creature arithmetic read off the row a card-local effect cannot state for itself) and never as a constant, so a Wasp beats a Minor Demon; bought at the mana sink, because a token is permanent and the ability that makes one has every later moment to be used at. What one activation GUARANTEES is the whole of the reading — the Spawn of Azar's random 1..3 is read at its floor — so the two coin flips in the pool (Bottle of Suleiman, Pandora's Box) have no row and stay unbought |
| `pays_sacrifices` | off | off | on | on | an ability whose cost is one of its own permanents — Strip Mine, a Digging Team |
| `casts_timed_spells` | off | off | on | on | a spell whose only moment is outside its own main phase — a Festival, a Siren's Call |
| `minds_pain` | on | on | on | on | a City of Brass is not a Plains; on everywhere (see below) |
| `fits_auras` | on | on | on | on | hangs a friendly aura only on a creature it gives something to — no vigilance on a Wall; on everywhere, for the same reason |
| `mulligans` | on | on | on | on | judges the opening hand under the Paris rule by the MANA in it (`AiMulligan`: none, all, too few or too many for the hand's size, or mana that casts none of its spells; nothing below four cards goes back); on everywhere — keeping a no-land seven is a malfunction, not a weakness. Since 2026-09-10 the band's FLOOR counts mana and its CEILING counts lands, because they are two different questions: a Mox is a land drop that does not use the land drop up, a Black Lotus is three of them at once and a Mana Crypt is two, so a hand of one Island and two Moxen — four mana on turn one — is no longer thrown back as "1 land in 7", while "nothing but land" still counts lands alone because a Mox is a spell. Named by SHAPE ({0} and a printed mana ability, seven cards in this pool and not one of them named in the code), ONE-DIRECTIONAL (it can only ever turn a mulligan into a keep) and no rung of its own. The shipped five hold no such card and mulligan at exactly the rates they did — 16.6 / 11.6 / 9.8 / 13.7 / 14.3% of their sevens, 4 000 hands each, to the tenth of a point before and after — while The Deck's own lists roughly halve theirs (20.2 → 8.3%, 22.6 → 9.8%, 36.2 → 16.6%), nineteen 1997 ENEMY decks do the same (Dracur 33.6 → 22.2%, Prismat 30.5 → 17.9%, Kiska-Ra 29.6 → 21.1%) and the pool's one landless list stops mulliganing to the floor every single game (100 → 3.1%, mean kept hand 4.00 → 6.97). Sixty-nine of the 217 loadable decks hold one of the seven cards. P12's OTHER escape, Forge's own — keep a one-lander when the library holds fewer than one land in seven — fires on exactly ONE of the 217 decks this pool can load, and that deck is already fixed by the census without any ratio in it, so it was measured and not kept |
| `feeds_worst` | on | on | on | on | asked which of its own to give up when the giving is no cost it chose — The Abyss's meal, Lord of the Pit's tribute, Mana Vortex's land, a Sylvan Library's discard — it gives the least valuable, not the best; on everywhere, the same reason |
| `spares_own` | on | on | on | on | never fills a harmful spell's slots with its own permanents unless the evaluator prices giving them up below zero — no Detonate on its own Mana Vault, no Winter Blast padded with its own creatures (the owner's playtest, 2026-09-08); on everywhere, the same reason |
| `prices_liabilities` | on | on | on | on | knows that a permanent of its OWN can be worth less than nothing: the reckoning (a permanent whose printed line says losing it loses the GAME is never given up — a Lich), the dead weight (tapped, not untapping, every ability needing the {T} it cannot pay — a Mana Vault with no {4}, a creature under a Paralyze whose {4} we cannot reach; since the fifth pass the escape printed on the AURA counts, so an Angel we could free for {4} is an Angel again) and the toll it still takes each turn, priced for the turns our mana needs to reach the price the card itself prints. It is what opens `spares_own`'s one door: with it the AI Detonates the Vault it cannot untap and keeps the one it can — and since the same pass it reads the sting a punisher deals its target's controller on BOTH sides of the table, so a Detonate on their Nevinyrral's Disk with the opponent at four is the kill it always was; on everywhere, the same reason |
| `prices_fallout` | on | on | on | on | prices what its own spell does to its OWN side of the table on the way past — the other half of `spares_own`, which only guards the slots. Volcanic Eruption ("destroy X target Mountains, then that many damage to each creature and each player") is the pool's one card of the shape: on, the planner walks every affordable X, prices the blast on the sweeper's own scale (`_sweep_value`: what dies on each side, both life totals, never an X lethal to us), refuses one that would put it on its own `chump_threshold` or below unless the blast wins outright, and keeps the cheapest X worth casting. Off, the blast is free and the X is whatever the lands will pay: at five life against six Mountains it cast for X=6 and killed itself. On everywhere, the same reason; the panic line gives it a per-rung shape without a number of its own |
| `counts_cards` | off | off | on | on | sizes X draws and discards to the hands and libraries in front of it; aims a draw at an empty library |
| `levels_boards` | off | off | on | on | prices Balance by what each side would lose — and since 2026-09-10 THE LAND SWEEP, which is the same sentence with only the land clause: a sweeper whose every kill is a LAND (Armageddon, and the sideboards' Flashfires and Tsunami) levels both manabases, so it is priced by what each side would lose rather than by a head count. Each land it takes is worth what it is worth to its controller (`Evaluator.land_value` — scarcity, a dual, the only source of a colour, a land that does more than make mana) instead of `permanent_value`'s flat 1.0, so a Library of Alexandria and three duals are not four Plains; and whatever THEIR board gets through that ours does not is charged against the swing at the reaper's rate (`AiPlayer._drought_clock`, the damage each side puts through the other's blocks — the reading `times_sweeps`' relief already asks their next attack with — priced by `_life_price`). An all-lands sweep kills nothing on the table, so both boards go on hitting each other with no mana to answer with, and the pilot used to Armageddon on the land count alone with two Serra Angels facing it |
| `tutors_for_the_turn` | off | off | on | on | fetches the card THIS TURN wants instead of the dearest card in the deck. A search of our own library is the one gain ask with an ORDER rather than a maximum (`AiPlayer._tutor_pick`, casting P9): a LAND when we are short of them, hold none and can cast nothing off the board's own mana — taken for the colour the hand is missing; then the best of what NEXT TURN's mana reaches; then the card worth most on THIS BOARD, which is a sweeper priced by what the sweep would swing and a leveller by what each side would lose. Off, the answer was `Evaluator.card_value` and nothing else, so in a hundred and fifty logged games The Deck's Demonic Tutor named exactly three cards out of the sixty in the deck and never a land |
| `paces_draws` | off | off | on | on | refuses an optional draw that would hand the opponent the library race — a Tome's tick, an Ancestral, a tutor's card, and since the third pass the extra draw step a Time Walk buys |
| `holds_duplicates` | off | off | on | on | keeps a second legend or world in hand instead of burying the first |
| `animates_to_attack` | off | off | on | on | buys a Factory's animation only when the attack it would declare sends the body; until then the body is no mana source, and on their turn a creature-until-end-of-turn is no blocker |
| `times_sweeps` | off | off | on | on | prices a board wipe by the damage it keeps off its life as well as the permanents it trades — lethal-worth when the sweep is the out, a creature its Abyss will eat never counted — and fires one it can activate in the opponent's combat, after the attackers are declared and before the damage (the Disk as a Fog) |
| `trusts_abyss` | off | off | on | on | keeps its counterspell when the creature spell on the stack is the next meal of a feeder on its table — The Abyss will destroy it at their upkeep — and spends it on what the feeder cannot eat |
| `pumps_to_attack` | off | off | on | on | judges its own creature at the size its OPEN MANA can reach when a combat declaration is made — a Carrion Ants behind four Swamps is a 4/5, not a 0/1 — attacking AND blocking (the name is the half it was born for), with the second main phase's cast kept whole on its own turn and the held instant on both, a capped breath counted at its cap, and the two card-local firebreathers (Dragon Whelp, Nalathni Dragon) read at last — three breaths and never the fourth unless that attack ends the game; and since the third pass the breaths the pilot BUYS are the ones the declaration was priced with — the split of the one pool is spent as it was allotted, and a trampler's overflow is measured against the toughness that will actually be there; and since the fourth, the BURN SPELL ON THE STACK — a Frozen Shade with Swamps open grows out of a Lightning Bolt instead of dying with the mana up, and the breath is asked before the pump instant in hand because the mana untaps and the card does not; and since the fifth, the breaths a block was DECLARED on are bought before the pilot's own pre-emptive regeneration shield can spend them — the one thing that was measurably breaking its own plan |
| `spends_counters` | off | off | on | on | pays a cost of "remove N <kind> counters from this permanent" — the AI had never removed one in its life, so an Osai Vultures sat on its carrion counters and a Scavenging Ghoul never regenerated. Spendable when NOTHING BUT THE COST READS THE COUNTER: refused when the kind's own NAME is a P/T delta (a Triskelion's +1/+1 counters are the 4/4) and refused when the permanent's live `damage_eats_counters` names it (a Rock Hydra's heads are its life). What is left is fuel — carrion, corpse, husk, matrix, dream — and fuel is worth zero to every reader until it is spent, so the effect is the whole trade |
| `ranks_counters` | off | on | on | on | picks WHICH counterspell answers a spell instead of firing whichever sat first in its hand, and pays an unless-cost's X to the caster rather than to the mana on the table. Until 2026-09-10 `_try_counter` walked the hand in order, so a Mana Drain and a Power Sink in one hand were spent by the shuffle, and Power Sink's X was "as deep as the mana goes" — eight Islands to make a price of one unpayable. The ranking is five readings, none of them a card's name: can we pay for it (a counter the mana does not cover used to end the search with a pass), does it actually STOP the spell (a printed "unless its controller pays" price the caster can simply pay is no counter — the hard card goes ahead of it, which is also why a Sink is not cast at all when they can pay it and something else answers), what it costs us now with its X included, the narrow card before the wide one, and then the card the evaluator would rather keep — so a Power Sink for one takes the small threat on a tapped-out turn and the Mana Drain is still in hand for the Serra Angel. Magician and up, the rung `holds_instants` is on: an Apprentice never casts a counterspell at all, so it is as inert there as `counter_threshold` |
| `holds_x_burn` | 0 | 0 | 3 | 5 | the smallest REACH — the largest X the mana can pay — at which the profile will point an X burn spell at a creature while the game is young; 0 never holds. A Fireball is two damage on turn three and eight on turn nine, and the deck holds it because it is the reach: `_size_x_burn` sized the X to the victim, which is right, and had no reading of whether the card was worth casting yet, so a Wizard on three Mountains spent one of Mountain Artillery's two Fireballs on a Grizzly Bears. The hold is bounded by the game's own age (only while the turn count is under twice the number, in player turns) and lifted by readings the pilot already makes rather than by a constant: a burn that wins is returned by the face arm before this is asked, and `AiPlayer._in_danger` — the panic line read a fourth time, against the damage their board would actually land through the blocks this seat would make — spends the card the moment the clock says to. The face arm still runs under the hold. It reads the REACH and not the shot on purpose: gating on the X actually paid refuses a Fireball for four at a Serra Angel for a game's first nine turns, which the suite has pinned as correct since the Fireball was first sized |
| `reads_gaze` | off | off | on | on | reads the three printed lines that settle a combat without ever entering the damage arithmetic, all three at `AiPlayer._dies_to`'s own seam. THE GAZE: a Cockatrice or a Thicket Basilisk destroys whatever it blocks or is blocked by, at end of combat — so a Craw Wurm no longer swings into one for free (`_attack_risk` 0.0 before, 2.5 after) and our own Cockatrice stops watching a Craw Wurm walk past for six. THE RAMPAGE (CR 702.23): the engine gives a blocked attacker +N/+N for each blocker past the first and the gang rung ignored it, so two Grizzly Bears ganged a Craw Giant on `2+2 >= 4`, met an 8/6, died both and took four trample; the number is counted now wherever a gang is priced, the crack-back model included. THE EXECUTIONER: an untapped Royal Assassin is why a non-vigilant body stays home, because tapping to attack is what makes it a legal target — a Hypnotic Specter used to swing past a 1/1 it cannot be blocked by and be in the graveyard before the damage step. Nothing names a card: two printed lines read as shapes (`EffectIntent.is_gaze`, `EffectIntent.destroys_the_tapped`, each with the card's own condition or spec put to it) and one engine field (`CardInstance.cur_rampage`) |
| `reads_manlands` | off | off | on | on | counts a permanent that can animate ITSELF as a body in the combat about to happen — theirs when we attack, ours when we block, and the two halves are one knob because either alone is a lie. Theirs: the attack was priced against their untapped CREATURES only, so a Mishra's Factory with `{1}` open was invisible to the cohort, to the pump rider and to the crack-back model, and a Llanowar Elves walked into a 2/2 that costs them a mana; the declaration is made now with their affordable animations hung on under the journal (`AiPlayer._attack_choice_reading_manlands`), the mirror of `animates_to_attack`'s own probe. Ours: `_animation_value` prices an animation by the ATTACK it enables and answers 0.0 at every moment but our own precombat main, so no rung had ever animated a Factory to BLOCK — three untapped lands watched a Grizzly Bears hit for two. It is bought at the moment `_defensive_combat_response` already owns, once their attackers are declared, and only when the block declaration itself would use the body AND the body comes back — `_animation_value`'s own refusal mirrored, because what animates here is almost always a LAND. Sorcerer and Wizard, with `animates_to_attack` and `plays_engines`. Nothing here names a card: the shape is `EffectIntent.animates`, and their mana is counted the way `AiPlayer._shieldable` already counts theirs — untapped permanents, public to both seats |
| `reads_pumps` | off | off | on | on | reads the pump on a creature it does NOT control as part of that creature's SIZE, which is the mirror of `pumps_to_attack` and the half that had never been built: two days of passes taught the pilot to size its own attack, block and survival by the mana it holds, and it had never once feared the same mana on the other side of the table. A Shivan Dragon with three Mountains open was a 5/5 and a Frozen Shade behind four Swamps was a 0/1, so a Grizzly Bears was sent into one at `_attack_risk` 0.00 — *we kill it and live* — and was in the graveyard with the Shade still standing and their life still twenty. `AiPlayer._pump_reach` answers what their body can grow to: the cheapest self-targeting `PumpEffect` ability with no tap cost, times the activations their OPEN SOURCES pay for, under three caps — the card's own *activate only N times each turn* (a Fire Drake behind five Mountains is a 3/2, not a 7/2), ONE POOL shared among the bodies of theirs this combat can ask it of (three Carrion Ants behind six Swamps are three 2/3s, not three 6/7s), and the smallest count past which no kill-or-survive answer on the board could still change (a Shade behind ten Swamps facing one Grizzly Bears is +2/+2). ONLY THE KILL TEST reads it and never the face damage, so the cohort still prices its damage through. AND IT IS ASYMMETRIC, because the Lab put it that way rather than the design: their pump deciding whether THEIR body dies is read everywhere, at `_dies_to`'s own seam; their pump deciding whether OURS dies is read only where we are choosing to SEND a body into it — `_attack_risk` and `_cohort_value`, the two halves of the attack declaration — because a blocker of ours that dies to their breath has SPENT their mana, and mana spent killing a blocker is mana that did not reach our face, while an attacker of ours that dies to it has bought nothing at all. Nothing names a card: the shape is `EffectIntent.pump_self`, and their mana is counted the way `AiPlayer._shieldable` already counts it — untapped permanents, public to both seats |

`minds_pain`, `fits_auras`, `mulligans`, `feeds_worst`, `spares_own`,
`prices_liabilities` and `prices_fallout`
are the seven knobs that are on at every rung, and the reason is the
line between weak and broken: an Apprentice that taps City of Brass for
its last life to cast a Grizzly Bears is not a worse player, it is a
malfunction — and so is one that puts Eternal Warrior on a Wall of
Swords, or keeps a seven with no land in it (the owner's playtests,
2026-09-08) — or throws back a seven of one Island and two Moxen
because it counted LANDS where the question was MANA (2026-09-10: The
Deck's own lists were mulliganing a fifth to a third of their sevens,
two to three times the rate of a starter with the same land count, and
the pool's one landless list mulliganed to the four-card floor in every
game it ever played) — or feeds its Serra Angel to The Abyss with a Grizzly Bears
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
games, and the knob's other half is what those two hundred games moved),
or casts a Volcanic Eruption for X=6 at five life and dies to its own
sorcery while the opponent walks away at twelve (2026-09-09: the reader
had no model for the card-local effect, so the blast on its own
creatures and its own face cost the planner nothing — the census that
named the card had it right for the wrong reason, since it is a
SIDEBOARD card in all three decks that hold it and a free-play census
never draws it).
They are knobs only so the Deck Lab
can run the null; with
`mulligans` off the pilot falls back to `DecisionAgent`'s plain rule,
which throws back only the two hands the 1997 game named — no land, all
land — down to the same floor of four.

The Apprentice's `counter_threshold` is in brackets because it never
reads it — with `holds_instants` off there is no counterspell to price.

`AiProfile` carries one field that is NOT in the table and not a
difficulty knob at all: `w_hand` (2026-09-10), the weight
`Evaluator.position_score` puts on a card-in-hand lead. Every preset
ships the same 1.5 — `Evaluator.W_HAND`'s own value — and no rung moves
it. It lives on the profile because `apply_overrides` is how the Deck Lab
puts a NUMBER on a seat, and casting note P11 wanted the hand:life ratio
settled by a sweep (§4, "THE HAND'S WEIGHT": it was, and nothing moved).

## 3. Rung by rung, in the player's terms

**Apprentice.** Knows every play and fumbles a third of them. Swings
recklessly (`aggression` 0.75): attacks that trade badly, burn at the
face. Plays "my turn only" Magic — it never holds mana open, never
counters, never Fogs, never casts a trick in your combat, and lets the
automatic damage-prevention order apply. Panics late (life 3). Never
sideboards between duels, never looks past its own combat, and treats
every permanent as what it is worth today: a Factory is a land, a Tome is
an artifact, a Hive is an artifact too — ten mana and it never makes a
Wasp — and a Strip Mine is never cracked. Your Factory is a land to it as
well, so it swings a Grizzly Bears into the `{1}` you have open; and it
reads a combat as power against toughness and nothing else — into the
Cockatrice, under the Craw Giant's rampage, and past the Royal Assassin
that takes the attacker it just tapped. What you see is the shape of
the 1997 game's easiest table — a wizard with good cards and no patience.

**Magician.** Fumbles a fifth. The reactive game switches on: it holds
instants and the mana for them, blocks with tricks, and counters — but
only the biggest threats (`counter_threshold` 7.0), so most of your
spells resolve. Sideboards two cards. Still no crack-back read, still no
engines, sacrifices, timed spells or card-counting: it will cast a Mind
Twist for X into an empty hand, and a Braingeyser sized past its own
library, because those layers are the Sorcerer's. It answers a burn
spell aimed at one of its creatures with a Giant Growth from hand, but
never with the creature's own breath, and it never removes a counter to
pay for anything: both of those are the Sorcerer's too. So are the two
combat READS — the printed line that kills what it blocks, the rampage
that grows under a gang, the assassin that answers a tapped body, and the
manland on either side of the table. What it does do,
from the moment it counters at all (2026-09-10, `ranks_counters`), is
choose WHICH counter: the card that actually stops the spell before the
one the caster can pay through, the cheaper before the dearer, the
narrow before the wide, and Power Sink's X one more than the mana they
can still reach rather than every Island it has — so a Sink takes the
small threat on a tapped-out turn and the Mana Drain is still in hand
when the Serra Angel comes. This is the rung the
owner's ruling keeps as it is — the visible step between "reacts" and
"plans".

**Sorcerer.** Fumbles one action in twelve. Balanced (`aggression` 0.5),
panics at 5, counters a tier smaller (5.5), sideboards three. Reads your
crack-back before committing an attacker — 1 500 leaf evaluations, half
the Wizard's, so its search truncates on the wide boards the Wizard still
resolves. Every capability is on: it activates engines and knows what
they are worth over time — including the five that pay in BODIES, so a
Hive buys a Wasp, a Boris Devilboon a Minor Demon and a Necropolis of
Azar its Spawn, each at the opponent's end step where the mana would be
lost anyway — pays a Strip Mine or a Digging Team for a
better body, casts a Festival at your upkeep and a Siren's Call before
your attackers, sizes its X spells — and since 2026-09-10 holds the X
BURN while its whole reach is under three (the Wizard waits for five),
so a Fireball is no longer spent on a Grizzly Bears on turn three and no
longer waits once their board is a clock this seat's own blocks cannot
absorb — prices a Balance, and an Armageddon: it holds that one while
your board is the one that would win the mana drought it makes, and
casts it with a Library of Alexandria and three duals of its own only
when the manabase it gives up is not the better one; fetches with its
Demonic Tutor the land it is stuck without, the creature next turn can
actually cast, or the Wrath your board is asking for rather than the
dearest card in its deck, paces its draws to
the libraries (a Time Walk's extra draw step among them), keeps a
second The Abyss in hand, animates a Factory
only for an attack it will actually declare, sends a firebreather at the
size its open mana can reach instead of at its printed 0/1 — and blocks
with it at that size too, so a Carrion Ants behind six Swamps eats a
Craw Wurm instead of watching it go past — and grows that same Carrion Ants out of a Lightning Bolt
aimed at it instead of watching it die with the Swamps untapped — and holds
its Nevinyrral's Disk for the attack it answers — priced by the damage it keeps off the
pilot, fired once the attackers are named and before they connect —
and keeps its Counterspell in hand when the creature on the stack is
one its Abyss will eat at their upkeep. It also spends a counter as a
COST where a counter is fuel: two carrion counters off an Osai Vultures
for the +1/+1 that wins a block, a corpse counter off a Scavenging Ghoul
for the regeneration, a husk counter off a Necropolis of Azar for the
Spawn — and never a Triskelion's +1/+1 counters, which are the body
itself. Since 2026-09-10 it also reads the three printed lines that
settle a combat without appearing in the arithmetic — it does not swing
a Craw Wurm into your Cockatrice, does not gang a rampaging Craw Giant
with two bodies that no longer reach it, and does not tap a Hypnotic
Specter into your Royal Assassin — and it counts a MANLAND as a body on
both sides of the table: your Mishra's Factory with `{1}` open is a
blocker its attack has to price, and its own is a blocker it animates
once your attackers are declared, when the block it would make is one
that brings the land back.

**Wizard.** No mistakes at all. The same decision code, the same
capabilities as the Sorcerer, with twice the search (3 000), the pickiest
panic line (6), the widest counter net (5.0), the more patient X burn
(`holds_x_burn` 5 against the Sorcerer's 3) and four sideboard swaps.
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

THE FOURTH PASS, the same day again: the two things the third one left —
a body in a GANG priced at no breath, and the leftovers spent off the
plan — one FIXED and one RULED. Both were §5 items rather than new
capabilities, so the knob's meaning grew a fourth time and its null did
not move. Seed 11, 1 000 games an arm, five pairs, each run TWICE: once
on the shipped tree and once on this one, so the `on` arms lie side by
side and every game can be compared by its own fingerprint.

- **The null is the null, proved game for game.** Every OFF arm — the
  null pair, the candidate pair at `off`, and both of them on the control
  pair — is byte-identical between the two trees, 1 000 of 1 000, on all
  five pairs: Vampire Lord vs Big Green 19.8%, Kzzy'n vs Big Green 14.3%,
  Vampire Lord vs Summoner 39.9%, vs Summoner (Spells of the Ancients)
  47.9%, vs War Mage 22.6%, each of them the shipped tree's own number to
  the decimal. **Control PASS in every arm of all ten runs** — Big Green
  vs White Knights, 525-475, byte-identical to its null, 1 000 of 1 000.
- **A small gain rather than a wash, and the flips say so even where the
  win rate cannot.** On arm, against the shipped tree's own `on` arm:
  Vampire Lord vs Big Green 23.9% → 25.4%, Kzzy'n vs Big Green 18.4% →
  19.3%, vs Summoner 53.3% → 54.7%, vs Summoner (Ancients) 59.3% →
  59.9%, vs War Mage 55.5% → 55.5%. Every one of those is inside the
  ±4.4-point interval a 1 000-game delta carries, so on any single pair
  it reads as a wash. The census underneath it does not: of the 5 000
  `on`-arm games, **388 played differently and 54 ended differently — 49
  of them won and 5 lost**. A 49-to-5 split of the games that turned is
  not a coin, and the direction is the same on every pair.
- **Where it fires and where it does not.** The gang question wants a
  board with a firebreather, a second body and something neither of them
  kills alone: 150 games of 1 000 differ against Big Green's War Mammoths
  and Craw Wurms, 88 against Summoner's Force of Nature and Colossus, 96
  against Big Green with Kzzy'n's dragons, 54 against the Ancients
  Summoner — and **not one game of the thousand** against War Mage, where
  the board that asks the question never comes up: its Ball Lightnings
  are hasted one-shot swings that the swarm blocks alone or not at all.
- **What it fixes is what the table sees**, the block half's precedent
  again. On the third pass's own board — a Carrion Ants and a Scathe
  Zombies in front of a Force of Nature with six Swamps open — the
  shipped pilot declares the gang, buys NOTHING for it, loses both bodies
  and takes five with every Swamp still untapped. It now buys the six
  breaths the gang was declared on, kills the 8/8, keeps the swarm and
  takes nothing. Put a Hill Giant beside it at eight life and the pilot
  goes from three life and two dead bodies to five life, a dead Force of
  Nature and its spare body still at home. And the counter: a Carrion
  Ants unblocked behind four Swamps and two Islands with a Counterspell
  in hand used to buy six breaths and tap out; it buys the four the
  declaration priced and the counter can still be cast.

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

THE FALLOUT (2026-09-09, `prices_fallout`) is a WASH ON THE SCOREBOARD
and a malfunction removed, and the census that opened the item was right
for the wrong reason.

- WHY THE CENSUS SAW NOTHING. "Volcanic Eruption resolved no cast in
  sixty games either way (0/0)" (`docs/ROADMAP.md`, the Detonate pass)
  is not a planner fault: the card is in the SIDEBOARD of all three
  decks that hold it — Conjurer, Mind Stealer and Thought Invoker, the
  1997 files' `.vRed` sections — and a free-play census never
  sideboards, so it could not be drawn. Put it in a hand and the pilot
  cast it every single time.
- WHAT IT DID THEN, probed on three boards. Nine Islands against six
  Mountains at five life: X=6, life −1, game over, the opponent at 12.
  A Mahamoti Djinn and two Serra Angels of its own against four
  Mountains and a Goblin: X=6, both Angels burnt, to take four lands
  and a 1/1. Two Mountains and nine Islands: X=6 paid for two, four
  mana for nothing, because the X buys TARGETS.
- MEASURED where the card can actually be reached: **Conjurer vs Troll
  Shaman** (two tier-3 1997 originals, `--best-of 3 --sideboard on` —
  the Eruption is boarded in against a red deck by every rung that
  sideboards at all, and it is the FIRST card the heuristic reaches
  for), 1 000 matches an arm, seed 4242, control Big Green vs White
  Knights. Win rate **14.6% → 15.1% (+0.5 ±3.1)**, inside the interval;
  the `off` arm replayed the null 1000 of 1000 and the control is
  byte-identical to its own null in every arm. The knob FIRED in **179
  of the 1 000 matches** and changed the winner in 12.
- WHAT THE WASH IS HIDING is the thing worth having. Over the same
  1 000 matches the pilot cast the Eruption 369 times with the knob off
  and **killed itself with 15 of them**; with it on, 316 casts and
  **none**. The sizing accounts for the rest: it now pays for the
  Mountains that are there rather than for every point its Islands will
  bear, and it steps down from an X its own board would not survive.
  A card that ends the game for its caster once in every twenty-five
  casts is a malfunction, which is why the knob is on at every rung.
- AND THE OTHER HALF OF THAT REPORT — that `AiSideboard` reaches for the
  Eruption against any red deck on a `land:mountain` tally, with no
  reading of what the blast would do to the BOARDER'S OWN creatures — was
  RULED on 2026-09-10 and not built. Reproduced first: against Troll
  Shaman the Eruption scores 5.65 (Thought Invoker, Conjurer) and 5.40
  (Mind Stealer), made of the six Mountains seen (3.00), the five
  creatures seen (1.25) and a damped generic 1.40 — so the land tally is
  the plurality but not the whole of it, and the card is the FIRST one
  boarded in two of the three decks and the third of four swaps in
  Conjurer. Three things decided it. The 1997 designer boarded exactly
  this card against red in all three of those decks (`.vRed` in the
  original `.dck` files), so the heuristic is agreeing with Coyote Tex,
  not overruling him. `prices_fallout` now answers the complaint one step
  later and at the moment it costs something: probed on Conjurer's own
  board of five creatures, the pilot with the knob off casts X=2 to take
  two Mountains and burns four of its OWN creatures for nothing, and at
  five life against six Mountains it casts X=6 and dies — with the knob
  on it declines both, and casts only the X that takes three of theirs
  and six lands with five of ours. And the swap MEASURES as a wash:
  `--best-of 3 --sideboard on` against Troll Shaman at seed 4242, the
  same decks with and without the Eruption in the board, 4 000 matches an
  arm — Thought Invoker 47.9% with and 49.2% without (−1.3 ±2.2), Conjurer
  16.8% with and 15.1% without (+1.7 ±1.6), the two signs opposite and the
  1 000-match run reading +1.9 and +0.3 the other way. A card that is
  sometimes castable is still worth boarding, and it is replacing the
  worst card in the deck by the heuristic's own reckoning (a Power Leak, a
  Sindbad, a Pirate Ship). What is left open is a different reading and is
  named in §5: the sideboard scores a symmetric sweeper's `creature` key
  as a BONUS, which is a general question about Earthquake, Hurricane and
  Wrath of God rather than about this card.
THE FOURTH PASS ON `pumps_to_attack` (2026-09-09, the burn spell on the
stack) is a WASH in win rate, and the reason it is measurable at all is
that the earlier three readings were not: the knob's own numbers on a
board with burn on it are large, and the fourth reading's share of them
is small. Seed 11, 1 000 games an arm, each pair run TWICE — once against
the tree before this landed and once against this one — so the `on` arms
can be laid side by side. Control Big Green vs White Knights.

| pair | null | `on`, before | `on`, after | the burn reading's own |
| --- | --- | --- | --- | --- |
| Vampire Lord vs Mountain Artillery | 18.3% | 25.7% | 26.5% | +0.8 |
| Warlock vs Mountain Artillery | 4.7% | 8.5% | 9.5% | +1.0 |
| Vampire Lord vs Black-Red Raiders | 27.6% | 36.2% | 36.3% | +0.1 |

- THE NULL IS EXACTLY THE NULL, and it was proved twice over. Every
  `off` arm above reads its own null to the decimal on BOTH trees, and
  the published sweep replays as printed: Vampire Lord vs Big Green at
  seed 11 comes out **19.8%** null — the first pass's own number above —
  with 23.9% on the `on` arm, which is the third pass's `on` arm
  unmoved. Big Green points no damage at a creature, so on that pair the
  new reading is never offered a board at all. The control pair is
  525-475 byte-identical to its own null in every arm of all ten runs at
  1 000 games, and 1075-925 in all five at 2 000.
- THE THREE DELTAS ARE +0.8, +1.0 and +0.1 against an interval of ±3.6,
  ±2.2 and ±4.1, so not one of them is visible; what can be said is that
  all three carry the same sign, which is what a rare reading in the
  right direction looks like. At 2 000 games an arm the whole knob reads
  +8.9 ±2.6 and +4.9 ±1.6 on the two Artillery pairs, both clear of zero,
  and that is the first three readings' number, not this one's.
- THE CENSUS SAYS THE READING FIRES AND THE GAMES RARELY TURN ON IT.
  Over 150 logged games of Vampire Lord against Mountain Artillery the
  pilot bought a breath off the stack **23 times** where it had bought
  none, beside 333 ordinary combat breaths; Warlock's two Frozen Shades
  buy 10 in the same 150. So it is about one save every six games with
  four Bolts and two Fireballs across the table, and one every fifteen
  with two Shades in sixty cards.
- WHAT IT FIXES IS WHAT THE TABLE SEES, which is this knob's own
  precedent twice over (the block half, the trampler). A Frozen Shade
  with four Swamps untapped dying to a Lightning Bolt is not a close
  decision the pilot got wrong; it is a play nobody at a table would
  miss.

THE FIFTH PASS ON `pumps_to_attack` (2026-09-10, the plan the pilot broke
itself) is a WASH in win rate, and it is the smallest of the five: it can
only show on a board where the pilot holds a firebreather AND a
regenerator that want the same mana in the same combat. Seed 11, control
Big Green vs White Knights, each pair run TWICE — once against the tree
before this landed and once against this one — so the `on` arms can be
laid side by side game for game.

| pair | null | `on`, before | `on`, after | games that moved |
| --- | --- | --- | --- | --- |
| Vampire Lord vs Big Green, 1 000 | 19.7% | 23.3% | 23.3% | 46 of 1 000 |
| Vampire Lord vs Big Green, 4 000 | 20.3% | 23.4% (+3.0 ±1.8) | 23.4% (+3.1 ±1.8) | 226 of 4 000 |
| Troll Shaman vs Big Green, 1 000 | 16.8% | 16.6% | 16.6% | 0 of 1 000 |

- THE PAIR IS THE ONE THAT CAN ANSWER IT. Vampire Lord holds two
  firebreathers (Carrion Ants, Vampire Bats) and a regenerator
  (Will-o'-the-Wisp) on one colour of land, so the declaration's breaths
  and the pre-emptive shield reach for the same Swamps; Big Green attacks
  every turn it can, which is what puts the question. Troll Shaman is the
  control of a different kind — four Uthden Trolls and a shield's worth of
  red mana, but only ONE firebreather, a 5/5 flier that is nearly never
  the body a plan is written for — and it moves nothing at all, which is
  what "this only fires when both halves are on the table" looks like.
- THE NULL IS EXACTLY THE NULL, twice over: the `off` and null arms of
  every run are byte-identical between the two trees, 4 000 of 4 000,
  and the control pair is 2150-1850 (525-475 at 1 000) byte-identical to
  its own null in every arm of all six runs.
- 226 OF 4 000 GAMES PLAYED DIFFERENTLY AND 8 ENDED DIFFERENTLY — six won,
  two lost, 938 wins against 934. The knob's own delta reads +3.1 ±1.8
  after and +3.0 ±1.8 before, so this pass's share of it is +0.1 against
  an interval twenty times that: a wash, and it should be.
- WHAT IT FIXES IS WHAT THE TABLE SEES, the same precedent the block half,
  the trampler and the burn save shipped on. A pilot that declares a gang
  on six breaths, spends one of the six Swamps shielding a Drudge
  Skeletons, then buys NOTHING and watches both blockers die and five
  trample through with five Swamps untapped is not making a close decision
  badly; it is breaking its own plan in front of the player.
- ONE READING WAS TAKEN AND NOT PUBLISHED HERE BEFORE: on this tree the
  1 000-game reading of Vampire Lord vs Big Green at seed 11 is 19.7%
  null / 23.3% `on`, where the fourth pass's paragraph above prints 19.8%
  / 23.9%. The difference is one game and six, it is the same on BOTH
  trees of this pass's A/B, and the control replays 525-475 exactly as
  printed — so it is a stale number from a pre-merge worktree, not a
  moved null. The 4 000-game reading in the table is the one to quote.

`spends_counters` (2026-09-09) is a WASH on every pair it can fire on,
and the census is where the change actually shows. Seed 11, control Big
Green vs White Knights, byte-identical to its own null in every arm of
all six runs (525-475 at 1 000, 1075-925 at 2 000).

| pair | null | `on` | delta (1 000) | delta (2 000) |
| --- | --- | --- | --- | --- |
| Lord of Fate vs Big Green | 33.6% | 33.9% | +0.3 ±4.1 | +0.2 ±3.0 |
| Witch vs Big Green | 16.8% | 17.2% | +0.4 ±3.3 | +0.0 ±2.3 |
| Lord of Fate vs Mountain Artillery | 32.2% | 32.6% | +0.4 ±4.1 | +0.4 ±2.9 |

- THE CENSUS, 150 logged games a pair, the same seeds. Witch (three
  Scavenging Ghouls): the Ghoul regenerates off a corpse counter **53
  times** where it had done so never, and the seat's regeneration
  shields go from 326 to 364 — fewer than 53 more, because some of those
  corpse counters replace a shield it was paying {B} for, which is the
  right way round. Lord of Fate (three Osai Vultures, two Necropolis of
  Azar): the birds spend their carrion **11 times** in 150 games where
  they had spent none.
- SO IT IS A DEAD CARD MADE LIVE RATHER THAN A DECISION RETUNED, and the
  win rate says as much: the cards it wakes are a 1/1 flier's +1/+1 and a
  2/2's regeneration, neither of which decides many games. It ships for
  the reason `feeds_worst`, `times_sweeps` and the Detonate half of
  `prices_liabilities` shipped: an Osai Vultures blocking at 1/1 with
  four carrion counters on it is a malfunction at the table, whatever the
  thousand games say. It is a rung and not a floor because paying a
  non-mana cost is a LAYER — the same argument `pays_sacrifices` is
  gated by — and the Apprentice that never regenerates its Ghoul is
  playing the same poorer game as the one that never cracks a Strip Mine.

THE BODY THE SCORER COULD NOT SEE (2026-09-10, the TOKEN ARM of
`plays_engines`) is a WASH in win rate with the same sign on every pair,
and five dead cards made live. It is an extension of a knob rather than a
new one, so the knob's meaning grew and its null did not move. Seed 11,
control Big Green vs White Knights, each pair run TWICE — once on the
tree before this landed and once on this one — so the `on` arms lie side
by side and every game can be compared by its own fingerprint.

| pair | null | `on`, before | `on`, after | delta (1 000) | delta (4 000) |
| --- | --- | --- | --- | --- | --- |
| Lord of Fate vs Big Green (2 Necropolis) | 33.8% | 33.8% | 34.4% | +0.6 ±4.1 | +0.6 ±2.1 |
| Crag Hydra vs Big Green (3 The Hive) | 21.0% | 21.0% | 21.9% | +0.9 ±3.6 | +0.8 ±1.8 |
| Lord of Fate — Ancients vs Big Green (2 Necropolis) | 34.6% | 34.6% | 35.2% | +0.6 ±4.2 | +0.7 ±2.1 |

(The 4 000-game column is its own run with its own null — 35.4%, 21.5%,
33.1% — not a longer version of the 1 000-game one; what it buys is the
interval, and all three deltas keep their sign and their size inside it.)

- THE `ON` ARM BEFORE THIS LANDED WAS THE NULL TO THE DECIMAL, on all
  three pairs, and that is the report reproduced at the Lab's own scale:
  none of these three decks owns a Factory or a Scepter, so
  `plays_engines` had nothing left to fire on and the knob did literally
  nothing for them — 33.8/33.8, 21.0/21.0, 34.6/34.6 at 1 000 games an
  arm. The census says the same thing card by card: over 150 logged games
  Lord of Fate makes **25 Spawn of Azar where it had made 0**, Crag Hydra
  **27 Wasps where it had made 0**, and Nether Fiend (four Hives in a much
  faster deck) **7 where it had made 0**.
- THE NULL IS EXACTLY THE NULL, proved game for game rather than by
  argument. Every `off` arm — the null pair, the candidate pair at `off`,
  and both control arms — is byte-identical BETWEEN THE TWO TREES on all
  three pairs: 5 000 games a pair, 15 000 in all, **not one game
  different**. The control pair is byte-identical to its own null in
  every arm of all six 1 000-game runs (525-475) and all three
  4 000-game ones (2150-1850), and the `plays_engines=on` control arm is
  identical too,
  which is the stronger statement: Big Green vs White Knights owns no
  Factory, no Scepter and no token maker, so the whole knob is silent
  there.
- THE FLIPS SAY MORE THAN THE RATES. Of the 3 000 `on`-arm games,
  **192 played differently and 23 ended differently — 22 won and 1
  lost** (Lord of Fate 7-1, Crag Hydra 9-0, the Ancients 6-0). A 22-to-1
  split of the games that turned is not a coin, and the direction is the
  same on every pair.
- WHAT IT FIXES IS WHAT THE TABLE SEES, which is this file's own
  precedent five times over. A Hive on the battlefield with ten untapped
  Islands behind it and no card in hand that wants them, turn after turn,
  is not a close decision the pilot got wrong; it is a permanent nobody
  at a table would leave alone. The same goes for a Necropolis with three
  husk counters on it — the counter cost had been opened the day before
  and the Spawn still could not be bought.

THE TOLLS (2026-09-10, `prices_liabilities`) is the FIFTH pass on the
liability knob and it closes the four questions §5 was left with — TWO
RULED and TWO FIXED — so the knob's meaning grew twice and its null did
not move at all. Seed 11, control Big Green vs White Knights, and every
pair run TWICE: once on the tree the liability pass shipped and once on
this one, so the `on` arms lie side by side and every game can be
compared by its own fingerprint.

- **THE NULL IS EXACTLY THE NULL, and this time across two trees.**
  Every `off` arm, every `null` arm and EVERY ARM OF THE CONTROL PAIR is
  byte-identical between the shipped tree and this one, game for game, in
  all SEVEN matched runs — five deck pairs, at 1 000, 2 000 and 4 000
  games an arm, 65 000 games of `off` and control compared one by one. The
  shipped tree's own sweep also replays the PUBLISHED numbers to the
  decimal: War Mage vs Crag Hydra 45.3% null / 45.5% `on` at 1 000 and
  45.8% / 45.6% at 2 000, War Mage vs Big Green 11.7% / 11.5% — which is
  the liability pass's own table above, read back. The control is
  525-475 at 1 000, 1075-925 at 2 000 and 2150-1850 at 4 000,
  byte-identical to its own null in every arm of all FIFTEEN runs.
- **THE DETONATE'S OTHER HALF IS A SMALL GAIN, and the flips say so
  where the win rate cannot quite.** War Mage (three Detonate) against
  Crag Hydra (four Onulet, three The Hive, two Soul Net): the `on` arm
  goes 45.5% → **47.1%** at 1 000 games an arm and 45.6% → **46.8%** at
  2 000, so the whole knob on that pair moves from −0.2 ±3.1 to +1.0
  ±3.1. Both deltas are inside the interval a 2 000-game arm can see; the
  census under them is not. Of the 2 000 `on`-arm games **207 played
  differently and 33 ended differently — 28 of them won and 5 lost**. A
  28-to-5 split is not a coin.
- **AND AGAINST A DECK WITH NO ARTIFACT ON IT, NOT ONE GAME OF A
  THOUSAND MOVES.** War Mage vs Big Green — the same three Detonates,
  nothing across the table to point them at — is 11.5% on both trees and
  **0 of 1 000 games differ**. That is the reading's own negative
  control: it fires on their artifacts and on nothing else.
- **THE AURA'S {4} IS A WASH, and the honest reading of it leans very
  slightly the wrong way.** The pair that puts the question is a seat
  asked for one of its own every turn against a deck holding Paralyze:
  Azaar - Lichlord (two Lich, three Sengir Vampire, three Juzám Djinn)
  vs Centaur Shaman (Spells of the Ancients) (four Paralyze, four Copper
  Tablet) at 4 000 games an arm — null 61.6%, `on` 66.6% before and
  **66.5%** after — and against A Royal Pain (four Paralyze) at 2 000 —
  null 58.0%, 62.4% before and **62.2%** after. Over the two pairs 374 of
  6 000 `on`-arm games play differently and 43 end differently: **17 won,
  26 lost**, which at that count is a coin (−9 games of six thousand,
  against a ±2.1-point interval). Alt-A-Kesh (two Lord of the Pit) vs the
  same Royal Pain is a third pair where the whole KNOB does nothing —
  32.0% in every arm, 0 of 2 000 games different either way.
- **SO IT SHIPS FOR THE REASON `feeds_worst`, `times_sweeps` AND THE
  DETONATE HALF SHIPPED,** and the numbers are said plainly rather than
  dressed up: a Serra Angel under a Paralyze with four mana open, handed
  to the first "give up one of yours" ask while a Grizzly Bears stands
  beside it, is a malfunction at the table whatever six thousand games
  say. The reading is also the one the knob already makes for a Mana
  Vault whose {4} is in reach — full worth, the untap not charged — so
  refusing it for an aura and granting it for an artifact would be two
  rules for one sentence.
- **THE TWO RULINGS COST NOTHING BECAUSE THEY BUILT NOTHING.** A toll
  with no printed escape and a symmetric toll are both left exactly as
  the liability pass left them; §5 carries the arguments. The short of
  it: the first wants a HORIZON and this engine has none, and the second
  turns out to be one card — Copper Tablet — once Manabarbs is refused
  for firing on a land being tapped and Karma, The Rack, Storm World and
  Power Surge for printing a count the reader will not do.

THE THREE READS THE COMBAT MATHS NEVER MADE (2026-09-10, `reads_gaze`)
is a small GAIN on both pairs the Forge note names, and the two readings
that can be measured want reading apart: one turns a great many games and
wins a few more than it loses, the other turns few, wins nearly all of
them, and is CLEAR OF ZERO at four thousand games. Seed 11, 2 000 games
an arm unless the row says otherwise, control Big Green vs White Knights.

| pair | null | `on` | delta | games that turned |
| --- | --- | --- | --- | --- |
| Big Green vs Forest Dragon (4 Cockatrice, 4 Thicket Basilisk) | 77.8% | 79.3% | +1.5 ±2.5 | 213 of 2 000 — 121 won, 92 lost |
| Big Green vs A Royal Pain (4 Royal Assassin) | 65.8% | 68.3% | +2.6 ±2.9 | 75 of 2 000 — 63 won, 12 lost |
| the same pair at 4 000 games | 66.6% | 69.1% | **+2.4 ±2.0, clear of zero** | 152 of 4 000 — 125 won, 27 lost |

- **THE NULL IS EXACTLY THE NULL, and it was proved by replay rather than
  by argument.** The `pays_sacrifices` sweep of the Deck Lab manual —
  Dracur (Spells of the Ancients) vs Big Green, 1 000 games an arm, seed
  11 — was run on the tree before these two knobs landed and on the tree
  after with `reads_gaze=off,reads_manlands=off` forced on both seats,
  and all **6 000 games are identical game for game**: the same log
  fingerprint, the same winner, the same turn count, 24.9% null either
  way, with the published control record 525-475 replayed to the game.
  (The `on` arm reads 27.2% against the 27.3% §4 prints for it, and it
  reads 27.2% on BOTH trees — one game of a thousand on an arm where a
  DIFFERENT knob is on, which is a stale published number and not a moved
  null. The same thing happened to the fifth pump pass and is recorded
  above.) Every sweep below carries its own control verdict, and Big
  Green vs White Knights is byte-identical to its own null in every arm
  of all of them (1075-925 at 2 000, 525-475 at 1 000).
- **THE GAZE TURNS A LOT OF GAMES AND WINS A FEW.** Against a deck with
  EIGHT gaze creatures in it, 897 of the 2 000 `on`-arm games play
  differently — the reading is in the attack declaration, the block
  ladder and the crack-back matrix at once, so almost every combat on
  that board moves — and 213 end differently, 121 won against 92 lost. A
  121-to-92 split is two standard deviations from a coin and no more, so
  the honest reading is "a small gain, the same sign as the delta".
  What it fixes is what the table sees, which is this file's own
  precedent several times over: a Craw Wurm walking into a Cockatrice
  because `_attack_risk` called the swing free, and a Cockatrice of ours
  standing still while a Craw Wurm goes past for six, are not close
  decisions the pilot got wrong.
- **THE EXECUTIONER IS THE SHARPER OF THE TWO, AND IT IS DECIDED AT FOUR
  THOUSAND.** Only 222 of 2 000 games play differently — a Royal Assassin
  has to be untapped, past its sickness and looking at a non-vigilant
  attacker — but 75 of them end differently and **63 are won against 12
  lost**, which at that count is not a coin at all. Run again at 4 000
  games an arm the delta reads **+2.4 ±2.0 and is clear of zero**, with
  451 games playing differently and 152 ending differently, **125 won
  against 27 lost**. The reproduction says why: a Hypnotic Specter
  swinging past a 1/1 it cannot be blocked by, `_attack_risk` −1.0
  ("nothing over there may block it"), and the body in the graveyard
  before the damage step with their life still twenty.
- **MEASURED AT EVERY RUNG, which is what the Forge note asked for
  before the ramp ruling is applied to it** (`docs/forge/combat.md` P3:
  *"Measure it at every rung and let the numbers argue"*). The assassin
  pair, 1 000 games an arm, both seats at the same preset, control PASS
  and byte-identical in every arm of all four runs:

  | pilot | null | `on` | the knob's own delta |
  | --- | --- | --- | --- |
  | Apprentice | 76.9% | 75.7% | −1.2 ±3.7 |
  | Magician | 69.5% | 71.6% | +2.1 ±4.0 |
  | Sorcerer | 66.9% | 69.6% | +2.7 ±4.1 |
  | Wizard | 65.8% | 68.3% | +2.6 ±2.9 |

  The delta is MONOTONE up the ladder and it is NEGATIVE at the bottom of
  it: a seat that fumbles a third of its actions gains nothing from
  reading a printed line, because the attack it declines to make this
  turn is one the mistake roll would have dropped anyway, and the
  attacker it keeps home it then fails to use. So the numbers and the
  owner's ramp ruling (§1, 2026-09-07) agree for once, and the knob is
  Sorcerer and Wizard on both grounds rather than on the ruling alone.
- **AND THE RAMPAGE HALF CANNOT BE MEASURED HERE AT ALL.** All seven
  rampage cards in the pool are Legends (Craw Giant, Frost Giant,
  Wolverine Pack, Marhault Elsdragon, Aerathi Berserker, Hunding
  Gjornersen, Chromium) and **no deck in `decks/` holds one of them**, so
  the Deck Lab has no board to put the question on. It is pinned by
  `tests/ai/test_ai_reads_gaze_2026_09_10.gd` alone — the gang declared
  on `2+2 >= 4` that meets an 8/6 and loses both bodies and four trample,
  the crack-back model's own `resolve_block` reading `[true, 3, 2]` where
  the truth is `[false, 3, 4]`, and the gang of ONE still equal to
  `_dies_to` on both arms — and that is said plainly rather than dressed
  up as a wash.

THE LAND THAT IS A BLOCKER (2026-09-10, `reads_manlands`) is the larger
of the two and the flips say so where the win rate is only just outside
the interval. Seed 11, 2 000 games an arm, control Big Green vs White
Knights, byte-identical to its own null in every arm.

| pair | what fires | null | `on` | delta | games that turned |
| --- | --- | --- | --- | --- | --- |
| The Deck (playable) vs Big Green | the BLOCK half alone — Big Green owns no manland | 42.0% | 44.5% | +2.5 ±3.1 | 62 of 2 000 — 56 won, 6 lost |
| Big Green vs The Deck (playable) | the ATTACK half alone — Big Green owns no manland of its own, and seat B has the knob off, so nothing ever animates to block | 58.2% | 58.1% | −0.1 ±3.1 | 3 of 2 000 — **0 won, 3 lost** |
| The Deck (playable) vs Mountain Artillery | the BLOCK half again, against a deck whose clock is burn rather than bodies | 39.4% | 40.4% | +1.1 ±3.0 | 35 of 2 000 — 28 won, 7 lost |

- **THE BLOCK HALF IS WHERE THE GAIN IS.** Big Green owns no manland at
  all, so on that pair the only reading that can fire is our own Factory
  animated to block, and 423 of 2 000 games play differently for it. Of
  the 62 that end differently, **56 are won and 6 lost** — a split that
  is six standard deviations from a coin. The Deck's whole problem is
  surviving to turn fifty, and three Factories that block are three more
  bodies it never had. Against Mountain Artillery — a clock made of burn
  rather than of bodies, so there is less to block — the same half reads
  +1.1 ±3.0 with a 28-to-7 split of the 35 games that turned: the same
  sign, smaller, on the deck that puts the question less often.
- **THE TWO HALVES SHIP TOGETHER BECAUSE EITHER ALONE IS A LIE, AND THE
  LAB SAYS SO RATHER THAN THE ARGUMENT.** The second row is the ATTACK
  half on its own: Big Green owns no manland, The Deck owns three, and
  seat B is at the null — so the pilot prices its attacks against a body
  the seat opposite will never actually make. It reads **−0.1 ±3.1**,
  215 of 2 000 games play differently, and of the **3 that end
  differently NOT ONE is won**. Three games of two thousand is nothing to
  a win rate and it is exactly the shape the design predicted: a pilot
  made timid about a blocker that does not arrive. Ship the BLOCK half by
  itself and the mirror fault appears — the pilot makes a body the reader
  opposite cannot see. One knob, one fact about the same permanent, read
  from both sides of the table.
- **AND THE PLAN'S SECOND PAIR CANNOT BE PLAYED.**
  `decks/community/sligh_geeba_1996.deck` — four Mishra's Factory, which
  is why the plan named it — holds NINE proxies (An-Zerrin Ruins, Dwarven
  Lieutenant, Dwarven Ruins, Dwarven Trader, Incinerate, Orcish
  Cannoneers, Orcish Librarian, Serrated Arrows, Zuran Orb) and the Deck
  Lab refuses it with exit 2. That is a pool fact and not a measurement
  failure; the substitutes below are named for what they put the question
  on rather than for the list they replace.

THE SHELTER CAST AND THE TWIN (2026-09-10) is the SIXTH reading under
`trusts_abyss` and the first one that turns the knob's own sign on a
pair. It is an extension and not a knob, so the knob's meaning grew and
its null did not move at all. Seed 11, 1 000 games an arm, control Big
Green vs White Knights, and the pair run TWICE — once on the tree the
third pass shipped and once on this one — so the `on` arms lie side by
side and every game can be compared by its own fingerprint.

| pair | null | `on`, before | `on`, after | the knob's own delta |
| --- | --- | --- | --- | --- |
| The Deck (playable) vs Blue Skies | 47.5% | 45.6% | **48.4%** | −1.9 ±4.4 → **+0.9 ±4.4** |

- **THE PAIR IS THE ONE THE THIRD PASS FLAGGED.** Blue Skies is where
  `trusts_abyss` measured −0.3 when the knob shipped, and it is the deck
  the open row named: four Merfolk of the Pearl Trident are four one-drop
  fliers that arrive AFTER the body The Deck declined to counter and take
  the Abyss's meal away from it. On this pair, at this size, the shipped
  knob is **−1.9 against its own null** — it was losing games — and with
  the two readings in it is **+0.9**. Both numbers are inside a
  ±4.4-point interval, so neither is visible on its own; what is visible
  is the 2.8 points between them and the census under it.
- **THE NULL IS EXACTLY THE NULL, across two trees.** Every `off` arm,
  every `null` arm and every arm of the CONTROL pair is byte-identical
  between the shipped tree and this one, game for game: **5 000 games
  compared one by one, not one different**, with the control 525-475 in
  every arm of both runs.
- **182 OF 1 000 `ON`-ARM GAMES PLAY DIFFERENTLY AND 36 END DIFFERENTLY —
  32 WON AND 4 LOST.** A 32-to-4 split is nearly five standard deviations
  from a coin. The two readings are rare (a feeder on the table, and either a
  twin or a cheaper body arriving after the one we let through) and when
  they fire they decide the game.
- **WHAT IT FIXES IS WHAT THE TABLE SEES**, this file's own precedent
  many times over: a Counterspell kept because The Abyss will eat their
  Serra Angel, a Mesa Pegasus resolving unopposed, and the Angel still
  standing at their upkeep with the counter spent on nothing.
THE OPENING HAND'S MANA (2026-09-10, `AiMulligan`, a correction and not a
knob) is a WASH ON THE SCOREBOARD and the end of a malfunction anyone
watching a Power deck open would have seen. Casting note P12 asked for
Forge's low-land-DECK escape; what this pool actually had was a census
that counted LANDS at both ends of the keep band where its floor meant
MANA. Five Moxen, a Black Lotus and a Mana Crypt therefore counted for
nothing: a seven of one Island and two Moxen — four mana on turn one —
went back as "1 land in 7", and an Island beside a Mox Ruby could not
cast the Lightning Bolt the Mox pays for. The floor now reads
`AiMulligan.mana_sources` (the lands plus every card costing {0} that
prints a mana ability, named by shape and never by name) and the ceiling
still reads the lands, because "nothing but land" asks what the hand can
CAST and a Mox is a spell. It is ONE-DIRECTIONAL: it can only turn a
mulligan into a keep.

THE RATES FIRST, because they are the finding — 4 000 opening sevens a
deck, each hand run down the whole Paris chain to a keep:

| deck | lands | free sources | sevens thrown back, before → after | mean hand kept |
| --- | --- | --- | --- | --- |
| The Deck (playable variant) | 22 | 6 | 20.2% → **8.3%** | 6.72 → 6.90 |
| The Deck (Weissman, February 1996) | 21 | 6 | 22.6% → **9.8%** | 6.70 → 6.89 |
| The Deck (Weissman, Winter 1994–95) | 17 | 6 | 36.2% → **16.6%** | 6.45 → 6.78 |
| Twist of Fire (Merritt 1993) | 0 | 21 | 100.0% → **3.1%** | 4.00 → 6.97 |
| Dracur (1997 enemy deck) | 20 | 4 | 33.6% → **22.2%** | 6.49 → 6.70 |
| Prismat (1997 enemy deck) | 19 | 4 | 30.5% → **17.9%** | 6.55 → 6.77 |
| Kiska-Ra (1997 enemy deck) | 21 | 3 | 29.6% → **21.1%** | 6.56 → 6.71 |
| Big Green | 15 | 0 | 16.6% → 16.6% | 6.78 → 6.78 |
| White Knights | 17 | 0 | 11.6% → 11.6% | 6.85 → 6.85 |
| Blue Skies | 18 | 0 | 9.8% → 9.8% | 6.88 → 6.88 |
| Mountain Artillery | 16 | 0 | 13.7% → 13.7% | 6.82 → 6.82 |
| Black-Red Raiders | 17 | 0 | 14.3% → 14.3% | 6.82 → 6.82 |

- THE WINTER LIST HAS EXACTLY WHITE KNIGHTS' SEVENTEEN LANDS and was
  throwing back three times as many sevens — 36.2% against 11.6% —
  because six of its sixty cards were mana the judgement could not see.
  That is the malfunction in one row of a table.
- THE LANDLESS LIST MULLIGANED TO THE FLOOR IN EVERY GAME IT EVER
  PLAYED. `twist_of_fire_merritt_1993` is forty cards of eighteen
  Timetwisters, twenty-one Black Lotuses and a Fireball; the pilot threw
  back its seven, its six and its five every single time and started
  every duel of its life on four cards.
- IT IS NOT A CURIOSITY OF THE COMMUNITY LISTS: **69 of the 217 decks
  this pool can load hold one of the seven cards, and nineteen of those
  are 1997 enemy decks** — Dracur, Prismat, Kiska-Ra, Arzakon, Azaar -
  Lichlord, Mind Stealer and thirteen more, the decks a player actually
  meets in the adventure. Each of them was throwing back around a third
  of its sevens.
- THE SHIPPED FIVE DO NOT MOVE AT ALL, which is the null said in one
  line: none of them owns one of the seven cards, so for them the census
  IS the land count and every rate is the same number to the tenth on
  both trees. Nor does a deck that merely shares a name with one that
  does — the `originals` Shapeshifter has no Mox and sits at 16.9% on
  both trees, while the `duels` list of the same name has five.

THE LAB, seed 11, `--mulligan on --sweep mulligans=on,off`, 2 000 games
an arm, every pair played TWICE — once on the tree before this landed and
once on this one — so the `on` arms lie side by side and every game can
be compared by its own fingerprint:

| pair | null (`off`) | `on`, before | `on`, after | delta | games that played differently | flips won–lost |
| --- | --- | --- | --- | --- | --- | --- |
| The Deck (playable) vs White Knights | 28.7% | 28.2% | 28.8% | +0.6 ±3.1 | 268 of 2 000 | 52–40 |
| The Deck (1996-02) vs White Knights | 22.5% | 22.1% | 22.9% | +0.8 ±2.6 | 288 of 2 000 | 41–26 |
| The Deck (Winter 94–95) vs White Knights | 42.5% | 44.2% | 42.8% | −1.4 ±3.1 | 436 of 2 000 | 69–98 |
| Twist of Fire vs Big Green | 51.5% | 51.5% | 53.5% | +2.0 ±3.1 | 2 000 of 2 000 | 507–466 |

- IT IS A WASH AND THE FLIPS SAY SO TOO: 1 299 games of the 8 000 ended
  differently, **669 won and 630 lost**, which at that count is a coin
  (+39 games, +0.49 of a point). Three pairs lean up and one leans down,
  and the one that leans down is the list with the fewest lands of the
  three Decks — which is the ANGEL section's own open question
  (`docs/AI-next-wave.md`: whether a control deck's keep should want
  three lands) asked from the other side, and it is not answered here.
- THE NULL IS EXACTLY THE NULL, proved game for game across two trees.
  Every `off` arm, every `null` arm and EVERY ARM OF THE CONTROL PAIR is
  byte-identical between the shipped tree and this one on all four pairs:
  **24 000 games compared one by one, not one different**. Big Green vs
  White Knights owns no Mox, no Lotus and no Crypt, so the correction is
  silent there even with `mulligans=on` — the control's `on` arm replays
  1076-924 on both trees.
  (Within a single run the `mulligans` sweep's own control FAILS by
  construction and the run exits 4: that knob changes the opening hand of
  every deck, so no pair of decks exists that it cannot fire on. The
  comparison that means something for this correction is the one BETWEEN
  the trees, and it is the one above.)
- P12'S OWN ESCAPE WAS MEASURED AND NOT KEPT. Forge keeps a one-lander
  when the library holds fewer than one land in seven
  (`library.size() / landsInDeck > 6`). Over every deck this pool can
  load — 217 of them — that test fires on ONE, the landless Twist of
  Fire; the next sparsest list is 3.93 cards per land, nowhere near the
  threshold, and `wc1994_lestree`, the deck the plan named to measure it
  on, is at 3.05 and does not even load (Chaos Orb). The one deck it
  would have served is fixed by the census with no ratio in it. A cut
  that measures nothing is written down and not kept.

THE HAND'S WEIGHT (2026-09-10, `w_hand`, a number exposed for a sweep and
NOT a knob) is a NO CHANGE with the evidence attached, which is the whole
point of the exercise. Casting note P11 observed that Forge prices a card
in hand at 2.5 times a point of life where `Evaluator.W_HAND` prices it
at 1.5, and asked for the difference to be settled by measurement.
`Evaluator.position_score` now takes an optional profile and reads
`AiProfile.w_hand` from it (the "thread an AiProfile through rather than
editing constants" its own header has asked for since it was written), so
`--sweep w_hand=1.5,2.0,2.5` is a command. Seed 11, 2 000 games an arm,
control Big Green vs Mountain Artillery:

| pair | 1.5 (the null) | 1.5 | 2.0 | 2.5 |
| --- | --- | --- | --- | --- |
| The Deck mirror (playable vs 1996-02) | 51.8% | 51.8% | 51.6% (−0.2 ±3.1) | 51.6% (−0.2 ±3.1) |
| The Deck (playable) vs Mountain Artillery | 39.2% | 39.2% | 39.4% (+0.1 ±3.0) | 39.1% (−0.1 ±3.0) |
| Big Green vs White Knights | 53.8% | 53.8% | 53.8% (+0.0 ±3.1) | 53.8% (+0.1 ±3.1) |

- THE THREE ARMS ARE INDISTINGUISHABLE and the incumbent stays. No delta
  reaches a third of its own interval, and the flips are a coin at both
  candidate values: 40 won to 42 lost across the three pairs at 2.0, and
  70 to 76 at 2.5.
- THE 1.5 ARM IS BYTE-IDENTICAL TO THE NULL on every pair and on the
  control — 0 of 2 000 games different, four times over — which is P11's
  own determinism check and the proof that the plumbing is inert at the
  shipped value.
- WHY IT MOVES SO LITTLE IS THE FINDING, and it was not knowable before
  the sweep: `W_HAND` has exactly two readers. `position_score` is
  consulted at ONE place in the pilot — `_combat_tolerance`'s posture
  flag, a `> 5.0` threshold that a hand-size lead rarely decides on its
  own — and `AiPlayer._level_value` prices a Balance. So the control pair
  P11 said could not exist (every game is scored) turns out to be very
  nearly a control after all: raising the weight by a full point changes
  **6 games of 2 000** on Big Green vs Mountain Artillery, and by two
  thirds of a point **12**. On Big Green vs White Knights, 9 and 12. The
  number is not a lever on this evaluator; the two decks that hold real
  card advantage move 165 and 298 games of 2 000 and still land inside
  the interval.
- SO NOTHING CHANGES EXCEPT THAT THE QUESTION IS NOW ASKABLE. `w_hand`
  ships at 1.5 on every preset, no rung moves it, and the next person who
  wants Forge's 2.5 can have the same three arms in one command instead
  of an argument.
THE TUTOR'S PICK (2026-09-10, `tutors_for_the_turn`) is a WASH on either
pair's own interval and a GAIN once the games that turned are counted,
and the census under it is where the change is really visible. Seed 11,
control Big Green vs White Knights, byte-identical to its own null in
every arm of all six runs (525-475 at 1 000, 2150-1850 at 4 000).

| pair | null (4 000) | `on` (4 000) | delta (1 000) | delta (4 000) | games that turned (4 000) |
| --- | --- | --- | --- | --- | --- |
| The Deck vs White Knights | 28.1% | 29.4% | +0.7 ±4.0 | +1.3 ±2.0 | 482 played, 151 ended — **102 won, 49 lost** |
| The Deck vs Black-Red Raiders | 41.8% | 42.4% | +0.6 ±4.3 | +0.6 ±2.2 | 518 played, 125 ended — **74 won, 51 lost** |
| Alt-A-Kesh vs White Knights | 23.0% (1 000) | 23.0% | +0.0 ±3.7 | — | **4 played, 0 ended of 1 000** |

(The 1 000-game runs have their own nulls — 29.1%, 41.3%, 23.0% — and the
1 000-game delta column is read against those.)

- **NEITHER DELTA IS CLEAR OF ZERO AND THE PAIR OF THEM IS.** Over the
  two 4 000-game pairs 276 games ended differently and they split **176
  to 100**; on the discordant pairs that is 4.6 standard errors from a
  coin, which is decided, and it is the same +0.95 points the two win
  rates average to. Said plainly: the search resolves in about a third of
  the games and the ANSWER differs in about one in eight, which is not
  enough to move a single pair's win rate past its own interval — and the
  flips say which way it moves.
- **THE NULL IS EXACTLY THE NULL, proved by replaying a published sweep
  game for game.** The `pays_sacrifices` sweep of the Deck Lab manual
  (Dracur — Spells of the Ancients vs Big Green, 1 000 games an arm, seed
  11) was run on the shipped tree and on this one with
  `tutors_for_the_turn=off` forced on both seats: 24.9% / 27.2% / 24.9%
  either way, control 525-475, and **all 6 000 games identical by their
  own log fingerprint** — the same winner, the same turn count, the same
  hash. (The ROADMAP prints 27.3% for that arm; the shipped tree gives
  27.2% here too, so the third decimal is the ledger's and not a moved
  null.)
- **THE CENSUS IS THE ARGUMENT.** Over 150 logged games of The Deck
  against White Knights the pilot resolved 53 searches and the answer was
  one of **exactly three cards** out of the sixty in the deck —
  Jayemdae Tome ×25, The Abyss ×22, Nevinyrral's Disk ×6 — because those
  are the three that price at 5.0 and nothing else in the deck does. With
  the knob it names six: Jayemdae Tome ×17, The Abyss ×15, **Balance ×11**,
  Disrupting Scepter ×4, Nevinyrral's Disk ×5 and **City of Brass ×2**. A
  Balance had never been fetched once, and a LAND had never been fetched
  in the pilot's life. Against Black-Red Raiders the same shape: six
  cards and 77 fetches become eight and 78, with Balance ×14 and a Swords
  to Plowshares where there had been none.
- **AND WHERE THE POOL DOES NOT PUT THE QUESTION IT MEASURES NOTHING,
  which is worth writing down rather than hiding.** Alt-A-Kesh — two
  Untamed Wilds over seven Forests, seven Swamps and seven Islands, the
  best deck in the pool for the colour prong — moves **4 games of 1 000**
  and flips none. Thirteen of the sixteen Untamed Wilds decks are
  mono-green, where "which basic" has one answer.
- **TWO POOL FACTS ON THE PAIRS THE PLAN NAMED.** `sligh_geeba_1996`
  cannot be played: 9 proxies (An-Zerrin Ruins, Dwarven Lieutenant,
  Dwarven Ruins, Dwarven Trader, Incinerate, Orcish Cannoneers, Orcish
  Librarian, Serrated Arrows, Zuran Orb) — Black-Red Raiders stands in
  for it above. And `necropotence_1996` cannot be played either: 6
  proxies (Hymn to Tourach, Icequake, Ihsan's Shade, Necropotence, Order
  of the Ebon Hand, Zuran Orb) — and it holds no tutor of any kind, so
  even loaded it could not have exercised the knob from seat A.

THE LAND SWEEP (2026-09-10, `levels_boards`' second reading) is a WASH
that removes a malfunction, and it took THREE CUTS to get there — the
first two are written down because each was measured and each was wrong
in a way the next one names. Seed 11, control Big Green vs Mountain
Artillery, and every pair run twice: once on the tree before this landed
and once on this one, so the `on` arms lie side by side game for game.

| cut | what it compared | AoL vs Big Green | AoL vs White Knights | games that turned |
| --- | --- | --- | --- | --- |
| 1 | our creatures' VALUE against theirs, as a veto | −1.3 (1 000) | +0.6 (1 000) | 35 ended — 14 won, 21 lost |
| 2 | our CLOCK against theirs, as a veto | −0.4 ±2.0 | +0.2 ±2.1 | 58 ended — 26 won, 32 lost |
| 3 | the clock DEFICIT as a price — **shipped** | −0.1 ±2.0 | +0.0 ±2.1 | 26 ended — 11 won, 15 lost |

(The deltas are this pass's own half: the `on` arm here against the `on`
arm of the tree before it, at 4 000 games for cuts 2 and 3. The WHOLE
knob on those pairs is +2.5 ±2.0 and +2.5 ±2.1, and that is the
leveller's number from 2026-09-07, not this reading's.)

- **CUT 1 WAS FORGE'S OWN COMPARISON AND IT LOST.** `evaluateCreatureList`
  becomes `Evaluator.permanent_value` here, which is power plus
  toughness — so an Ironroot Treefolk (8) outweighs two Savannah Lions
  (3 and 3) and a white weenie deck reads as BEHIND against the wall it
  is walking past. Against Big Green 15 of the 17 games that turned were
  lost. The lesson is the currency and not the rule: what decides a game
  with no mana in it is not what the boards are worth but what they get
  through.
- **CUT 2 FIXED THE CURRENCY AND KEPT THE VETO, and the veto was the
  other half of the mistake.** `_drought_clock` is
  `_damage_through_blocks` — the reading `times_sweeps`' relief already
  asks their next attack with — and refusing whenever theirs got anything
  through still cost 18 of the 21 games that turned against Big Green.
  The reason is named in §5: against a green deck the case for an
  Armageddon is the four fatties in THEIR HAND that will never be paid
  for, and nothing in this engine can see a hand's future.
- **CUT 3 CHARGES THE DEFICIT INSTEAD OF VETOING ON IT**, at
  `_life_price`'s rate and for one turn of it, which is the same currency
  and the same conservatism `_sweep_relief` prices a saved point of life
  in. Two Grizzly Bears' worth of clock is one point off the swing; a
  Serra Angel's is four, and four is what a three-land swing cannot
  carry. Of 8 000 `on`-arm games **285 played differently and 26 ended
  differently — 11 won and 15 lost**, which at that count is a coin, and
  both win rates land inside a fifth of their own interval.
- **THE NULL IS EXACTLY THE NULL, across two trees.** Every `off` arm,
  every `null` arm and EVERY ARM OF THE CONTROL PAIR is byte-identical
  between the shipped tree and this one, game for game — on both pairs at
  4 000, 40 000 games of `off` and control compared one by one, not one
  different, and the same at 1 000 for the two cuts above it. The control
  is 549-451 at 1 000 and 2177-1823 at 4 000, byte-identical to its own
  null in every arm of all fifteen runs — eight at 1 000, seven at 4 000.
- **WHAT IT FIXES IS WHAT THE TABLE SEES**, which is this file's own
  precedent several times over. Probed on two boards. Four Plains against
  seven and two Serra Angels across the table with nothing on ours: the
  shipped pilot prices the Armageddon at 6.00 and casts it, handing the
  opponent a board that kills it in three swings with no mana on either
  side; it now prices it at 2.00 and holds. And three Underground Seas, a
  Tundra, a Library of Alexandria and a City of Brass of ours against
  seven Plains: the shipped pilot sees five lands against seven, prices
  it at 4.00 and blows up the better manabase in the game; it now sees
  what each land is worth to the seat that has it, prices it at −9.00 and
  holds. Neither is a close decision made badly.
- **THE CENSUS SAYS IT DECLINES FEW AND THE RIGHT FEW.** Over 150 logged
  games Armies of Light casts Armageddon 15 times against Big Green with
  the reading off and 14 with it on, and 37 times against White Knights
  and 31 — one in fifteen declined on the first pair and one in six on
  the second, and the ones declined are the ones with a board across the
  table. Cut 2's veto declined 8 of the 15 and 9 of the 37, which is what
  a rule with no price in it looks like.

THE MANA ON THE OTHER SIDE OF THE TABLE (2026-09-10, `reads_pumps`) is a
WASH on the win rate and the removal of a malfunction the owner named by
name, and the interesting part of it is a CUT rather than the ship: the
first form of the reading measured **−3.2 ±2.8 against Mountain
Artillery**, which is outside the negative interval and is the "no harm"
rule's own refusal. Seed 11, 2 000 games an arm unless the row says
otherwise, control Big Green vs White Knights, byte-identical to its own
null in every arm of every run below.

| pair | null | `on` | delta | games that turned |
| --- | --- | --- | --- | --- |
| Big Green vs Vampire Lord (4 Carrion Ants, 4 Vampire Bats, 22 Swamps) | 76.6% | 77.2% | +0.6 ±2.6 | 58 of 2 000 — 35 won, 23 lost |
| Big Green vs Great Hydra (4 Granite Gargoyle, 4 Wall of Fire, 4 Lightning Bolt, 4 Mana Flare) | 76.3% | 76.0% | −0.3 ±2.6 | 76 of 2 000 — 35 won, 41 lost |
| Mountain Artillery vs Vampire Lord — the canary | 73.0% | 72.1% | −1.0 ±2.8 | 77 of 2 000 — 29 won, 48 lost |

- **THE REPRODUCTION IS THE OWNER'S OWN SENTENCE AND IT REPRODUCED
  EXACTLY.** *"The pilot pumps its own creatures and reads a Cockatrice, a
  Factory and an Assassin — but it will still attack a 0/1 Frozen Shade
  with four Swamps up."* On that board the shipped Wizard read
  `_attack_risk 0.00` — "we kill it and live" — declared the swing, and
  the Grizzly Bears was in the graveyard with the Shade still standing and
  their life still twenty. `AiPlayer._shieldable` has counted their open
  mana against their cheapest REGENERATION shield since the block audit,
  so a Drudge Skeletons with {B} up is a wall to every kill this pilot
  predicts; the other printed line their mana buys was read by nobody.
- **THE READ IS THE MIRROR OF `pumps_to_attack` AND THAT IS THE WHOLE
  CASE FOR IT.** Two days of passes taught the pilot to size its own
  attack, block and survival by the mana it holds — five passes of them —
  and not one of them ever asked the same question of the seat opposite.
  A knob that does to you what it cannot see coming is the asymmetry this
  closes.
- **THE THREE CAPS ARE WHAT MAKE IT A READING AND NOT A FANTASY**, and
  each is a real card. The printed *activate only N times each turn* (a
  Fire Drake behind five Mountains is +1/+0 and a Vampire Bats behind six
  Swamps +2/+0, not +5/+0 and +6/+0). ONE POOL, shared among the bodies of
  theirs this combat can ask it of — three Carrion Ants behind six Swamps
  are three 2/3s and not three 6/7s, which is `pumps_to_attack`'s own
  fifth-pass sentence read from the other side of the table. And the
  smallest activation count past which no kill-or-survive answer on the
  board could still change: a Shade behind ten Swamps facing one Grizzly
  Bears is +2/+2, because +3/+3 and +10/+10 answer every question there
  identically and a reading that prints 10 invites a later caller to
  believe it. Forge counts exactly ONE activation
  (`predictPowerBonusOfBlocker`), which under-reads that Shade by three
  points; counting all of them is the honest read of public mana.
- **THE CUT THAT SAVED IT, AND THE NUMBER THAT FORCED THE CUT.** Fed
  through `_dies_to` in BOTH directions the reading measured **−3.2 ±2.8
  on Mountain Artillery vs Vampire Lord** with 44 of the 151 games that
  turned won and 107 lost. Split by phase, the ATTACK half measured −0.2
  and the BLOCK half **−2.4**: read on defence, their pump stopped the
  block ladder's first rung from claiming a kill AND told it our blocker
  would die, no later rung catches a printed 0/1 (rung 1.7 wants
  `cur_power >= 2`), and three Carrion Ants behind six Swamps walked past
  three Hill Giants for six damage a turn — the "wall" the Forge note's
  own risk paragraph predicts, arriving on defence instead of offence.
  So the POWER half — their pump killing a body of OURS — is asked only
  where we are choosing to SEND a body into it (`_attack_risk` and
  `_cohort_value`, the two halves of the attack declaration) and not where
  we are choosing to put one in FRONT of it. The TOUGHNESS half — their
  body surviving ours — is read everywhere, at `_dies_to`'s own seam.
- **AND THE ASYMMETRY IS A FACT ABOUT THE GAME, NOT A TUNING.** A blocker
  of ours that dies to their breath has SPENT their mana, and mana spent
  killing a blocker is mana that did not reach our face — this engine
  breathes fire at the PLAYER with an unblocked attacker, on both sides of
  the table (`AiPlayer._offensive_combat_response`), which the
  reproduction shows in one line: decline the block and the 0/1 Shade
  hits for four. An attacker of ours that dies to it has bought nothing
  at all. The Lab is what found it; the sentence is what keeps it.
- **THE OTHER CUT WAS SMALLER AND IT STAYED.** Reading their pool whole
  for every body of theirs took Mountain Artillery from −3.2 to −2.7 when
  the pool was split among them, and the split is kept for the reading it
  is rather than for that: with the phase asymmetry in as well the two
  forms are −1.0 either way and the flips lean to the split (Big Green vs
  Vampire Lord 35-23 with it, 36-30 without).
- **NO HARM ACROSS THE WHOLE FIVE-DECK GAUNTLET**, 1 000 games an arm,
  every one of the twenty starter matchups with each deck in turn on seat
  A. **Fourteen of the twenty are byte-identical to their own null — 0
  games different** — because the knob has nothing to read there. The six
  that fire: Black-Red Raiders vs Mountain Artillery +0.7 (124 games
  played differently, 17 ended, 12 won to 5), White Knights vs Mountain
  Artillery +0.1 (203, 27, 14 to 13), White Knights vs Black-Red Raiders
  +0.2 (4, 2, 2 to 0), Blue Skies vs Mountain Artillery +0.0 (62, 10, 5
  to 5), Blue Skies vs Black-Red Raiders −0.1 (15, 1, 0 to 1) and Big
  Green vs Mountain Artillery −0.4 (158, 16, 6 to 10). Nothing is near
  the ±4.4 interval that size carries, and the deck the two earlier
  rejected approximations broke — Mountain Artillery, at −2.3 then — is
  the seat READING here in four of them and reads +0.0 in all four.
- **MEASURED AT EVERY RUNG, and the numbers argue nothing.** Big Green vs
  Vampire Lord, 1 000 games an arm, both seats at the same preset, control
  PASS and byte-identical in every arm of all four runs:

  | pilot | null | `on` | the knob's own delta |
  | --- | --- | --- | --- |
  | Apprentice | 77.1% | 77.2% | +0.1 ±3.7 |
  | Magician | 83.3% | 82.7% | −0.6 ±3.3 |
  | Sorcerer | 78.0% | 78.2% | +0.2 ±3.6 |
  | Wizard | 75.5% | 75.6% | +0.1 ±3.8 |

  Not monotone, not clear of zero anywhere, and the largest of the four is
  a sixth of its own interval. So unlike `reads_gaze`, whose −1.2 at the
  Apprentice argued its own rung, this one is placed by the ramp ruling
  (§1, 2026-09-07) and by the company it keeps: it is the mirror of
  `pumps_to_attack` and belongs to the layer `reads_gaze`,
  `reads_manlands` and `animates_to_attack` belong to. SORCERER AND
  WIZARD, said plainly as a ruling rather than dressed up as a
  measurement.
- **THE NULL IS EXACTLY THE NULL, proved by replay and not by argument.**
  The `pays_sacrifices` sweep of the Deck Lab manual — Dracur (Spells of
  the Ancients) vs Big Green, 1 000 games an arm, seed 11 — was run on
  HEAD's own files and on this tree with
  `reads_gaze=off,reads_manlands=off,reads_pumps=off` forced on both
  seats, and all **6 000 games are identical game for game**, the two
  `games.csv` files byte for byte. (Both read 22.6% null and 25.4% `on`
  against the 24.9% / 27.2% §4 prints for that pair, which is a number
  gone stale under the day's OTHER knobs and not a moved null — the same
  thing recorded twice above.) Every sweep in this section carries its own
  control verdict, and Big Green vs White Knights is byte-identical to its
  own null in every arm of all of them (1075-925 at 2 000, 525-475 at
  1 000).
- **THE POOL FACT, AND IT IS THE REASON THE GAUNTLET IS ALL ZEROES.**
  Seventeen cards in this pool carry an activated self-pump with no tap
  cost (Arcades Sabboth, Atog, Carrion Ants, Dragon Engine, Fallen Angel,
  Fire Drake, Frozen Shade, Granite Gargoyle, Killer Bees, Osai Vultures,
  Pavel Maliki, Shivan Dragon, Vaevictis Asmadi, Vampire Bats, Wall of
  Fire, Wall of Opposition, Wall of Water) and three of them — Atog,
  Fallen Angel, Osai Vultures — pay in a BOARD rather than in mana and are
  refused. Of the five shipped starters only Mountain Artillery (3 Granite
  Gargoyle, 1 Shivan Dragon) and Black-Red Raiders (1 Shivan Dragon) hold
  one at all, so the knob can fire in six of the twenty starter matchups
  and nowhere else. It is the 1997 enemy decks that put the question:
  Vampire Lord, Ape Lord, Great Hydra and Kzzy'n the Dragon Lord field
  eight each. **And the plan's own Lab line is stale:**
  `decks/community/necropotence_1996.deck`, which
  `docs/forge/combat.md` P2 names as the likely pair, holds SIX proxies
  and the Deck Lab refuses it with exit 2.
- **SO THE READING OF IT IS A WASH THAT REMOVES A VISIBLE MALFUNCTION,
  which is the reason `holds_x_burn` and the Detonate half shipped.** Two
  of the three pairs are inside a ±2.6-point interval with opposite signs
  and the canary is inside a ±2.8 one; across the three, 99 of the 211
  games that ended differently were won and 112 lost, which at that count
  is a coin. What is NOT a coin is the table: a Grizzly Bears sent into a
  0/1 with four black sources open, dying for nothing while the pilot
  reads the swing as free, is not a close decision made badly. It is the
  one thing this pilot could do to a human that a human could not do back
  to it.

Every change to a profile is measured before it ships — `DeckLab/deck_lab.sh
--sweep KNOB=on,off` against a control pair, the same seed — and
`docs/ROADMAP.md` keeps the runs. The control pair is chosen by what
FIRES the knob, not by what the last knob used: a pace knob's control
holds no draw spell, tutor or Time Walk (Big Green vs White Knights),
a sweeper's no Hurricane, Earthquake or Wrath (Blue Skies vs Black-Red
Raiders), `pumps_to_attack`'s no activated self-pump AND — since the
fourth pass — no targeted burn on either side, `spends_counters`'s no
permanent whose ability costs a counter, `plays_engines`' no Factory, no
Scepter and — since the token arm — no permanent whose activated ability
makes a token (Big Green vs White Knights holds none of the three) — the
third pass's Time Walk

fourth pass — no targeted burn on either side AND — since the fifth — no
regenerator beside a firebreather, `spends_counters`'s no
permanent whose ability costs a counter — the third pass's Time Walk

permanent whose ability costs a counter, `prices_liabilities`'s no Lich,
no Mana Vault, no permanent that stops untapping and — since the fifth
pass — no Paralyze and no Detonate,
`reads_gaze`'s no trigger that destroys what it blocks (Cockatrice,
Thicket Basilisk), no printed rampage and no ability that destroys a
TAPPED creature (Royal Assassin, Tetsuo Umezawa), and
`reads_manlands`' no permanent that can animate ITSELF on EITHER side of
the table (Mishra's Factory, Jade Statue), and `reads_pumps`' no
activated self-pump on the side OPPOSITE the seat being swept — which in
practice is the same list `pumps_to_attack` already keeps, seventeen
cards, and Big Green vs White Knights holds none of them — the third
pass's Time Walk
sweep FAILED its first control on exactly that (Blue Skies' Ancestral
Recall), and a failed control makes the deltas beside it no measurement
at all. `CONTRIBUTING.md`
has the rule.

AND A KNOB THAT DEFAULTS ON AT SORCERER IS A KNOB THE NEXT SWEEP HAS TO
PIN. `reads_gaze`, `reads_manlands` and `reads_pumps` are on at Sorcerer
and Wizard, so a measurement of some OTHER knob taken against a number
published before 2026-09-10 must force all three off on both seats
(`--profile-a wizard:reads_gaze=off,reads_manlands=off,reads_pumps=off`,
and the same for `--profile-b`) or it is measuring several changes at
once. That is how both of those passes proved their own null, and it is
the general rule every knob since `plays_engines` has quietly needed.
TWO MORE SINCE 2026-09-10. `levels_boards` grew the LAND SWEEP, so its
control must hold no Balance AND no all-lands sweeper — Big Green vs
Mountain Artillery holds none of them in the main deck (Mountain
Artillery's three Flashfires are in the SIDEBOARD, which a free-play
sweep never swaps in), and it is 549-451 byte-identical to its own null
in every arm of eight runs at 1 000 games and 2177-1823 in all seven at
4 000. `tutors_for_the_turn` fires
wherever a card ask offers cards out of OUR OWN LIBRARY, so its control
must hold no Demonic Tutor, no Untamed Wilds, no Land Tax, no Transmute
Artifact and no Aladdin's Lamp — Big Green vs White Knights holds none
of the five, and is 525-475 byte-identical to its own null in every arm
of four runs at 1 000 games and two at 4 000. A Regrowth is NOT one of
the five: the graveyard's gain asks go through `_choose_targets`, which
has had its own land rule since the second pass, and Big Green's one
Regrowth is untouched by the knob.

## 5. Where the ladder still ends short

- `counter_threshold` is an absolute evaluator number, so a Wizard on a
  deck with pain lands spends life on counters a Sorcerer keeps; that is
  the open knob question above, to be instrumented before it is touched.
- `ranks_counters` orders the counters in hand by what they COST and
  whether they work, and never by what the spell on the stack would do:
  a Counterspell and a Mana Drain price the same, so which of the two
  answers a Serra Angel is still the hand's own order. Countering by the
  SHAPE of the spell — Weissman's rule, the counter kept when a card in
  hand answers the spell later — is wave 2's `counters_by_shape`
  (`docs/AI-next-wave.md`). And the ranking cures only the mana half of
  an older quirk: [method AiPlayer._try_counter] RETURNS whatever
  [method AiPlayer._cast_response] gives it, so a counter the engine
  refuses for a reason the mana plan cannot see still ends the search
  with a pass.
- `reads_pumps` counts their open SOURCES and not their COLOURS, which is
  the convention `_shieldable`, `_animatable_bodies` and
  `_taps_into_execution` all keep — a permanent with any mana ability is
  one mana — so a Frozen Shade behind three Forests and one Swamp is read
  at +4/+4 where the truth is +1/+1. In this pool a deck plays the colour
  of its own creatures, so the error is rare and it is always in the
  direction of respecting the body; pricing it properly wants a planner
  bound to a seat that is not ours, which is a larger thing than this
  reading. It also does not see the two CARD-LOCAL firebreathers (Dragon
  Whelp, Nalathni Dragon, `EffectIntent.CARD_LOCAL_PUMPS`), because that
  table is gated behind `pumps_to_attack` and one reading with two gates
  is two stories; a Whelp of theirs with Mountains open is still a 2/3 to
  the attack declaration. And the thing the CUT above leaves open is a
  rung and not a read: the block ladder has nothing between the safe block
  (`cur_power >= 2`, which a printed 0/1 never satisfies) and the chump,
  so there is no place for it to say *this body dies either way, and
  blocking spends their mana instead of my life*. That is the comparison
  `_face_damage_value` already prices for the chump rung, and giving it to
  the middle of the ladder is `reinforces_blocks`' shape
  (`docs/AI-next-wave.md`, combat P4) rather than this knob's.
- `holds_x_burn` is the HOLD half of its row only. The CHAIN — two burn
  spells that kill together, the first sized for its share and the
  second's cost booked out of the reserve — is wave 3's
  (`docs/AI-next-wave.md`, `docs/forge/casting.md` P7). And
  `AiPlayer._in_danger` reads the board's clock and nothing else: burn in
  their hand, an upkeep price we cannot pay, a Vise ticking — none of
  those lift the hold, and the first of them is a hand read this AI does
  not do at all.
- The mana planner does not know that a Mishra's Factory, a Library or a
  Strip Mine is worth more untapped than a Forest: among equal sources
  it takes them in battlefield order, so a second animation can be paid
  by tapping the first animated body when the Factories come before the
  plain lands. `animates_to_attack` excludes the body it has already
  animated; the tie-break itself is open (`docs/ROADMAP.md`, the third
  pass). ~~And no rung animates a Factory to BLOCK on the opponent's
  turn.~~ **Closed 2026-09-10 — FIXED, `reads_manlands`** (§4), and with
  it the other half of the same fact: a manland of THEIRS is a body the
  attack has to price. What is left open is smaller and is named on the
  knob's own rows below.
- `levels_boards`' LAND SWEEP (2026-09-10) reads the BOARD's clock and
  nothing else, and the thing it cannot see is the half of a mana drought
  that hurts most: what it does to the HAND. Armies of Light Armageddons
  a Big Green holding two Craw Wurms and a Force of Nature, and the
  reason that is right has nothing to do with the creatures already on
  the table — it is the four fatties that will never be cast. Pricing it
  wants the same HORIZON `counts_the_race` is named for (wave 4): how
  many turns each side needs to rebuild, which is a hand size, a curve
  and a land count over turns, and nothing in the engine estimates turns.
  So the reading errs toward NOT casting, and the measurement says that
  costs a little against a fat green deck and gains a little against a
  fast white one. Forge's other two clauses are ruled and not built for
  the same reason each time: its Crucible of Worlds branch names a card
  this pool does not have, and its second land test ("never when we would
  lose more land value") is the swing itself once the lands are priced by
  `Evaluator.land_value`, so it is already there rather than missing.
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
- ~~`trusts_abyss` reads the table as it stands: a creature it lets
  through because it is the next meal can be sheltered before their
  upkeep by a cheaper creature cast after it (Blue Skies' one-drop
  fliers, the −0.3 there), and a second copy of a creature already on
  the table is let through as level with it although only one of the
  two dies.~~ **Closed 2026-09-10 — both FIXED, as an EXTENSION of the
  knob rather than a knob of its own** (§4). The knob's promise is one
  sentence — *the counter is kept because the feeder answers this
  creature* — and both rows are boards where the feeder does not answer
  it, so a second knob would have meant a seat keeping a counter on a
  promise a different knob was responsible for. THE TWIN is one
  character of arithmetic and a paragraph of reasoning: the shelter test
  in `AiPlayer._is_next_meal` asked for a creature worth strictly LESS
  than the newcomer, and a feeder takes one body a turn, so a second
  Sengir Vampire beside the first leaves a Sengir Vampire standing
  whichever of the two is eaten. THE SHELTER CAST is the "after" board
  read once more (`AiPlayer._shelter_swing`): the meal a feeder takes
  today is the cheapest legal creature of theirs, a newcomer worth less
  displaces it, and what the displacement buys them is the difference —
  which is what the spell is worth countering for and has nothing to do
  with what it is worth on the board. A Mesa Pegasus that saves a Serra
  Angel is a Serra Angel, and it is read BEFORE the profile's bar
  because the whole point of it is a one-drop the bar would never look
  at. WHAT IS LEFT is the second feeder: the swing is read one feeder at
  a time and the largest displacement taken, because a second Abyss
  would eat off a board this reader would have to simulate. The pool has
  one card of the shape.
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
  mana no plan wanted is still spent. ~~What is left open is smaller and
  named at the site: a body in a GANG is priced at no breath, and
  `_offensive_combat_response` spends the leftovers without consulting
  the plan.~~ **Both closed 2026-09-09 by the fourth pass** (§4) — one
  FIXED, one RULED.
  * The GANG's breath: FIXED, and it was not the safe direction after
    all. The reading erred safe, but it was mirroring a recovery that was
    itself wrong: the block ladder's third rung declares a gang — two
    bodies whose combined damage kills — on the probe's sizes, and
    `_combat_self_pumps` then asked each of them whether the breath let
    IT kill the attacker alone. On the third pass's own board (a Carrion
    Ants and a Scathe Zombies in front of a Force of Nature, six Swamps,
    the gang priced at exactly the eight an 8/8 needs) the pilot declared
    the gang and bought NOTHING: both bodies died at 0/1 and 2/2, five
    trampled through, the trampler walked away and every Swamp was still
    untapped. `AiPlayer._band_kills` is the ladder's own gang question
    written down as a predicate, and the recovery, the trampler's residue
    (`_absorbed_by`) and the declaration all ask it now. The mates are
    priced at what the plan still owes them, so a gang reaches one
    verdict and buys together; and because that pricing IS the plan, the
    question is asked only in the pass that honours it, which is where
    the null stays the null. ~~What is left, and it is the one already
    named on `_pump_plan`: mana spent between the declaration and the
    recovery by something else leaves a body short of the reach its plan
    promised, and the residue then over-reads by that much.~~
    **Closed 2026-09-10 by the fifth pass — FIXED, and the spender was
    the pilot itself.** Walking `_respond_action` in order, the routine
    that spends the plan's mana is the line directly above the recovery:
    `_combat_regeneration` buys a pre-emptive shield out of the same open
    pool, and the two were double-booked at the declaration as well
    (the ladder's `_dies_to` asks `_shieldable` -> `_can_shield`, which
    plans the shield against the WHOLE pool that `_pump_shares` is
    dividing). Reproduced on the fourth pass's own board plus one Drudge
    Skeletons: six Swamps, the swarm declared on six breaths, the shield
    took one, the gang question then said no — correctly, of five —
    and the recovery bought NOTHING; both blockers died, FIVE trampled
    through and five Swamps were left untapped. `_combat_planned_pumps`
    delivers the breaths the declaration was priced with before the
    pilot's own next discretionary purchase, and it is gated by the knob
    the plan is gated by, so below Sorcerer it returns before it reads
    the board. The counterspell and the answer to removal on the stack
    still come first and always could — `_pump_reserve` books
    `_held_reserve` out of every share, so the plan never owned that
    mana. WHAT IS LEFT is now only THEIRS: an opponent's effect that taps
    one of our lands between the two moments still leaves a body short,
    and `_owed_bonuses` is deliberately NOT re-read against the mana on
    the table — over-crediting a mate errs on the harmless side, because
    every breath it buys is toughness as well as power, so against the
    trampler this reading exists for the gang still absorbs the
    assignment it paid for, and on the opponent's turn that mana has
    nothing else to buy. Ruled, and pinned by
    `tests/ai/test_ai_pump_plan_broken_2026_09_10.gd`.
  * The LEFTOVERS: RULED, not built, and one half of it fixed for a
    different reason. `_offensive_combat_response` does spend off the
    plan — measured, two unblocked firebreathers behind four Swamps split
    two and two, and it poured all four into the first body it met — and
    it costs nothing: by the time it runs the bodies it serves are
    UNBLOCKED and every point they buy is face damage, which is fungible
    between them, so any split of the same pool lands the same total.
    Honouring it would be strictly worse in two ways (a dearer breath
    handed mana a cheaper one could spend, an allotment made out to a
    body that stayed home going unspent), so it stays off the plan. The
    OTHER half of that note was real and is fixed: the routine booked
    only `_main2_reserve`, so an unblocked firebreather spent a
    Counterspell's mana — priced at four breaths by the declaration, it
    bought six and tapped every land. It reads `_pump_reserve` now, the
    same cost every other breath in the file is priced against.
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
  callers and they are the four that wanted it. WHAT WAS LEFT OPEN was
  five rows, and the fifth pass (2026-09-10, §4) closed the four that
  were open questions — two RULED and two FIXED; the fifth, a roll, was
  already a ruling and stays one:
  * ~~A TOLL WITH NO PRINTED PRICE TO STOP IT is not read at all — a
    Serendib Efreet's point a turn, an Erg Raiders' two, a Yawgmoth
    Demon's.~~ **Closed 2026-09-10 — RULED, not built, and the reason is
    that the horizon does not exist.** The honest price of an endless
    stream is the stream times a number of TURNS, and nothing in this
    engine estimates the turns a game has left: `_face_damage_value`
    scales one hit by the share of a life total it takes,
    `Evaluator.position_score` is a snapshot of life, board, hand and
    lands, `CombatSearch` looks exactly one turn ahead, the liability
    reading's own `turns` are the turns our MANA needs to reach a printed
    price, and `PACE_HORIZON` is twenty DRAW STEPS of a library race
    under `paces_draws` — a decking clock, not a game clock. The one
    horizon derivable from what is here is the toll's own, our life over
    its rate, and taking it prices a Serendib Efreet at 8.5 minus our
    whole life: −1.5 at twenty, and every drawback creature in the pool
    out of its own deck. An invented constant would be worse than the
    silence. The reader SEES the stream (`_own_toll` returns one damage
    for the Efreet); it is the price that refuses, and the horizon is
    `counts_the_race`'s to bring (wave 4).
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
- ~~`pumps_to_attack`'s burn reading answers DAMAGE and nothing else. A

    a Mana Crypt keeps its printed worth. Still open, still ruled.
  * ~~A SYMMETRIC toll ("deals 1 damage to that player" — Copper Tablet,
    Manabarbs, Storm World, Power Surge) is not read.~~ **Closed
    2026-09-10 — RULED, and the census is the argument rather than the
    symmetry.** Of the six cards the pool puts on the shape, FIVE are
    refused by rules that predate the question: Manabarbs fires on a LAND
    BEING TAPPED FOR MANA, which `TOLL_BEATS` excludes on purpose (a
    price the seat agreed to is not a toll), and Karma ("damage equal to
    the number of Swamps they control"), The Rack, Storm World and Power
    Surge print a COUNT the reader will not do, which is
    `TOLL_UNKNOWABLE`'s own ruling — a regex for "deals N damage to that
    player" finds a bare number in none of the four. What is left is ONE
    CARD, Copper Tablet, and pricing a shared clock needs to know whose
    race it is winning: which seat it kills first (answerable, two life
    totals and a rate each) AND whether the game ends from something else
    before it kills either (not answerable — the same missing horizon as
    the row above). So it is a `counts_the_race` question after all, and
    it stays wave 4's.
  * ~~THE UNTAP PRICE PRINTED ON THE AURA rather than on the host is not
    read … it cannot give the creature away.~~ **Closed 2026-09-10 —
    FIXED, and the stated reason for leaving it was wrong.** The
    understatement is harmless to `spares_own`'s door, which needs a
    price BELOW zero — and to no other caller: `answer_card` gives up the
    LEAST valuable of ours when the giving is no cost we chose
    (`feeds_worst`), and zero is the least there is. A Serra Angel under
    a Paralyze with four Mountains open was fed to a Lord of the Pit's
    upkeep ahead of a Grizzly Bears, on a turn the {4} the aura itself
    prints would have given the Angel back. `AiPlayer._untap_prices`
    reads the host's own line AND the lines of everything in
    `CardInstance.attachments` — the same beat (`TOLL_BEATS`), the same
    line reader (`EffectIntent.toll_of_line`), the trigger's own
    condition put to it with a probe event (CR 603.4), and the line
    required to say "untap" or it is some other bargain. Who controls the
    aura is not asked, because the printed line does not ask it: an enemy
    Paralyze offers the {4} to the creature's controller, which is the
    copy of the card this pool plays. WHAT REMAINS, and it is smaller: a
    price printed on a permanent with NO structural link to the host —
    Magnetic Mountain's "{4} for each tapped blue creature" — cannot be
    tied to THIS creature without reading the card's own filter, so a
    blue creature under one still reads as dead weight. It understates,
    in the direction that cannot give a permanent away.
  * ~~`EffectIntent.damage_to_target_controller` … only the OWN-side half
    is priced … An enemy Detonate's X is still an unpriced bonus.~~
    **Closed 2026-09-10 — FIXED, under the knob that owns the field.**
    A half-read field is what made the pilot blind to a lethal Detonate:
    their Nevinyrral's Disk, the opponent at four, five Mountains and the
    card in hand read as an ordinary 7.6 and not as a win. Both halves go
    through one line now (`AiPlayer._controller_sting`): ours is charged
    at the reaper's rate as before, theirs is credited on the AI's own
    clock (`_face_damage_value`, the currency every point of combat
    damage to a face is already read in) and is worth `LETHAL_WORTH` when
    it is lethal. It is gated on `prices_liabilities` and not shipped
    knobless, which is what keeps the null the null — the objection that
    deferred it ("pricing it moves the shipped pilot on both arms") was
    an objection to a reader change, and this is a knob's.
- `pumps_to_attack`'s burn reading answers DAMAGE and nothing else. A
  spell that kills by shrinking — "target creature gets -2/-2" — has no
  `EffectIntent.damage_at` for the arm to read, so a Frozen Shade with
  Swamps open still dies to one although the toughness it can buy would
  save it.~~ **Closed 2026-09-10 — RULED, not built: the shape is not in
  this pool, and the census is the argument.** Walking every printed
  effect in the registry, a negative TOUGHNESS term exists on exactly two
  cards and both are `self_buff()`s on their own card (Urza's Avenger's
  `{0}: -1/-1`, Wall of Wonder's `+4/-4`). Every shrink that can be aimed
  at a creature of ours takes POWER only — Ghosts of the Damned and Hell
  Swarm at -1/-0, Pradesh Gypsies, Staff of Zegon and Marsh Gas at -2/-0,
  Bone Flute at -1/-0 — and no amount of it kills anything. Two more
  things take toughness off one of ours and neither is the shape either.
  HOLY LIGHT ("nonwhite creatures get -1/-1") is the pool's only
  until-end-of-turn toughness shrink and it would kill a Frozen Shade
  behind four Swamps — reproduced, four Swamps untapped — but it TARGETS
  NOTHING: `_save_from_the_stack` walks `top.targets` and there are none,
  so the arm is never reached, `EffectIntent` reads the card-local effect
  as `unknown` besides, and the card is in no shipped deck. Everything
  else is PERMANENT — the Immolation and Weakness auras, which ARE in the
  1997 decks, and the Spirit Shackle, Takklemaggot and Unstable Mutation
  counters — and a breath lasts until end of turn (CR 514.2), so it
  postpones the state-based action by one cleanup and does not save:
  reproduced, four breaths make the Shade a 6/3 that lives the turn and
  is in the graveyard at the cleanup with every Swamp spent. So the arm
  answers nothing because there is nothing here to answer, and
  `_find_pump_instant` is silent for the same reason — the two readers
  stay in step. Widening either is still a READER's question (an intent
  that reports the toughness a spell TAKES), and it is blocked on a card
  this pool does not have. Pinned by
  `tests/ai/test_ai_shrink_and_dream_2026_09_10.gd`, census and all.
- `tutors_for_the_turn` (2026-09-10) knows three things about a fetch and
  four things are open, each the honest cost of reading only what the
  engine already has a reading for.
  * ITS THIRD STEP READS TWO SHAPES. "The card worth most on THIS board"
    is `_sweep_value` for a sweeper and `_level_value` for a leveller,
    which are the two readings `_size_and_aim` already opens with; every
    other card keeps its printed worth. The casting note's own examples
    name two more — *a Moat when their creatures are ground-bound*, *the
    finisher when the board is ours* — and neither exists as a reading
    anywhere in this engine. Inventing one for a fetch would be a
    card-shaped rule in the one place the ladder forbids it (§1), so the
    fetch says only what the caster can already say.
  * THE EVALUATOR IS FLAT AT THE CHEAP END. `Evaluator.card_value` floors
    every spell at 2.5, so among the candidates next turn's mana reaches
    an Ancestral Recall, a Swords to Plowshares and a Dark Ritual all
    price the same and the shuffle decides which comes back. That is not
    this knob's flatness — `_try_cast_best` ranks the hand by the same
    number — but the fetch is where a human notices it, because a tutor
    is asked once a game and the answer is remembered.
  * THE COLOUR PRONG NEARLY NEVER BITES IN THIS POOL, and the census says
    so: of the sixteen decks that play Untamed Wilds, thirteen are
    mono-green, so "which basic" has one answer whatever the hand wants.
    Alt-A-Kesh (seven Forests, seven Swamps, seven Islands and four Gem
    Bazaars) is the deck that could ask it and **4 games of 1 000 play
    differently** — its manabase is even enough that the shortfall is
    usually nought. The reading is right and the pool does not put the
    question.
  * IT IS ONE CARD IN SIXTY, and that is a fact about the format rather
    than about the knob: Demonic Tutor is RESTRICTED, so every deck in
    this repository that plays it plays exactly one. The search resolves
    in about one game in three and the ANSWER differs in about one in
    eight, which no win rate at a thousand games can see; the census and
    the flips are what it is read by.
- `spends_counters` prices no counter at all, on purpose: fuel is worth
  zero to every reader the pilot owns until it is spent. Three things
  follow, and each is the honest cost of that.
  * ~~A counter with TWO uses is spent on whichever comes first. Rasputin
    Dreamweaver's dream counters are a shield AND a colourless mana, and
    the pilot buying the shield does not know it just spent a mana.~~
    **Closed 2026-09-10 — RULED, and the measurement says something
    simpler than the note did: the pilot makes NEITHER use, so there is
    no preference to decide.** THE MANA is refused by the mana planner
    itself — a mana ability with a rider the plan's arithmetic cannot
    model (mana, life, a sacrifice, counters) is not a source, and
    Rasputin's "Remove a dream counter: Add {C}" is that comment's own
    example in `engine/mana_planner.gd`. THE SHIELD is admitted by
    `_ability_available` and then priced at nothing by `_ability_option`,
    because `DreamShieldEffect` is card-local and the reader calls it
    `unknown` — the same scorer gap the Necropolis row below names — and
    it is not reachable in the 1997 damage-prevention window either:
    `_effects_answer` wants `is_damage_prevention` and one of two known
    effect classes, and the card declares neither. Measured: a 4/1 with
    seven dream counters blocks a Hill Giant and dies holding all seven,
    on both arms of the knob. Both fences are outside `spends_counters` —
    one is the mana planner's, one the general scorer's and the card's
    own script — so the knob has nothing to prefer between and no price
    to carry. WHAT WOULD HAVE TO BE READ the day both uses are reachable:
    not the two prices, which exist already (`_packet_worth` prices a
    point of prevention at the creature when the point is the one that
    kills it, and a mana is worth the cast it completes), but the ORDER —
    the counter is spent one at a time and the two uses come up in
    different windows, so the pilot would have to know at the earlier one
    how many counters the later one will want, which is the damage that
    is COMING rather than the damage that has landed. That is the same
    forward reading `counts_the_race` is named for (wave 4). Pinned by
    `tests/ai/test_ai_shrink_and_dream_2026_09_10.gd`.
  * A COUNTER SOME OTHER ABILITY OF THE SAME CARD READS is out of the
    ruling's reach, because a card's own script cannot be read from
    outside it. In this pool no such counter is a COST — Armageddon
    Clock removes its doom counter as an EFFECT, and the Oracle Time
    Vault has no counters — so the rule refuses nothing it should allow
    and allows nothing it should refuse. The day a card makes a clock's
    counter a cost, the card is where the reading has to be declared.
  * ~~NECROPOLIS OF AZAR STILL NEVER MAKES A SPAWN. The gate opens for it
    (`{5}`, one husk counter, and the husk counters are fuel), but
    `AiPlayer._ability_option` has no arm for an effect whose payload is
    a TOKEN, so the general scorer prices the ability at nothing and
    passes it by.~~ **Closed 2026-09-10 — FIXED, under
    `plays_engines`** (§4, the token arm). It was a scorer's gap and not
    this knob's, and the gap was wider than the one card: FIVE permanents
    in this pool make a creature token through an activated ability and
    not one of them had ever made one — The Hive on ten open mana, Boris
    Devilboon, Master of the Hunt, Serpent Generator and the Necropolis.
    The reading is `EffectIntent.TOKEN_MAKERS`, the sixth card-local
    table, and it states the body ONE activation GUARANTEES; the price is
    that body on `Evaluator.permanent_value`'s own scale
    (`AiPlayer._token_value`), never a constant. What is left open is
    named on the arm itself, below.
- `plays_engines`' TOKEN ARM (2026-09-10) buys a body and knows four
  things about it: its power, its toughness, its printed keywords and
  whether it walks. Four things are open, and each is the honest cost of
  a reading that states only what an activation GUARANTEES.
  * IT NEVER FIRES IN THE PILOT'S OWN MAIN PHASE. The value it reaches
    (a 1/1 flier for `{5}` prices at 1.5, a 1/1 at 0.5) is below
    `ABILITY_BAR_MAIN`, so every token in the pool is bought at the mana
    sink — the opponent's end step, where the mana would be lost anyway.
    That is deliberate and it is the arm's own note: a token is
    PERMANENT, so unlike an animation it is not lost by waiting, and the
    main bar asks "is this worth the mana a SPELL might want". What
    waiting costs is one turn of the body's availability as a BLOCKER,
    because the sink runs after their combat. Whether the arm should
    state its own bar the way the animation does is a measurement
    nobody has made.
  * THE TOKEN'S OWN ABILITIES ARE NOT PRICED. Serpent Generator's Snake
    carries a poison trigger and Master of the Hunt's Wolf grants itself
    banding; the row claims neither, so both are bought as vanilla 1/1s.
    It understates, which is the direction a purchase should err in, and
    it is the same understatement `Evaluator.permanent_value` already
    makes about every triggered and static ability on a real creature.
  * THE ROLL IS READ AT ITS FLOOR. Necropolis of Azar's Spawn is 1/1 to
    3/3 rolled on resolution, and the row says 1/1 — the Rainbow Knights
    ruling with the sign the other way, so the pilot may buy a 3/3 for
    the price of a 1/1 and never the reverse. A DISTRIBUTION is the same
    piece of work it was there and is not blocked on this card.
  * A COIN FLIP HAS NO ROW AT ALL, so Bottle of Suleiman ({1} and a
    sacrifice for a 5/5 flier or five damage to our own face) and
    Pandora's Box ({3} for one creature out of both libraries and a flip
    for EACH player, which can hand the opponent the copy) are still
    never activated. That is the Camouflage rule and not an oversight;
    what would lift it is an evaluator that carries a distribution.
- `AiSideboard` scores a card by what it ANSWERS and never by what it
  costs the seat that boards it, so a SYMMETRIC sweeper's `creature` key
  is read as a bonus in proportion to the opponent's creatures with our
  own side of the board unread. Volcanic Eruption is the card that raised
  it and Volcanic Eruption is closed (§4, the fallout): the planner
  prices the blast now, the swap measures as a wash, and the 1997
  designer boarded the same card. The general question is not closed —
  Earthquake, Hurricane and Wrath of God are in the shipped sideboards
  and the same reading applies to all of them — and it is a bigger piece
  of work than a card: the heuristic would have to know the deck it is
  boarding FOR, which is the one thing it currently reads only for
  colour (`deck_colors`). Two smaller over-reads sit beside it and are
  worth naming while somebody is in the file: "put into a graveyard this
  way" gives the Eruption the `graveyard` key, so a deck that recurs its
  dead makes the blast look like graveyard hate; and `SIGNAL_CAP` counts
  the Mountains seen, not the Mountains that will be on the table when
  the spell is cast.
- `reads_gaze` (2026-09-10) reads three printed shapes and leaves five
  things it could have read, each the honest cost of stating only what a
  card actually prints.
  * A GAZE WITH ANOTHER TIMING is not read at all. `EffectIntent.is_gaze`
    wants "destroy that creature ... at end of combat", which is what
    both cards of the shape in this pool print (Cockatrice, Thicket
    Basilisk), because that timing is the one the arithmetic below it is
    true for: the victim still strikes, so `AiPlayer._damage_from` is
    untouched. A line that destroyed the blocker on the spot would also
    take its damage off the exchange, and Forge's own note says to read
    the timing rather than assume it — so an unread timing leaves the
    pilot exactly where it was rather than inventing a rule for a card
    that is not here.
  * THE PAIR IS PUT TO THE TRIGGER IN BOTH ROLES. `AiPlayer._dies_to` is
    asked about two bodies and is deliberately blind to which of them
    attacks — the crack-back matrix asks both ways about the same pair —
    so the gaze's condition is offered the pair as attacker/blocker and
    again the other way round, and either answer is taken. A card that
    gazed in ONE direction only would be over-read by that. This pool
    prints none, and demanding both answers would under-read the two it
    does print the moment they attack.
  * RAMPAGE IS COUNTED WHERE A GANG IS PRICED and nowhere else — the
    block ladder's gang rung, the band predicate the recovery shares, the
    panic line's trample residue and the crack-back model's own
    resolution. It is NOT counted on an attacker of OURS that their gang
    is about to grow, because `AiPlayer._attack_risk` asks one blocker at
    a time and has no model of a gang at all; that understates our own
    attacker, which is the timid direction rather than the fatal one.
  * THE LETHAL PUSH DOES NOT SUBTRACT AN EXECUTED ATTACKER.
    `AiPlayer._damage_through_blocks` counts every body's power toward
    the swing that wins the game, and a body their Royal Assassin answers
    at the declaration lands none of it. The cohort's own reading does
    subtract it (`AiPlayer._cohort_value`), so the case is a swing that
    is lethal ONLY with the assassinated body's damage in it — rare, and
    the push is the one reading in this file that is allowed to be
    optimistic, because a swing that wins the game has no next turn to
    be wrong in.
  * AND IT IS NOT MEASURABLE IN THE LAB, the rampage half. No deck in
    `decks/` holds any of the pool's seven rampage cards (Craw Giant,
    Frost Giant, Wolverine Pack, Marhault Elsdragon, Aerathi Berserker,
    Hunding Gjornersen, Chromium — all Legends), so the Deck Lab can
    only ever measure the other two readings and the rampage half is
    pinned by `tests/ai/test_ai_reads_gaze_2026_09_10.gd` alone. That is
    said here rather than dressed up as a wash.
- `reads_manlands` (2026-09-10) buys a body and knows three things about
  it: the size the animation prints, whether the block declaration would
  use it, and whether it comes back. Four are open.
  * THE ANIMATED BODY IS NEVER PUMPED. Mishra's Factory's second ability
    — "{T}: Target Assembly-Worker creature gets +1/+1" — is a TARGETED
    pump and not a self-pump, so `pumps_to_attack`'s reader cannot see
    it and the classic two-Factory 3/3 block is not planned. It
    understates, which is the direction a purchase should err in: the
    pilot declines blocks a 3/3 would make rather than making blocks a
    2/2 cannot survive.
  * TWO OF THEIR TIMING RIDERS ARE NOT MODELLED.
    `AiPlayer._animatable_bodies` honours the printed ones that cost
    nothing to read — combat-only, a named step, "before" a step, whose
    turn — and skips `ActivatedAbility.max_per_turn` and an
    `activation_condition`, which would need a per-instance count or the
    card's own predicate. Both over-include, and on a read of what may
    BLOCK us over-including is the safe way to be wrong.
  * OUR OWN FACTORY'S ATTACK IS STILL PRICED WITHOUT THEIRS.
    `AiPlayer._animation_value` refuses an animation when an untapped
    CREATURE of theirs eats the body, and `_would_attack_once_animated`
    puts the question to `_attack_choice` — neither reads a manland of
    theirs, so the pilot may animate a Factory to attack into a Factory
    it will then decline to swing into. It costs a mana and not a card,
    and it is the SAME gap `animates_to_attack` already carries between
    its probe and a pumped declaration: the animation probe asks the
    plain `_attack_choice` while the real declaration may be the pumped
    one. Both want the probe routed through
    `AiPlayer._attack_declaration`, which is one journal inside another,
    and that is a measurement nobody has made.
  * THEIR ANIMATED BODY IS COUNTED AS A CREATURE ON THEIR NEXT TURN TOO.
    The declaration is made with the animation hung on the board, so the
    crack-back model — which builds itself out of `is_creature()` — sees
    a Factory that would in truth have to be paid for again. It is the
    same judgement `AiPlayer._build_combat_model` already records about
    its other defensive reads, and the mirror of `animates_to_attack`'s
    ruling about OUR animated body, which is excluded because holding it
    home buys nothing.
- The counter cost is read on OUR side of the table only. A creature of
  THEIRS with a corpse counter is judged regeneration-capable by
  `AiPlayer._shieldable`, which counts their open mana and never asks
  whether the ability's cost is a counter they have — an over-read that
  predates this ruling and runs in the safe direction (it makes their
  Ghoul look harder to kill than it is).
- The Magician has no crack-back search and no capabilities — by ruling.
  Anything that turns out to be a malfunction rather than a weakness
  (the way `minds_pain`, `fits_auras`, `mulligans`, `feeds_worst`,
  `spares_own`, `prices_liabilities` and `prices_fallout` did)
  goes on everywhere;
  anything that is a layer of play stays a rung.
- The 1997 adventure's difficulty (gold, deck minimum, life, the creature
  bonus, Arzakon's 100/200/300/400) is not a duel-profile matter and is
  not modelled here; it belongs with the adventure.
- What the engine should eventually know about the old loops a player
  brings to the highest table — Channel-Fireball, the infinite turn, the
  Vise behind a Moat, decking — is `docs/arzakon.strategy`, section 4.

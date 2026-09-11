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
| `times_sweeps` | off | off | on | on | prices a board wipe by the damage it keeps off its life as well as the permanents it trades — lethal-worth when the sweep is the out, a creature its Abyss will eat never counted — and fires one it can activate in the opponent's combat, after the attackers are declared and before the damage (the Disk as a Fog). **And since 2026-09-10 it DEFERS to that moment instead of merely adding it** (`AiPlayer._defers_sweep`): the combat offering was an addition, so our own main phase went on offering the same activation at its own bar with a relief read off an attack that had not happened, and a Disk worth firing at home still fired at home — a Disk and two Jayemdae Tomes of ours against three Grizzly Bears went off in our own first main phase, both Tomes in the graveyard, on a turn where waiting cost nothing at all. The deferral is that relief read ONE PHASE EARLIER: while a creature of theirs could attack us, their combat is the better moment for the same activation — the attack declared instead of guessed, and whatever their own main phase adds to the table swept with it — so the sweeper waits, in our main phase and at their UPKEEP alike, both of which come before their combat. It is bounded by the same reading: a board that cannot attack has no combat to wait for, so the Disk still goes off at home under our own Moat rather than waiting on a moment the Moat itself has refused; a sweep that WINS is never deferred; a printed timing rider that would refuse their combat ends the wait; and a combat that never comes still ends in the mana sink at their end step, so no deferred sweeper is stranded. **And the relief's "after" board now applies the STATICS the sweep removes** (`AiPlayer._ground_the_sweep_opens`): it read the survivors' attack legality off the board as it STOOD, so a Moat of ours went on holding the ground in a reading of the board the same sweep had just destroyed the Moat on — at two life, with a Moat and a Disk against a Serra Angel and a regenerating 2/2, the relief came back 1008.00, the Angel's four priced as lethal plus a lethal-worth for a sweep that "is the out", while the 2/2 the Disk does not kill walks in for two the moment the Moat is gone. Asked without replaying the game: `cur_cant_attack` is set by a static and by nothing else, so a sweep that takes EVERY permanent carrying a static (`MtgGame.battlefield_with_statics`) can leave nothing that grounds anything — and where a static source survives, the old reading stands, which is the conservative direction |
| `trusts_abyss` | off | off | on | on | keeps its counterspell when the creature spell on the stack is the next meal of a feeder on its table — The Abyss will destroy it at their upkeep — and spends it on what the feeder cannot eat |
| `pumps_to_attack` | off | off | on | on | judges its own creature at the size its OPEN MANA can reach when a combat declaration is made — a Carrion Ants behind four Swamps is a 4/5, not a 0/1 — attacking AND blocking (the name is the half it was born for), with the second main phase's cast kept whole on its own turn and the held instant on both, a capped breath counted at its cap, and the two card-local firebreathers (Dragon Whelp, Nalathni Dragon) read at last — three breaths and never the fourth unless that attack ends the game; and since the third pass the breaths the pilot BUYS are the ones the declaration was priced with — the split of the one pool is spent as it was allotted, and a trampler's overflow is measured against the toughness that will actually be there; and since the fourth, the BURN SPELL ON THE STACK — a Frozen Shade with Swamps open grows out of a Lightning Bolt instead of dying with the mana up, and the breath is asked before the pump instant in hand because the mana untaps and the card does not; and since the fifth, the breaths a block was DECLARED on are bought before the pilot's own pre-emptive regeneration shield can spend them — the one thing that was measurably breaking its own plan |
| `spends_counters` | off | off | on | on | pays a cost of "remove N <kind> counters from this permanent" — the AI had never removed one in its life, so an Osai Vultures sat on its carrion counters and a Scavenging Ghoul never regenerated. Spendable when NOTHING BUT THE COST READS THE COUNTER: refused when the kind's own NAME is a P/T delta (a Triskelion's +1/+1 counters are the 4/4) and refused when the permanent's live `damage_eats_counters` names it (a Rock Hydra's heads are its life). What is left is fuel — carrion, corpse, husk, matrix, dream — and fuel is worth zero to every reader until it is spent, so the effect is the whole trade |
| `ranks_counters` | off | on | on | on | picks WHICH counterspell answers a spell instead of firing whichever sat first in its hand, and pays an unless-cost's X to the caster rather than to the mana on the table. Until 2026-09-10 `_try_counter` walked the hand in order, so a Mana Drain and a Power Sink in one hand were spent by the shuffle, and Power Sink's X was "as deep as the mana goes" — eight Islands to make a price of one unpayable. The ranking is five readings, none of them a card's name: can we pay for it (a counter the mana does not cover used to end the search with a pass), does it actually STOP the spell (a printed "unless its controller pays" price the caster can simply pay is no counter — the hard card goes ahead of it, which is also why a Sink is not cast at all when they can pay it and something else answers), what it costs us now with its X included, the narrow card before the wide one, and then the card the evaluator would rather keep — so a Power Sink for one takes the small threat on a tapped-out turn and the Mana Drain is still in hand for the Serra Angel. Magician and up, the rung `holds_instants` is on: an Apprentice never casts a counterspell at all, so it is as inert there as `counter_threshold` |
| `holds_x_burn` | 0 | 0 | 3 | 5 | the smallest REACH — the largest X the mana can pay — at which the profile will point an X burn spell at a creature while the game is young; 0 never holds. A Fireball is two damage on turn three and eight on turn nine, and the deck holds it because it is the reach: `_size_x_burn` sized the X to the victim, which is right, and had no reading of whether the card was worth casting yet, so a Wizard on three Mountains spent one of Mountain Artillery's two Fireballs on a Grizzly Bears. The hold is bounded by the game's own age (only while the turn count is under twice the number, in player turns) and lifted by readings the pilot already makes rather than by a constant: a burn that wins is returned by the face arm before this is asked, and `AiPlayer._in_danger` — the panic line read a fourth time, against the damage their board would actually land through the blocks this seat would make — spends the card the moment the clock says to. The face arm still runs under the hold. It reads the REACH and not the shot on purpose: gating on the X actually paid refuses a Fireball for four at a Serra Angel for a game's first nine turns, which the suite has pinned as correct since the Fireball was first sized. **And since 2026-09-10 the same number carries THE CHAIN** (`docs/forge/casting.md` P7's second half), which is the same sentence read forwards instead of backwards: the hold answers *is this X burn worth pointing at a creature at all*, and the chain answers *which creature*, once the answer is one card short. `_best_victim` asks `EffectIntent.kills` of ONE card at a time, so a Fireball and a Lightning Bolt in one hand on four Mountains looked at a Serra Angel and both answered honestly — three is not four, and three is not four — and the pilot PASSED with three of its four mana enough to kill a 4/4 flier. `AiPlayer._burn_chain` finds the creature the two kill together, sizes the X to its SHARE (the Fireball for one, not for the reach's three), refuses the pair unless ONE plan pays for both, and books the partner's cost in `_held_reserve` — Forge's `reserveManaSourcesForNextSpell` at the same seam. The partner is a card whose damage is PRINTED: a second X spell is refused on arithmetic, because each X spell pays a coloured pip of overhead and one of them reaches further alone than two do. The second half is released by `AiPlayer._finishes_damaged` — a held burn that kills a creature ONLY because of the damage already marked on it cannot wait for their end step, since marked damage is wiped in this turn's cleanup (CR 514.2) — and that reading also spends a Bolt on the blocker that came back from combat with three points on it. ONE KNOB AND NOT TWO because the two halves would contradict each other: at a reach the hold refuses, a separate chain knob would point the same card at the same creature for the same turn. The hold is asked FIRST and wins, `_in_danger` lifts both together, and Forge arranges it the same way — its chain chance is forced to 100 exactly where its hold stops refusing |
| `reads_gaze` | off | off | on | on | reads the three printed lines that settle a combat without ever entering the damage arithmetic, all three at `AiPlayer._dies_to`'s own seam. THE GAZE: a Cockatrice or a Thicket Basilisk destroys whatever it blocks or is blocked by, at end of combat — so a Craw Wurm no longer swings into one for free (`_attack_risk` 0.0 before, 2.5 after) and our own Cockatrice stops watching a Craw Wurm walk past for six. THE RAMPAGE (CR 702.23): the engine gives a blocked attacker +N/+N for each blocker past the first and the gang rung ignored it, so two Grizzly Bears ganged a Craw Giant on `2+2 >= 4`, met an 8/6, died both and took four trample; the number is counted now wherever a gang is priced, the crack-back model included. THE EXECUTIONER: an untapped Royal Assassin is why a non-vigilant body stays home, because tapping to attack is what makes it a legal target — a Hypnotic Specter used to swing past a 1/1 it cannot be blocked by and be in the graveyard before the damage step. Nothing names a card: two printed lines read as shapes (`EffectIntent.is_gaze`, `EffectIntent.destroys_the_tapped`, each with the card's own condition or spec put to it) and one engine field (`CardInstance.cur_rampage`) |
| `reads_manlands` | off | off | on | on | counts a permanent that can animate ITSELF as a body in the combat about to happen — theirs when we attack, ours when we block, and the two halves are one knob because either alone is a lie. Theirs: the attack was priced against their untapped CREATURES only, so a Mishra's Factory with `{1}` open was invisible to the cohort, to the pump rider and to the crack-back model, and a Llanowar Elves walked into a 2/2 that costs them a mana; the declaration is made now with their affordable animations hung on under the journal (`AiPlayer._attack_choice_reading_manlands`), the mirror of `animates_to_attack`'s own probe. Ours: `_animation_value` prices an animation by the ATTACK it enables and answers 0.0 at every moment but our own precombat main, so no rung had ever animated a Factory to BLOCK — three untapped lands watched a Grizzly Bears hit for two. It is bought at the moment `_defensive_combat_response` already owns, once their attackers are declared, and only when the block declaration itself would use the body AND the body comes back — `_animation_value`'s own refusal mirrored, because what animates here is almost always a LAND. Sorcerer and Wizard, with `animates_to_attack` and `plays_engines`. Nothing here names a card: the shape is `EffectIntent.animates`, and their mana is counted the way `AiPlayer._shieldable` already counts theirs — untapped permanents, public to both seats |
| `reads_pumps` | off | off | on | on | reads the pump on a creature it does NOT control as part of that creature's SIZE, which is the mirror of `pumps_to_attack` and the half that had never been built: two days of passes taught the pilot to size its own attack, block and survival by the mana it holds, and it had never once feared the same mana on the other side of the table. A Shivan Dragon with three Mountains open was a 5/5 and a Frozen Shade behind four Swamps was a 0/1, so a Grizzly Bears was sent into one at `_attack_risk` 0.00 — *we kill it and live* — and was in the graveyard with the Shade still standing and their life still twenty. `AiPlayer._pump_reach` answers what their body can grow to: the cheapest self-targeting `PumpEffect` ability with no tap cost, times the activations their OPEN SOURCES pay for, under three caps — the card's own *activate only N times each turn* (a Fire Drake behind five Mountains is a 3/2, not a 7/2), ONE POOL shared among the bodies of theirs this combat can ask it of (three Carrion Ants behind six Swamps are three 2/3s, not three 6/7s), and the smallest count past which no kill-or-survive answer on the board could still change (a Shade behind ten Swamps facing one Grizzly Bears is +2/+2). ONLY THE KILL TEST reads it and never the face damage, so the cohort still prices its damage through. AND IT IS ASYMMETRIC, because the Lab put it that way rather than the design: their pump deciding whether THEIR body dies is read everywhere, at `_dies_to`'s own seam; their pump deciding whether OURS dies is read only where we are choosing to SEND a body into it — `_attack_risk` and `_cohort_value`, the two halves of the attack declaration — because a blocker of ours that dies to their breath has SPENT their mana, and mana spent killing a blocker is mana that did not reach our face, while an attacker of ours that dies to it has bought nothing at all. Nothing names a card: the shape is `EffectIntent.pump_self`, and their mana is counted the way `AiPlayer._shieldable` already counts it — untapped permanents, public to both seats |
| `counters_by_shape` | off | off | on | on | counters by what the spell DOES and by what its own hand can answer, instead of comparing one printed number with `counter_threshold`. The bar is the wrong instrument at both ends of it, and the probe of 2026-09-10 says so in four numbers: Wrath of God prices at 5.00, Fireball at 2.50, Time Walk at 3.00 and Wheel of Fortune at 4.00 — so a Sorcerer (bar 5.5) watched a Wrath of God take four Serra Angels off its own table, and EVERY rung let a Fireball for eight resolve at eight life with the Counterspell in hand. `AiPlayer._counter_shape` answers ALWAYS, NEVER or *ask the bar* before the bar is asked. ALWAYS: a sweeper that takes more off our board than off theirs by a 2/2's worth; damage at our FACE that is lethal or crosses the panic line, the X read off the stack (and a player-hitting sweeper counted here as well as on the board, because an Earthquake for eight against a two-creature control deck is not a board sweep at all); a draw at OUR library that decks us; an extra turn; a wheel (`EffectIntent.wheels`) while our hand is the fuller. NEVER — Weissman's rule, *the counter is for what nothing else in the hand can touch* — when a card in hand answers the spell later and CHEAPER, with the mana for it PLANNED and not merely hoped for, and with the answer SPARE: every creature already on their side has a claim on the removal in our hand, so one Swords to Plowshares against a Savannah Lions on the table is a reason to counter the White Knight and Swords the Lions, not to let both resolve. That last clause is the Lab's and not the design's — without it the rule measured −1.7 with 3 games flipped to a win against 20 flipped away, and with it −0.1 with 2 against 3. It COMPOSES with `ranks_counters` rather than replacing it: this decides WHETHER a spell deserves a counter, that one decides WHICH counter answers it |
| `reads_lethal_x` | off | off | on | on | knows that LIFE can be spent as mana when the mana is lethal. Channel opens a mana source paid for in life (`MtgPlayer.life_for_mana`) and no seat had ever paid a point: the card is a card-local effect, so `EffectIntent.adds_mana` was false, the Dark Ritual gate never asked about it, and it was cast as a plain three-point spell — probed at HEAD, a Wizard holding Channel and Fireball with two Forests and a Mountain cast Channel into an empty board against an opponent at twenty and finished the turn with the Channel in the graveyard, the Fireball in hand and its own life at twenty. On, a life-for-mana spell is cast ONLY in a step where the life it opens makes an X spell in hand LETHAL, and once it is open the life is paid and the spell fired in ONE action (`AiPlayer._lethal_life_mana`), so no rung can pay life for mana it then fails to spend. Two printed shapes reach a player's life with an X and the pool holds one of each behind a Channel — the aimed burn (Fireball, Disintegrate) and the sweeper that hits PLAYERS (Hurricane, Earthquake), whose X lands on us too and must leave us alive. The life is capped at `life − 1 − their attack`, read through the same block plan `_in_danger` uses, so a Fireball is not paid for with the life a Serra Angel is about to take. Forge never gets here at all: Channel is `AI:RemoveDeck:All` there and `willPayCosts` keeps a margin of four |
| `checks_before_casting` | off | off | off | on | looks at the POSITION a cast would leave it in before it commits — the last layer of the ramp, and the one a player notices. `AiPlayer._try_cast_best` prices a cast by what the card is worth and what its victim is worth (`_cast_value`) and never by the board afterwards, so a Savannah Lions was cast in front of an untapped Prodigal Sorcerer and pinged off the table before it had blocked once: the card gone, the board where it was, and the pilot reading the cast as a gain. Forge's `OnePlaySafetyChecker` copies the game and replays the play; ours copies nothing, because `Evaluator.position_score` is a sum of four counted quantities and the position after a cast is therefore ARITHMETIC (`AiPlayer._cast_projection` — the card leaves the hand, the victim leaves their board, the life totals move, our permanent arrives). THE ANSWER IS THE ONE THE TABLE IS ALREADY SHOWING and no other: an activated ability on THEIR battlefield they can pay for right now that would take the body straight off again (`AiPlayer._answered_on_arrival`), their open sources counted the way `AiPlayer._shieldable` counts them, the effect read as a shape (`EffectIntent`) and never as a name; their hand is not looked at at all. It ABSTAINS unless that answer is on the table, which is the note's own "a pessimistic projection that never casts into open red mana" answered, and `AiPlayer._in_danger` lifts it, because a desperate play is allowed to be desperate — Forge's own escape. **And since 2026-09-10 the same knob carries THE APPETITE ALREADY IN PLAY** (`AiPlayer._fed_on_arrival`; docs/ROADMAP.md, "THE DECK, THIRD PASS" §6 — the Angel), which is this sentence with a TRIGGER in place of an activated ability: a printed upkeep trigger that declares what it eats (`TriggeredAbility.kills_each_upkeep`, the reading `trusts_abyss` already makes of THEIR board) is an answer written as a trigger, and it is read on BOTH sides of the table because the pool's one feeder is symmetric — The Deck's own three copies eat at ITS upkeep as surely as at theirs, and nothing in the cast path had ever asked. Fifty games of `decks/variants/the_deck_serra.deck` against White Knights at HEAD: 56 Serra Angels cast, **33 of them destroyed at our own upkeep with our own enchantment on the table**, and the two Angels attacked 29 times in fifty games between them; with the reading on, 38 cast and 21 eaten for the same 28 attacks — eighteen cards not spent, and a five-mana body that is summoning-sick until the upkeep that eats it could only ever have blocked once. Measured at +0.8 ±2.9 on that pair with 28 games flipped to a win against 12 flipped away (§4), and the starter matrix byte-identical to the tree before it, 0 of 10 000: no deck in `decks/` holds a feeder |
| `reinforces_blocks` | off | off | on | on | comes back to a block it has already declared and finishes the attacker off. `AiPlayer._best_block_for` is a LADDER and returns on the first rung that answers, so the free absorb — *a wall soaks the hit at zero cost, which is what walls are FOR* — sits above the value trade and above the gang: a Wall of Stone on the table blocked alone every time and the rungs below it were never reached, however many bodies were standing at home. Two walls of swords watched a Serra Angel walk away for free (each lives through it, and together they deal it exactly four); a Wall of Stone soaked a Craw Wurm while the Water Elemental beside it, which kills the Wurm, stayed home. `AiPlayer._reinforce_blocks` runs ONCE over the finished plan, and only where the band survives the attacker and does not kill it — never a chump, never a trade, never a body that `_shieldable`, indestructible or a printed gaze says cannot die. Safe bodies first and free of charge, then, only if those fall short, ONE body that dies to close the kill exactly. THE PRICE IS WHAT THE PAIR PUTS AT RISK — rung 3's own `price <= attacker_value * 1.5` read off the bodies that actually die, with Forge's stricter bound on top (the body that dies is worth strictly less than the attacker it kills) — so a survivor is free, a rampage that turns the pair into two corpses is charged for both, and nothing is written into the plan unless the band it builds actually kills. Sorcerer and Wizard, with the other combat reads |
| `minds_the_vise` | off | off | on | on | reads the two printed shapes on THEIR side of the table that decide what our own HAND should be doing, and neither of them had ever reached a decision. THE SQUEEZE: a permanent whose upkeep trigger deals damage counted off the cards in a hand (`EffectIntent.hand_toll_of_line`, read from the trigger's own line the way the wheel and the aimed discard are). Reproduced — a Wizard holding seven with a Black Vise across the table went on drawing (the Jayemdae Tome's tick is offered at a hand of five, where `_draw_need` returns exactly 0.00), cast by printed worth alone, and its one Disenchant took the Jayemdae Tome (4.20) over the Vise (1.00) while the Vise squeezed for three a turn. THE PRISON: a permanent of theirs whose static holds our creatures at home (`cur_cant_attack`, set by a static and by nothing else — the reading `_ground_the_sweep_opens` already makes), priced by `Evaluator.permanent_value` at a flat 3.20 with two Craw Wurms standing behind it. Three readings, each of them 0 with no such permanent on the table: THE ROOM (`_vise_room`, the cards the hand can still take before the toll charges for them — no Ancestral, no Tome tick and no wheel drawn into a hand a Vise is already counting), THE RELIEF (`_vise_relief`, a cast worth the point it takes off our next upkeep at `_life_price`'s rate) and THE PRICE (`_prison_relief`, what taking the card off the table is worth — the squeeze's next beat ours minus theirs, and the prison's held attack read through `_damage_through_blocks`). **THE RELIEF IS SIGNED, AND THAT IS THE HALF `docs/forge/casting.md` P4 HAS BACKWARDS**: its *"The Rack shares (a)-(c) with the threshold at three"* is one subtraction out — a Rack's X is three MINUS the hand, so emptying a hand under one is the worst play at the table, and a pilot that answered it like a Vise would take the full three every upkeep instead of nothing. The room is one-directional for the same reason (it may refuse a draw and can never demand one), and a WHEEL is charged for the seven cards it refills us to rather than credited for the one it spent, which is `docs/arzakon.strategy` §4's *"never Wheel or Twister into one"* as arithmetic. **WHAT IS NOT BUILT**: P4's *"priced at the damage it will deal over `PACE_HORIZON` turns"* is a stream times a horizon, and there is no horizon in this engine — the same ruling the `EffectIntent.TOLL_BEATS` census made on 2026-09-10 for `prices_liabilities`. Every reading here prices ONE BEAT, a number the table is showing; the horizon stays `counts_the_race`'s (§5) |
| `runs_loops` | off | off | off | on | prices the three cards of `docs/arzakon.strategy` §3C's infinite-turn loop by what they DO on this board instead of by the printed card, which is the one thing `Evaluator.card_value` cannot see. Reproduced, all three at the same seam: a Wheel of Fortune came out at **4.00 with our hand at seven and theirs at nothing** — a gift of six cards — and at **4.00 with ours at one and theirs at seven**, a gain of six, the same number both ways round; **Time Walk came out at 3.00 with three Serra Angels on the table**, an extra turn worth twelve damage priced at a Counterspell (the flat 3.0 `docs/arzakon.strategy` §5 names); and a **Regrowth with Time Walk and a Serra Angel in our own graveyard took the Angel**, 10.00 against 3.00, which is why the loop could never start. On: an extra turn is a draw step (`w_hand`) plus a land drop when a land is held plus the attack the board makes again, read through their blocks and priced by `_face_damage_value` (`AiPlayer._extra_turn_value` — 20.70 for that Time Walk); a FIXED-COUNT wheel is worth the cards it MOVES, `their hand − ours` once the wheel itself has left our hand (CR 608.2m), refused when that is negative and priced at `w_hand` a card (`_wheel_swing`); and a card in our own graveyard is offered to a "return a card" spell at what casting it on THIS board would be worth (`_graveyard_worth`). **THE LOOP IS THOSE THREE AND NOT A FOURTH RULE**: a turn taken with a returner in hand is credited the card it does not spend, which is what puts the Walk ahead of the Regrowth beside it in the same main step — so the Walk is in the graveyard when the Regrowth is cast, and the Regrowth takes it back. Nothing is named: the shapes are "extra turn", "each player discards and draws" (`EffectIntent.wheels`, built the same morning) and "return a card from your graveyard", and a Raise Dead is not a returner because its spec admits creatures alone. `paces_draws`' and `counts_cards`' guards run FIRST and are untouched. Wizard only — the far end of the ramp, and `docs/arzakon.strategy` §4's own item 6 |
| `counts_the_race` | off | off | on | on | reads the race to the empty library in TURNS instead of in cards — the same number only while each side loses one a turn. `paces_draws` counts CARDS and is exactly right under that assumption, because a draw step takes one from each library in turn; a MILL breaks the equality and everything built on it is then wrong by the ratio. Reproduced four times over, and the first is not a mispricing but a decision the pilot had never made: **A MILLSTONE IS NEVER ACTIVATED** — `{2}, {T}: target player mills two cards` falls out of `AiPlayer._ability_option`'s last `else` ("pumps, regeneration, mana, untaps, unknowns") because nothing there has an arm for a payload that is a card off a LIBRARY, and with the opponent's library at **two**, where the activation is the game (CR 704.5b), the option is still `{}` and the Millstone stays untapped. **OUR OWN MILLSTONE MAKES NO DIFFERENCE TO THE PACE** — our library at 12 against their 30 is a race we hold by two turns (theirs is ten turns at three cards a turn, ours is twelve) and `_library_slack` answered `1 << 20`, *"the race is lost already"*, because 12 − 30 is negative. **THEIR MILLSTONE IS PRICED AT 2.60 WHILE IT KILLS US** — with our library at six the one Disenchant took a Jayemdae Tome (4.20) and left the mill running, which is `minds_the_vise`'s malfunction in the other currency. **AND A TIMETWISTER IS CAST INTO A LIBRARY WE HAVE EMPTIED** — ours at 40, theirs at 3 with twenty cards in their graveyard, priced 11.50 and cast, their library back at 21, which is `docs/arzakon.strategy` §4 item 4 word for word. On, all four come out of ONE reading and no card is named: the rate a library loses cards at (`AiPlayer._mill_rate` — the draw step plus every repeatable mill aimed at that seat, a `{T}` ability counted ONCE because the tap is what makes a rate, and an unbounded one refused the way `TOLL_UNKNOWABLE` refuses a count) turns a library into a number of TURNS (`_deck_clock`); the pace counts those turns; a mill is bought at `LETHAL_WORTH` when it decks them and at what a card is worth otherwise, at the mana sink and never in the main phase, which is where a Millstone belongs; taking a mill of THEIRS off the table is worth the cards it hands back (`_mill_relief`, `w_hand` a card rising with the share of the library it takes — `_face_damage_value`'s own sentence about a life total, said about a library); and a wheel that shuffles the GRAVEYARDS back (`EffectIntent.wheel_recycles`, one more fact off the line the wheel count is already read from) is refused when it would lengthen the loser's clock in a race we hold. **THE HORIZON IS THE DECKING CLOCK AND NOTHING ELSE, AND THAT IS THIS ROW'S REAL ANSWER** (§5): a library is the one quantity in this game that never grows back, so a rate taken off it is a fact, while every other rate the engine can see is revisable inside a turn — which is why `RACE_HORIZON` refuses to read a combat clock more than four turns out. The bound here is `PACE_HORIZON`, the libraries' own, and there is no new number anywhere in the row. **AND THE POOL CANNOT MEASURE THE MILL AT ALL**: five decks hold a maindeck Millstone and **not one of them loads**, the three `docs/forge/casting.md` P3 names for its own measurement among them |
| `crack_back_margin` | 0 | 0 | 0 | 0 | how far under our own life total the counter-swing has to reach before `AiPlayer._search_hold_back` is worth running: the gate was `reach >= life`, and it is `reach >= life - crack_back_margin`. The old gate is exact and asks exactly one question — *does this attack LOSE THE GAME to the counter-swing?* — and never the other one, whether it costs us twelve life for four points of damage. **Every preset ships 0, which is that gate unchanged**: the number is here so the Deck Lab can put the question in one command, the way `w_hand` is, and the Lab's answer of 2026-09-10 was NO (§4). Not a difficulty knob, and no rung moves it |
| `develops_late` | off | off | off | off | keeps the hand shut until the attack is over — the whole of `docs/forge/casting.md` P1, and **every preset ships it off, which is the pilot unchanged**. `AiPlayer.act` reaches the main-phase planner in EITHER main step and the first one it reaches is Main 1, so every land, creature, artifact, enchantment, draw spell, discard and tutor this pilot has ever played went down BEFORE its own combat and with it the mana: a Wizard on four Forests with an Ironroot Treefolk in hand plays the land, casts the Treefolk, and stands at their declare-blockers with everything shown and nothing open. On, Main 1 casts only what Forge's `castPermanentInMain1` would — a win, floating mana that would be lost, a haste creature, a non-creature mana source, and what changes THIS combat (a permanent of theirs answered, an aura or a pump on a body of ours, a land that animates itself) — the mana sink waits with the rest, and the land drop is held under Forge's own four guards, the fourth of which is this pilot's own hazard: it sizes its attack and its block by the mana it holds, so a land in hand is a Carrion Ants that reads one point smaller. **THE LAB REFUSED THE RUNG** (§4): nine pairs, eight of them negative, a drift of about a point and a quarter and not one delta clear of its interval — so the field is here for the Deck Lab to ask with, the way `crack_back_margin` is, and no rung moves it |
| `reads_race` | off | off | on | on | reads the two CLOCKS of the race — how many turns we need to take them from their life total to nothing, how many they need to do it to us — and lets the difference move what a VOLUNTARY BLOCK TRADE is allowed to cost. Rung 2 of `AiPlayer._best_block_for` takes a trade nothing forces on it whenever the body it spends is worth no more than `attacker_value + 0.5`, and that is the same margin at twenty life as at four: our Serra Angel trades itself for their Craw Wurm while we are one turn from winning at 20 against their 4, and our Craw Wurm lets an Erhnam Djinn through at 8 life because the Wurm is worth ONE POINT more. On, `AiPlayer._trade_margin` reads P1's own three states — demand a gain (−0.5) when their clock is more than a turn longer than ours, allow a small loss (+1.5) when ours is more than a turn longer than theirs, +0.5 otherwise — with a dead band of a turn between them and `AiPlayer.RACE_HORIZON` (four turns, `PACE_HORIZON`'s sentence said about the red zone) under all of it, because on a 20-20 board two Grizzly Bears against one Hill Giant is five turns against seven and that is a board, not a race. Both clocks are public numbers: the two life totals and the printed power each side could swing with once everything untaps, which is the durable reading the crack-back model has always made of theirs. **P1'S HEADLINE HALF — the ATTACK bar moved by the same difference, plus one for a clock they cannot block — WAS BUILT, MEASURED AND REFUSED** (§4): over the eight starter matchups it moved most it ended 42 games in a win against **170 in a loss**, White Knights vs Black-Red Raiders −3.1, and it is the third brake-or-licence hung on `AiPlayer._combat_tolerance` to be refused this month. The block half alone reads 16 won to 17 lost on those same eight, every delta between −0.2 and +0.2, and that wash is what ships |
| `holds_tricks` | off | off | off | on | keeps the mana for a pump instant open through its own combat, so the body it sent on the strength of the trick can still be saved. The pilot already picks the one extra attacker a Giant Growth makes sound (`AiPlayer._attack_choice`'s rider) and already spends the pump to win that body's block (`_offensive_combat_response`); what sat between them was the first main phase, which knew about neither — `AiPlayer._held_reserve` books removal, a draw and a counterspell and skips a pump outright, so the {G} paid for a Grizzly Bears and the trick was a dead card. Measured over 200 whole games of Big Green against White Knights before a line was written: the pilot reached declare-blockers holding a pump 2,051 times and **could no longer pay for it in 531 of them (25.9%)**. On, `AiPlayer._trick_reserve` puts the pump's cost into that same reserve — but only on our own turn, only before the blocks are in, and only where there IS a bait: a body of ours the pump makes a sound attacker and that is not one without it, which is the rider's own pair of readings asked one phase earlier. An empty board on the other side books nothing, because with nothing to block us every attack is sound already. Its worth is the bait's own worth, so the 1.5x rule that lets a clearly better cast go ahead of a held Counterspell lets one go ahead of this. Wizard only: a trick held through a combat is the last rung of the reactive ramp, and it composes with `holds_instants` rather than widening it. P5's OTHER half — remember the body's id so the response prefers it — DID NOT REPRODUCE and is not built: over those same 200 games the response found two or more of its own attackers that the pump could save in exactly ONE declare-blockers step |
| `holds_the_closer` | off | off | off | off | the finisher of a control deck held until the board is locked — the other half of THE ANGEL (docs/ROADMAP.md, "THE DECK, THIRD PASS" §6), **built whole and refused, every preset shipping its null**. `AiPlayer._holds_the_closer` keeps a creature in hand while four readings all hold: a COUNTER IN HAND (a hand with no answer in it has nothing to wait for — the one line that keeps this off every aggro deck in the pool), `_is_the_closer` (nothing we control is worth as much and our own table is the slower clock), `_out_raced` (the crack-back model's own `_could_attack_next_turn`: their attackers' power against our life over the turns this body needs) and NOT `_board_is_locked` (their attack grounded by a static of ours or eaten by a feeder — the Moat and the Abyss read as shapes, which is the article's "a Moat or an Abyss on the table with a counter in hand" exactly, since the counter is the first reading). `AiPlayer._in_danger` lifts it, which is the whole answer to "but the Angel BLOCKS". THE LAB SAID NO on the very pair it was written for: −0.4 ±2.9 at 2 000 games an arm on the Serra variant against White Knights, 6 games flipped to a win against 14 flipped away — and on the five-deck starter matrix it costs Blue Skies, the ONE starter that holds a counterspell beside its creatures, about fifty games of four thousand, because a flier deck's Mahamoti Djinn is its clock and not its finisher. A capability is as good or better one rung up; this one is not. Not a difficulty knob and no rung moves it: the field is here so the question is one Lab command (`--sweep holds_the_closer=on,off --null off`), the way `crack_back_margin`'s 0 and `develops_late`'s off are |
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

`AiProfile` carries THREE fields that are NOT in the table and not
difficulty knobs at all — `w_hand`, `defender_scale` and `ability_bonus`
(all 2026-09-10). Each is an EVALUATOR NUMBER a seat carries for the
length of a measurement: the weight `Evaluator.position_score` puts on a
card-in-hand lead, and the two `Evaluator.permanent_value` terms combat
note P6 proposed changing — a defensive body's discount per point of
toughness and what an activated or a mana ability adds. Every preset
ships the evaluator's own constant (1.5, 0.0, 0.0) and no rung moves any
of them. They live on the profile because `apply_overrides` is how the
Deck Lab puts a NUMBER on a seat, and because a CONSTANT cannot otherwise
be measured at all: with the number on the profile, "the new evaluator on
one seat against the old on the other, same seeds" is one command instead
of two builds in two worktrees. All three questions were put and all
three answered the same way — §4, "THE HAND'S WEIGHT" and "THE PRICE OF A
BODY THAT CANNOT ATTACK": the incumbent constants stay, and the evidence
is written down.

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
that brings the land back. And it comes back to a block it has already
declared to finish the attacker off — two Wall of Swords together kill
the Serra Angel one of them used to watch walk away — and it reads the
two CLOCKS of the race before it takes a trade nothing forces on it: at
twenty life with the game one turn from over it keeps the Serra Angel
rather than exchanging it for your Craw Wurm, and at eight life with two
turns left it gives up a Craw Wurm worth a point MORE than your Erhnam
Djinn, because a point of value is worth a turn of the clock that is
killing it. Only while a clock is inside four turns: on a 20-20 board
with nothing happening it trades the way it always did.

**Wizard.** No mistakes at all. The Sorcerer's capabilities with twice
the search (3 000), the pickiest panic line (6), the widest counter net
(5.0), the more patient X burn (`holds_x_burn` 5 against the Sorcerer's
3) and four sideboard swaps — and, since 2026-09-10, ONE LAYER OF ITS
OWN: it looks at the position a cast would leave it in before it makes
the cast (`checks_before_casting`). It does not put a Savannah Lions in
front of your untapped Prodigal Sorcerer, or a Llanowar Elves in front of
your Rod of Ruin with `{3}` up, because it projects the board after the
spell resolves and after the answer YOUR TABLE IS ALREADY SHOWING — and
refuses the cast when that position is worse than the one it is in. It
reads your hand for none of this; the answer has to be a permanent you
control and mana you have untapped. When the next attack would kill it
anyway the veto lifts, because a desperate play is allowed to be
desperate. Every OTHER difference between a Wizard and a Sorcerer is a
number, not a layer — which is what "no mistakes" means here: it never
degrades its own choice. The one exception since 2026-09-10 is a second
layer and a small one: it books the mana for the combat trick in its
hand. The pilot has always sent one extra attacker on the strength of a
Giant Growth and always spent the Growth to win that body's block; the
Wizard is the rung that stops the first main phase spending the {G} on a
two-drop first — but only on its own turn, only before your blocks are
in, and only when there is a body the trick is actually FOR.

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

THE COUNTER'S MIND (2026-09-10, `counters_by_shape`) is wave 2's second
row (`docs/forge/casting.md` P2) and the biggest single number this
project has measured for one knob. Reproduced before a line was written,
a Wizard on eight Islands with one Counterspell in hand: a Wrath of God
into four Serra Angels of ours went uncountered at the Sorcerer's 5.5 bar
(the card prices at 5.00), a Fireball for eight at eight life went
uncountered at EVERY rung (2.50), so did a Time Walk (3.00) and a Wheel
of Fortune into a hand of seven against a hand of none (4.00) — and the
same pilot spent the Counterspell on a Serra Angel with a Swords to
Plowshares in hand and a Plains untapped.

Seed 11, 1 000 games an arm, the shipped Wizard on seat B:
**The Deck (playable) vs Mountain Artillery 40.2% → 51.6% (+11.4 ±4.3)**,
with 381 of 1 000 games ending differently and **122 flipped to a win
against 8 flipped away**; **vs Black-Red Raiders 42.7% → 49.9% (+7.2
±4.4)**; vs White Knights 30.5% → 30.4% (−0.1 ±4.0, 113 differ, 2 won and
3 lost). Both clear-of-zero numbers are the burn clause: The Deck holds
five counters and dies to a Fireball or an Earthquake it was pricing at
2.50. Control `big_green` vs `white_knights` 525-475 byte-identical to
its own null in every arm of six runs, and the `off` arm replays the null
in 1 000 of 1 000 games on all four pairs.

THE HALF THE LAB REWROTE. Fed as P2 wrote it, the NEVER clause measured
−1.7 against White Knights with **3 games flipped to a win against 20
flipped away** — the pair P2 names for it. Split by clause: the ALWAYS
half measures EXACTLY ZERO on that pair (White Knights' one Wrath of God
already clears the Wizard's 5.0 bar, and the deck holds no X burn, no
extra turn and no wheel), so all of it was the NEVER half. The cause is
arithmetic and not judgement: The Deck holds four Swords to Plowshares
and four Counterspells, and the rule as written let EVERY White Knights
creature through on the strength of ONE Swords, so the counters were
hoarded against a weenie deck that has nothing better coming. The clause
that fixes it counts the claims already on the table — the answer must be
SPARE, `answers > their creatures in play` — and the same pair then reads
−0.1 ±4.0 with 2 flipped to a win against 3 away. That is a fact about
this pool's decks and not a tuning: a removal spell in hand is spoken for
the moment a body of theirs is standing.

MEASURED AT EVERY RUNG on the pair that moves most, The Deck vs Mountain
Artillery: Apprentice inert (`holds_instants` off — it never casts a
counterspell at all), Magician +0.3 ±0.6 (the matchup itself is 0.2% at
that rung, a floor), Sorcerer 37.0% → 49.0% (**+12.0 ±4.3**), Wizard
+11.4. Monotone, clear of zero at both top rungs and at neither lower
one, so P2's own conditional — *"Wizard; Sorcerer for the ALWAYS half
only if the sweep says so"* — is answered by the number rather than by
the ramp ruling: the whole knob goes at Sorcerer, and the halves were not
split into two knobs because the NEVER half, once narrowed, is a coin
rather than a cost.

P2'S SIXTH ALWAYS CLAUSE WAS NOT BUILT. A control-stealing aura on our
best creature is already answered: `_try_counter` has raised the threat
to the worth of any card of OURS the top spell targets since long before
this knob — a line written for the counter-war — so a Control Magic on a
Serra Angel is priced at the Angel's 10.00 and countered at every rung. A
second copy would fire only where the bar itself refuses. The board is
pinned on both arms in `tests/ai/test_ai_counters_by_shape_2026_09_10.gd`.

CHANNEL-FIREBALL (2026-09-10, `reads_lethal_x`) is wave 2's third row
(`docs/forge/casting.md` P6) and a WASH THAT REMOVES A VISIBLE
MALFUNCTION, on `holds_x_burn`'s and `tutors_for_the_turn`'s precedent.
`MtgGame.pay_life_for_mana` had never been called by any seat in this
AI's life, and the probe shows what that looked like: a Wizard with
Channel and Fireball in hand and three lands out cast Channel into an
empty board against an opponent at twenty, and finished the turn with the
Channel in the graveyard, the Fireball in hand and its own life
untouched. On, the same board holds the Channel; at six life across the
table it casts Channel, pays six and Fireballs for six in one action.

Seed 11, 2 000 games an arm: Summoner (1997, the pool's one playable
Channel deck) vs White Knights 8.8% → 8.7% (−0.1 ±1.8) and vs Big Green
10.8% → 10.9% (+0.2 ±1.9). Across the two, **829 of 4 000 games end
differently and 3 are flipped to a win against 1 flipped away** — a coin
on the totals, with the thrown-away card no longer thrown away. Control
byte-identical in every arm, and the `off` arm replays the null in 4 000
of 4 000.

P6'S CIRCLE-OF-PROTECTION HALF DID NOT REPRODUCE and was not built. With
the 1997 damage-prevention fork on (`RulesOptions.damage_prevention_window`,
`duel_soak.sh --rules fifth`) the shipped pilot already answers a Fireball
for six at six life with the Circle and lives at six, because
`AiPlayer._packet_worth` prices a packet that kills us at `LETHAL_WORTH`;
with the fork off — the built-in default, and what the Deck Lab plays —
there is no window for any seat to act in, which is a ruleset and not an
AI gap. P6's other defender clause, the counter against a lethal X spell,
is one of `counters_by_shape`'s ALWAYS clauses exactly as P6 asks
("counts it as ALWAYS (P2)"), so it is one line under one knob. Both
boards are pinned on both arms in
`tests/ai/test_ai_reads_lethal_x_2026_09_10.gd`.

THE NO-HARM MATRIX for both knobs together, the five starters at 1 000
games a matchup, seed 11, `wizard:counters_by_shape=on,reads_lethal_x=on`
against the same pair pinned off: six of the ten matchups are BYTE-
IDENTICAL and the four that move are the four Blue Skies plays, because
Blue Skies is the only starter with a counterspell in its main deck (two
Counterspells and nothing else). They move by 1, 1, 6 and 2 games in a
thousand — 43.3 → 43.1, 41.6 → 41.7, 59.1 → 58.5, 70.4 → 70.5 — where one
standard deviation at that size is sixteen. No matchup moves against
either knob by more than the run's noise. `reads_lethal_x` cannot fire in
the matrix at all: no starter holds a life-for-mana spell.
THE ANSWER STANDING ON THE TABLE (2026-09-10, `checks_before_casting`)
is a WASH on the win rate that removes a malfunction a human would name
on sight, and it ships on `holds_x_burn`'s and `reads_pumps`' precedent —
with a null this time, which is the difference between this row and the
one below it. Seed 11, 1 000 games an arm, control Big Green vs White
Knights (no repeatable creature-answer on either side), byte-identical to
its own null in every arm of every run.

| pair | null | `on` | delta | games that turned |
| --- | --- | --- | --- | --- |
| White Knights vs Conjurer (4 Prodigal Sorcerer, 4 Rod of Ruin) | 92.8% | 93.0% | +0.2 ±2.3 | 169 — 3 won, 1 lost |
| Big Green vs Conjurer | 91.9% | 92.0% | +0.1 ±2.4 | 203 — 7 won, 6 lost |
| White Knights vs Mountain Artillery (2 Rod of Ruin, 2 Orcish Artillery) | 48.0% | 47.8% | −0.2 ±4.4 | 123 — 6 won, 8 lost |
| The Deck (playable) vs Mountain Artillery | 40.2% | 40.2% | +0.0 ±4.3 | **0 of 1 000** |
| Big Green vs Black-Red Raiders | 46.8% | 46.8% | +0.0 ±4.4 | **0 of 1 000** |

- **THE REPRODUCTION IS THE THIRD BOARD TRIED AND IT IS NOT ARGUABLE.** A
  Savannah Lions, one Plains, and an untapped Prodigal Sorcerer across
  the table: the shipped Wizard casts it, and it is pinged off the
  battlefield before it blocks once. The card is gone, the board is where
  it was, and `_cast_value` read the cast as a gain. A Llanowar Elves
  into a Rod of Ruin with `{3}` up is the same board one card over. The
  first board tried — a Grizzly Bears at four life against two Serra
  Angels — is the pilot playing CORRECTLY, which is exactly why
  `AiPlayer._in_danger` has to lift the veto, and does.
- **495 of the 5 000 games end differently and the flips are 16 to 15**,
  which at that count is a coin held very still. No pair is outside its
  own interval in either direction.
- **TWO OF THE FIVE PAIRS MEASURE 0 GAMES DIFFERENT, and both are pool
  facts.** Black-Red Raiders answers creatures with TERROR and LIGHTNING
  BOLT — cards in a hand, which this reading never looks at — and holds
  no repeatable ability at all; and The Deck's own creatures are Mishra's
  Factories, which are lands until they animate and so are never the
  subject of a "would this body survive its arrival" question. The pairs
  that can see the knob are the ones whose BOARD shows the answer, and in
  this pool that is Conjurer (four Prodigal Sorcerer, four Rod of Ruin)
  and Mountain Artillery.
- **THE NULL IS EXACTLY THE NULL.** The `off` arm replays the null game
  for game in all five runs (0 of 5 000), and the manual's own
  `pays_sacrifices` sweep — Dracur vs Big Green, seed 11 — run on this
  tree with `checks_before_casting=off` pinned on both seats is **byte
  for byte HEAD's own 6 000 games**.
- **P8's OWN NO-HARM TEST IS THE GAME LENGTH — "a veto that lengthens
  games by more than a turn is refusing too much" — and it goes the other
  way.** Mean turns from `games.csv`: 17.54 → 17.51 on White Knights vs
  Conjurer, 19.58 → 19.51 on Big Green vs Conjurer, 20.36 → 20.34 on
  White Knights vs Mountain Artillery. It costs about 14% of the Lab's
  throughput on a board that fires it (85 games/s against 99), which is
  `_in_danger`'s block plan being asked once per answered candidate.
- **WHAT IT IS NOT.** It is not a hand read: the answer has to be a
  permanent they control and mana they have untapped. It is not a game
  copy: the projection is arithmetic on the four quantities
  `position_score` counts. And it is not the whole of casting note P8 —
  the guessed Bolt behind open red mana is gated on a match memory no
  `AiPlayer` carries (§5).

THE PRICE OF A BODY THAT CANNOT ATTACK (2026-09-10, the Forge study's
combat note P6 — two constants, NO KNOB) is a **NO CHANGE with the
evidence attached**, and it is the second time in one day that the
answer to "is this number right" turned out to be "the incumbent stays"
(the first was `w_hand`, above). P6 asks for two terms of
`Evaluator.permanent_value` to move for every rung and every consumer at
once: a defensive body's discount to scale with its toughness, and half a
point per activated or mana ability. Both were built, both were measured,
neither clearly helps — so neither ships, and what ships instead is the
ABILITY TO ASK.

- **IT REPRODUCED TWICE, AND NEITHER BOARD IS ARGUABLE.** With a Wall of
  Stone (7.00) and a Hypnotic Specter (5.50) across the table, a Swords
  to Plowshares takes **the Wall**, and a Control Magic — cast and
  resolved through the real path — **steals the Wall**. A 0/8 that can
  never attack is priced above a 2/2 flier that eats a card a turn, and
  every consumer that has to PICK inherits it. Forge's own table puts the
  same wall at 155 against a vanilla 2/2's 160 — just BELOW the bear
  (`docs/forge/combat.md` §2.1).
- **THE NOTE'S OWN EXAMPLE CANNOT BE PLAYED, AND ITS ARITHMETIC IS ONE
  SUBTRACTION OUT.** P6 names a Terror, and Terror can legally target
  NEITHER of the two cards the note contrasts the Wall with: the Hypnotic
  Specter is black and the White Knight has protection from black. Swords
  to Plowshares is the pool's one "destroy target creature" with no
  colour rider, and it is what the reproduction had to use. And
  `-(toughness * 0.4 + 1.0)` on a Wall of Stone's eight stat points is
  **3.8**, not the 2.8 the note prints — 2.8 is that discount taken off
  the ALREADY discounted 7.0. 3.8 is the number measured, and it is the
  better one: it is where Forge puts the card.
- **`counter_threshold` IS NOT AN INHERITOR, WHATEVER THE NOTE SAYS.**
  `AiPlayer._try_counter` prices the spell on the stack with
  `Evaluator.card_value` — `permanent_value`'s PRINTED twin — so a Wall
  of Stone clears a Wizard's 5.0 bar and a Magician's 7.0 exactly on the
  nose however this change goes. That malfunction is `card_value`'s and
  is written down in §5 rather than fixed here: widening a no-knob
  constant change while measuring it is how a measurement stops meaning
  anything.
- **HOW A CONSTANT WAS MEASURED AT ALL.** A constant has no null, so the
  two numbers are carried by the profile for the length of a run —
  `AiProfile.defender_scale`, `AiProfile.ability_bonus`, fields and not
  knobs, shipping at the evaluator's own constants (0.0 and 0.0), no rung
  moving them — and `Evaluator.permanent_value` takes the optional
  `AiProfile` that `position_score` has taken since `w_hand`, with the
  pilot handing its own profile to all sixty-nine of its calls. That
  turns P6's own Lab prescription — *a third run pairing each preset
  against the OLD evaluator, the null build kept in a worktree* — into
  one command on one seed set: `--sweep defender_scale=0,0.4`.
- **THE DEFENDER DISCOUNT, on the nine pairs that can see it at all** —
  every wall deck the pool can play, four of them as MIRRORS because a
  mirror is the most sensitive instrument a symmetric change has. Seed
  11, 1 000 games an arm, control Big Green vs White Knights:

| pair | null | 0.4 | delta | games that turned |
| --- | --- | --- | --- | --- |
| Priestess mirror (4 Wall of Swords, 4 Wall of Spears, 2 Elder Land Wurm) | 49.9% | 50.0% | +0.1 ±4.4 | 304 — 5 won, 4 lost |
| Alt-A-Kesh mirror (2 Wall of Ice, 2 Wall of Bone, 2 Wall of Air) | 48.4% | 48.2% | −0.2 ±4.4 | 292 — 28 won, 30 lost |
| Fungus Master mirror (2 Wall of Brambles, 2 Wall of Wood, 2 Carnivorous Plant) | 50.1% | 49.3% | −0.8 ±4.4 | 320 — 6 won, 14 lost |
| Elementalist mirror (Wall of Air, Water, Fire, Stone) | 50.4% | 51.0% | +0.6 ±4.4 | 83 — 8 won, 2 lost |
| Priestess vs Black-Red Raiders | 8.3% | 8.5% | +0.2 ±2.4 | 53 — 2 won, 0 lost |
| Black-Red Raiders vs Priestess (the Terror seat) | 89.5% | 89.7% | +0.2 ±2.7 | 75 — 4 won, 2 lost |
| Fungus Master vs Big Green | 10.5% | 11.1% | +0.6 ±2.7 | 127 — 7 won, 1 lost |
| Alt-A-Kesh vs Mountain Artillery | 25.5% | 25.5% | +0.0 ±3.8 | 46 — 3 won, 3 lost |
| Priestess vs Mountain Artillery | 3.1% | 3.3% | +0.2 ±1.6 | 40 — 2 won, 0 lost |

- **1 340 of those 9 000 games end differently and the flips are a
  coin**: 65 won to 56 lost, 0.8 standard errors off even. Not one pair
  is below its own negative interval, which is the no-harm rule kept —
  and not one is above its own positive one either, which is the rule
  that decides this.
- **AND THE FIVE-STARTER GAUNTLET CANNOT SEE IT AT ALL.** Twenty-five
  cards in this pool carry DEFENDER and **not one of them is in any of
  the five shipped decks**, main deck or sideboard, so all twenty ordered
  starter matchups measure **exactly 0 games different — 0 of 20 000**.
  That is a POOL FACT and not a null result: the decks that put the
  question are the 1997 enemies, and Priestess alone fields ten
  defenders.
- **THE ABILITY BONUS, on the WHOLE five-starter gauntlet — all twenty
  ordered matchups, 20 000 games.** It fires on 144 of the pool's 387
  creatures, so unlike the discount it is visible in the shipped decks:
  1 757 of 20 000 games end differently, **91 flipped to a win and 104
  to a loss** (0.47, 0.9 standard errors off a coin, if anything the
  wrong way). No single matchup's delta reaches a third of its own
  ±4.4-point interval; the largest are Blue Skies vs Mountain Artillery
  −1.2 and Big Green vs Mountain Artillery −0.7.
- **EVERY `0` ARM IS BYTE-IDENTICAL TO THE NULL** — 0 of 1 000 games in
  every one of the twenty-nine runs above — which is the determinism
  check and the proof that the plumbing is inert at the shipped value.
  Every control arm likewise: Big Green vs White Knights 525-475 for the
  discount, and for the bonus a control of its own, since Big Green's
  Llanowar Elves can see it — **White Knights vs Blue Skies**, the one
  starter pair where neither deck holds a creature with an activated or a
  mana ability, 273-727 byte-identical in all twelve of its arms.
- **MEASURED AT EVERY PRESET, as the note asks**, on the pair the
  published ladder itself is measured on — the Big Green mirror, the
  pilot's rung against a Wizard. Today's tree reads **15.9 / 37.1 / 44.4
  / 51.3** (the published 15.8 / 37.6 / 45.1 / 51.7 is the 2026-09-06
  sweep, before six knobs), and the discount moves it by **+0.0 at every
  one of the four rungs — 0 games different, four times over**, because
  Big Green holds no defender. The ladder stays monotone because nothing
  touched it.
- **AND THE BASELINE IS THE OTHER HALF OF THE ANSWER.** A constant change
  invalidates the BASELINE, not the knobs, so the manual's own
  `pays_sacrifices` sweep (Dracur vs Big Green, seed 11, 1 000 games an
  arm) was replayed with the candidate constants on BOTH seats. The
  defender discount leaves it **byte for byte where it was — 0 of 6 000
  games different**, 22.6 / 25.4 / 22.6 with the control 525-475, because
  neither deck holds a defender. That is a real point in its favour and
  it is not enough on its own. The ability bonus does NOT: **829 of the
  same 6 000 games end differently**, the published sweep reads 22.7 /
  25.3 / 22.7 instead of 22.6 / 25.4 / 22.6 and the control pair itself
  moves from 525-475 to 523-477 — four Llanowar Elves are enough. A
  constant that moves the number every other knob was measured against,
  in exchange for a coin, is the clearest DO NOT SHIP in this file.
THE WALL THAT BLOCKED ALONE (2026-09-10, `reinforces_blocks`) is a GAIN,
and the deck that says so loudest is the one with eight walls in it. Seed
11, control the ALL-LAND PAIR (forty Forests against forty Mountains —
the only pair a block knob cannot fire on; it decks out at 68 turns and
plays 1000-1000), byte-identical to its own null in every arm of every
run below.

| pair | null | `on` | delta | games that turned |
| --- | --- | --- | --- | --- |
| Priestess (4 Wall of Swords, 4 Wall of Spears) vs Big Green, 2 000 an arm | 6.6% | 10.9% | **+4.4 ±1.7, clear of zero** | 450 of 2 000 — 108 ended, **98 won to 10** |
| Priestess vs Blue Skies | 1.5% | 3.4% | **+2.0 ±1.0, clear of zero** | 185 of 2 000 — 43 ended, **41 won to 2** |
| Priestess vs Black-Red Raiders | 11.6% | 12.2% | +0.6 ±2.0 | 237 of 2 000 — 26 ended, 19 won to 7 |
| Big Green vs White Knights, 2 000 an arm | 53.8% | 54.4% | +0.7 ±3.1 | 120 of 2 000 — 21 ended, 17 won to 4 |
| White Knights vs Big Green, 2 000 an arm | 47.8% | 48.9% | +1.1 ±3.1 | 285 of 2 000 — 36 ended, 29 won to 7 |

- **THE REPRODUCTION IS A LADDER THAT RETURNS TOO EARLY.**
  [method AiPlayer._best_block_for] answers on its first answering rung,
  and rung 1.5 — the free absorb, *a wall soaks the hit at zero cost,
  which is what walls are FOR* — sits above the value trade at rung 2 and
  the gang at rung 3. So a survivor is chosen and the rest of the ladder
  is never walked:

  ```
  their Serra Angel 4/4    ours: Wall of Swords 3/5, Wall of Swords 3/5
      _plan_blocks -> ["Wall of Swords"] ; band kills it: false
        + Wall of Swords -> kills it: true ; that body dies: false

  their Craw Wurm 6/4      ours: Wall of Stone 0/8, Water Elemental 5/4
      _plan_blocks -> ["Wall of Stone"] ; band kills it: false
        + Water Elemental -> kills it: true ; that body dies: true
  ```

  The first of those costs NOTHING — both walls live through the Angel and
  together they deal it exactly four — and the pilot declined it every
  time.
- **THE NOTE'S OWN HEADLINE BOARD DOES NOT ADD UP, and it is written down
  rather than forced.** `docs/forge/combat.md` P4 is titled by "the Wall
  of Stone plus Grizzly Bears kill on a Craw Wurm"; a Wall of Stone is
  0/8 and a Grizzly Bears is 2/2, so that pair deals TWO to a toughness of
  four. The probe above is what the row is really about, and
  `tests/ai/test_ai_reinforces_blocks_2026_09_10.gd` pins the arithmetic
  that refuses the headline on both arms.
- **THE PRICE IS WHAT THE PAIR PUTS AT RISK, and that is a decision the
  note left open.** P4 says *the rung 3 price rule applied to the pair*;
  rung 3 charges both bodies of a gang because in a gang both are at
  risk, and here the survivor the ladder already committed is not. So the
  price is `Evaluator.permanent_value` summed over the bodies of the pair
  the attacker actually KILLS, against the same `attacker_value * 1.5`,
  with Forge's own bound kept on top of it — the body that dies is worth
  strictly less than the attacker it kills
  ([forge] `AiBlockController.java:795-858` at `b09a3d3f`). Charging the
  wall as well would have made the knob nearly inert (a Wall of Stone
  scores 7.00 against a Craw Wurm's 10.00), and it would have bound the
  reading to an evaluator constant the Wave 5 row is about to change.
  Priced this way the rampage is still charged for both bodies, because a
  Craw Giant blocked by two is an 8/6 and the wall dies with the
  reinforcement (CR 702.23).
- **ONE THING IS TIGHTER THAN FORGE.** Forge adds its safe blockers
  whether or not the attacker ends up dead. Nothing is written into the
  plan here unless the band it builds actually kills — a body added for
  nothing is a body exposed to a combat trick for nothing, which is P4's
  own named risk (a Giant Growth on the Wurm takes the Elemental AND the
  wall the ladder had made safe; the test plays that out).
- **NO HARM ACROSS THE WHOLE TWENTY-MATCHUP STARTER MATRIX**, 1 000 games
  an arm, each deck in turn on seat A. Every delta is between −0.6 and
  +1.4, nothing anywhere near the ±4.4 interval that size carries, and
  across the twenty **152 games ended differently — 110 won, 42 lost**.
  Four of the twenty are byte-identical to their own null, and the six
  liveliest all have Big Green in them, which is the pool fact under it:
  a survivor that does not kill is what the knob needs, and in the
  starters that is Big Green's Ironroot Treefolk and Giant Spider. No
  shipped starter holds a WALL at all — for those you go to the 1997
  enemies, and Priestess (eight of them) is the pair above.
- **THE NULL IS EXACTLY THE NULL.** Every sweep above carries an `off`
  arm beside the `on` one, and it is byte-identical to the null in
  **2 000 of 2 000 games on both Big Green pairs and in all four pairs of
  the Priestess run, 8 000 for 8 000** — the knob only ever ADDS a body to
  an attacker the plan already blocked, never moves one and never takes
  one away.

A SUB-LETHAL CRACK-BACK GATE, MEASURED AND REFUSED (2026-09-10,
`crack_back_margin`). `docs/forge/combat.md` P8 asked for the Wizard at
`chump_threshold`'s 6 and said plainly that this is the THIRD attempt at
a question two earlier brakes failed, with *the search prices, it does
not threshold* as the argument and the Lab as the proof. The gate was
built exactly as designed — one line, `reach >= life -
crack_back_margin` — and the Lab said no. **Every preset ships 0, which
is the old gate unchanged.** Seed 11, control the all-land pair, PASS
byte-identical in every arm of every run.

| pair (seat A holds the knob) | null | 6 | 10 | games that turned at 6 |
| --- | --- | --- | --- | --- |
| Big Green vs Mountain Artillery, 2 000 an arm | 54.8% | −0.6 ±3.1 | −1.6 ±3.1 | 406 of 2 000 — 68 ended, 28 won to 40 |
| Mountain Artillery vs Big Green, 2 000 an arm | 48.9% | +0.3 ±3.1 | +2.1 ±3.1 | 674 of 2 000 — 102 ended, 54 won to 48 |
| Big Green vs the other four starters, 1 000 an arm | — | −0.7 / −2.4 / +1.1 / −1.0 | −2.7 / −4.3 / +1.9 / −1.0 | 1 063 of 4 000 — 194 ended, 82 won to 112 |
| White Knights vs the other four starters, 1 000 an arm | — | +1.6 / −0.5 / +1.0 / −0.1 | +0.8 / −0.6 / +1.9 / +0.0 | 654 of 4 000 — 76 ended, 48 won to 28 |
| The Deck (playable) vs Big Green / White Knights / Mountain Artillery | — | **+0.0** | **+0.0** | **0 of 3 000 — the knob cannot fire there at all** |

- **NOT ONE DELTA IN TWENTY ARMS IS CLEAR OF ITS INTERVAL**, and the flips
  are a coin: 212 won to 228 lost at 6, 330 to 360 at 10.
- **WHERE IT MOVES A DECK SYSTEMATICALLY IT MOVES THE CREATURE DECK THE
  WRONG WAY.** Big Green against Blue Skies is −2.4 then −4.3, monotone —
  a green deck that stops attacking into a deck it cannot block anyway.
  That is the pessimism the 2026-09-04 attack audit spent a pass removing
  and the two earlier brakes were rejected for; the search prices it
  rather than thresholding it, and it prices it the same way.
- **THE COST WAS NEVER THE PROBLEM, and P8's budget is met with room.**
  The note's rule is that the per-declaration time in the Lab's timing
  column must not exceed twice today's. On Big Green vs Mountain
  Artillery, 1 000 games at `--jobs 1`, best of two runs: 13.6 s at the
  null, **13.1 s at 6 and 12.5 s at 10** (0.96× and 0.92×), and per TURN
  0.72 / 0.66 / 0.62 ms because the arms play longer games. On Big Green
  vs White Knights: 13.7 / 12.9 / 14.5 s (0.94× and 1.06×). The reason is
  worth keeping: opening the gate does not make ONE declaration dearer —
  `combat_search_nodes` and `CombatSearch.MIN_SLICE` are untouched — it
  runs the same search on more declarations, and the ones it newly runs on
  are the SMALLER boards, which are the cheap ones.
- **THE DECK WHOSE SHAPE FORGE'S SOURCE DESCRIBES CANNOT SEE IT.**
  `notNeededAsBlockers` is about a non-aggro deck declining a sub-lethal
  swing; The Deck is this pool's non-aggro deck and it measures **exactly
  0 games different in 3 000**, because it barely declares an attack the
  search could hold back in the first place. A pool fact, not a null.
- **SO THE KNOB SHIPS AT ITS NULL AND THE FIELD STAYS**, on `w_hand`'s own
  precedent of the same day: the question is now one Deck Lab command
  (`--sweep crack_back_margin=0,6,10 --null 0`) instead of a patch to
  `engine/ai/ai_profile.gd`, and the numbers are here so nobody spends a
  fourth attempt on it. What the question actually needs is a reading of
  the RACE rather than a lower bar — the swing the reproduction refuses is
  a 4/4 flier they cannot block trading four damage for twelve, which is
  `reads_race`'s row (`docs/AI-next-wave.md`, combat P1).
  **AND THAT ROW, BUILT THE SAME DAY, DOES NOT ANSWER IT EITHER** (the
  entry below). P1's race read is a threshold on `AiPlayer._attack_risk`,
  and `_attack_is_reasonable` returns on `risk < 0` — *nothing over there
  may legally block it* — before any threshold is read: the Air Elemental
  is declared on both arms of `reads_race`, at a clock of five against
  their two. The board is pinned that way in
  `tests/ai/test_ai_reads_race_2026_09_10.gd` so the hand-off is not
  believed twice. What that swing actually costs is a TAPPED blocker, and
  nothing on the attack side prices a body for being unavailable on their
  turn except the crack-back search itself — which is where a fourth
  attempt, if anyone makes one, has to live.

WHO IS THE BEATDOWN (2026-09-10, `reads_race`) is a WASH THAT REMOVES A
MALFUNCTION on the block ladder, and a REFUSAL on the attack bar — which
is the larger half of `docs/forge/combat.md` P1 and the third time this
month one number has been asked to carry a brake and has not earned it.
Seed 11, `--profile-a wizard:holds_tricks=off --profile-b
wizard:holds_tricks=off` so the day's other combat row is pinned out of
the reading, control the ALL-LAND PAIR (forty Forests against forty
Mountains — the only pair where both clocks are NEVER), byte-identical to
its own null in every arm of every run below.

| pair (seat A holds the knob) | null | `on` | delta | games that turned |
| --- | --- | --- | --- | --- |
| Big Green vs White Knights, 2 000 an arm | 54.1% | 54.8% | +0.6 ±3.1 | 183 of 2 000 — 32 ended, 22 won to 10 |
| Mountain Artillery vs White Knights, 2 000 an arm | 54.3% | 54.5% | +0.2 ±3.1 | 232 of 2 000 — 35 ended, 20 won to 15 |
| Big Green vs Blue Skies, 2 000 an arm | 40.8% | 40.8% | +0.1 ±3.0 | 31 of 2 000 — 7 ended, 4 won to 3 |
| The Deck (playable) vs Mountain Artillery, 2 000 an arm | 51.3% | 51.3% | +0.0 ±3.1 | **1 of 2 000** |

- **THE REPRODUCTION IS A MARGIN THAT DOES NOT MOVE.** Rung 2 of
  [method AiPlayer._best_block_for] takes a trade nothing forces on it
  whenever the body it spends is worth no more than `attacker_value +
  0.5`, and that is the same number at twenty life as at four:

  ```
  their Craw Wurm 6/4 | our Serra Angel 4/4, us at 20 and them at 4
      our_clock 1, their_clock 4 -- we win next turn
      block: [Serra Angel] -- the body that wins the game, given away

  their Erhnam Djinn 4/5 | our Craw Wurm 6/4, us at 8 and them at 20
      our_clock 4, their_clock 2 -- two turns from dying
      block: [] -- the Wurm is worth ONE POINT more, so it lets it through
  ```

  `AiPlayer._trade_margin` reads P1's own three states — demand a gain
  (−0.5), allow a small loss (+1.5), or leave it alone — off two clocks
  built from public numbers only: the two life totals and the printed
  power each side could swing with once everything untaps
  (`AiPlayer._race_reach`, the durable half `_could_attack_next_turn`
  has always asked of their board, asked of ours as well).
- **THE HORIZON IS THE TREE'S AND NOT THE NOTE'S, and the suite is what
  put it there.** `clamp(their_clock - our_clock, ...)` saturates almost
  at once: on a 20-20 board two Grizzly Bears against one Hill Giant is
  five turns against seven, the maximum reading, for a difference nobody
  will still be in by then. Read that way it refused a Rasputin
  Dreamweaver the 3/3 it was worth trading with — a declaration this
  suite has pinned as right since the 2026-09-04 cohort audit. So nothing
  is read at all unless the FASTER clock is inside `AiPlayer.
  RACE_HORIZON`, four turns: `PACE_HORIZON`'s sentence about the
  libraries — *a game that has not ended by then is not being decided by
  them* — said about the red zone.
- **P1'S HEADLINE HALF WAS BUILT, MEASURED AND REFUSED.** The attack bar
  moved by the same clock difference plus one for a clock they cannot
  block (Forge's `turnsUntilDeathByUnblockable`) was built exactly as the
  note asks — with a floor at zero, because a risk of 0.00 is a FREE
  exchange and a negative appetite refuses attacks that cost nothing, and
  with the horizon above — and four arms over the eight starter matchups
  it moves most, 1 000 games an arm, say no:

  | arm on the eight matchups | worst delta | games that turned | ended, won to lost |
  | --- | --- | --- | --- |
  | both halves | −3.0 | 2 410 | 245 — **59 won to 186** |
  | the attack bar alone | −3.1 | 2 185 | 212 — **42 won to 170** |
  | the attack bar without the evasive clock | −2.3 | 2 266 | 223 — **58 won to 165** |
  | the block margin alone (what ships) | −0.2 | 301 | 33 — 16 won to 17 |

  Dropping the evasive clock changes nothing, so it is the CLAMP itself,
  and what it moves is the deck it should have left alone: White Knights
  against Black-Red Raiders −3.1, Blue Skies against Mountain Artillery
  −1.9. Both are decks of small evasive bodies that were already ahead in
  those matchups, and a race read hands them a licence to swing. P1's own
  Risk paragraph names this exactly — *a tolerance that moves is the
  first thing the two rejected approximations were, and both were
  rejected because they moved the wrong deck* — and the asymmetry it
  offers as the protection is not one. `AiPlayer._combat_tolerance` is
  therefore the arithmetic it always was, and
  `tests/ai/test_ai_reads_race_2026_09_10.gd` pins that on both arms.
- **NO HARM ACROSS THE WHOLE TWENTY-MATCHUP STARTER MATRIX**, 1 000 games
  an arm, each deck in turn on seat A. Every delta is between −0.6 and
  +0.8, well inside the ±4.4 that size carries, and across the twenty
  **111 games ended differently — 63 won, 48 lost**.
- **AND THE POOL BARELY PUTS THE QUESTION, which is a pool fact and not a
  null.** Nothing moves unless a clock is inside four turns, so a pair
  that spends its games on a 20-20 board never reaches the reading: **The
  Deck (playable) against Mountain Artillery — the archetypal
  control-versus-beatdown race, and P1's own named tournament pair —
  measures 1 GAME DIFFERENT IN 2 000**, because a control deck's own
  reach is usually zero and a clock of never is not a race. (P1 names
  `sligh_geeba_1996` for that pair; it cannot be played — nine proxies —
  and Mountain Artillery is the substitute.) The matchups that move are
  the ones with a creature deck on seat A.
- **THE NULL IS EXACTLY THE NULL.** Every sweep carries an `off` arm
  beside its `on` one, byte-identical to the null in **2 000 of 2 000
  games on all four pairs, 8 000 for 8 000**, and the creatureless
  control replays 1000-1000 in every arm of every run.

THE TRICK'S MANA, BOOKED (2026-09-10, `holds_tricks`) is a GAIN, and the
whole of it lives in one deck of the five, which is the pool fact under
it. Seed 11, `--profile-a wizard:reads_race=off --profile-b
wizard:reads_race=off` so the day's other combat row is pinned out of
the reading, control White Knights vs Blue Skies (neither list holds a
pump instant), byte-identical to its own null at 560-1440 in every arm
of every run below.

| pair (seat A holds the knob) | null | `on` | delta | games that turned |
| --- | --- | --- | --- | --- |
| Big Green vs White Knights, 2 000 an arm | 54.1% | 55.4% | +1.3 ±3.1 | 216 of 2 000 — 35 ended, **30 won to 5** |
| Beast Master (4 Giant Growth) vs White Knights, 2 000 an arm | 20.5% | 21.9% | +1.4 ±2.5 | 321 of 2 000 — 46 ended, **37 won to 9** |
| Big Green vs Mountain Artillery, 2 000 an arm | 54.7% | 55.5% | +0.7 ±3.1 | 107 of 2 000 — 25 ended, **20 won to 5** |
| Big Green vs Black-Red Raiders, 2 000 an arm | 48.6% | 49.0% | +0.4 ±3.1 | 109 of 2 000 — 26 ended, 17 won to 9 |

- **NO SINGLE DELTA IS CLEAR OF ITS INTERVAL AND THE FLIPS ARE NOT A
  COIN**, and the second sentence is the finding. Across the four pairs
  the knob ends 132 games differently: **104 won against 28 lost**. The
  arms are the same seeds game for game, so the paired count is the
  sharper instrument than two unpaired Wilson intervals — a coin would
  give 66-66, and 104-28 is nearly seven standard deviations off it. The
  pooled delta over 8 000 games an arm is +0.95 points.
- **THE MALFUNCTION IS MEASURED, not argued.** 200 whole games of Big
  Green against White Knights on the tree before this existed: the pilot
  reached declare-blockers holding a pump instant **2 051 times** and in
  **531 of them (25.9%) could no longer pay for it** — the first main
  phase had spent the mana on a two-drop. `AiPlayer._held_reserve` books
  removal, a draw and a counterspell and skips a pump outright
  (`or intent.pumps`), so a Giant Growth reserved nothing, and the two
  routines that DO know about it — the declaration's pump rider and
  `_offensive_combat_response`'s *win the block* — were being handed an
  empty pool. On the tree that books it the rate is 23.5%, and the
  booking itself fires in **18% of the main-phase passes** where a pump
  is in hand: it is a narrow reservation, not a blanket hold.
- **THE BOOKING IS THE RIDER'S OWN QUESTION ASKED ONE PHASE EARLIER.**
  `AiPlayer._trick_reserve` books only on our own turn, only before the
  blocks are in, and only where there is a BAIT — a body of ours the pump
  makes a sound attacker and that is not one without it, which is exactly
  the pair of readings `_attack_choice`'s rider makes. An empty board on
  the other side books nothing at all, because with nothing to block us
  every attack is sound already; and its worth is the bait's own worth,
  so the 1.5x rule that lets a clearly better cast go ahead of a held
  Counterspell lets one go ahead of this (a Force of Nature is cast, a
  Grizzly Bears waits a turn).
- **P5'S OTHER HALF DID NOT REPRODUCE AND IS NOT BUILT.** The note asks
  for the bait's id to be remembered *"so the offensive response prefers
  it"*. Over those same 200 games the response found two or more of its
  own attackers that the pump could save in **exactly one** declare-
  blockers step — 2 in 200 on the tree that books the mana — because the
  rider sends ONE bait and the cohort's own bodies are the ones it has
  already priced as sound. A tie-break for a tie that happens once in two
  hundred games is not a capability; the row is recorded here so nobody
  spends an afternoon on it.
- **AND THE POOL HOLDS EXACTLY TWO CARDS OF THE SHAPE.** A pump INSTANT
  with a toughness bonus and no self-mode is Giant Growth and
  Righteousness, and of the five shipped starters only Big Green holds
  one (three Giant Growth). So **16 of the 20 starter matchups are
  byte-identical to their own null**, every delta in the four that are
  not is between +0.2 and +1.7, and across the matrix **56 games are won
  against 18 lost**. The 1997 enemies with four apiece — Beast Master,
  Druid, Guardian of the Tusk, Alt-a-Kesh, Fungus Master — are where the
  question is really put, and Beast Master is the pair above.
- **THE NULL IS EXACTLY THE NULL.** Every sweep carries an `off` arm
  beside its `on` one and it is byte-identical to the null in **2 000 of
  2 000 games on all four pairs, 8 000 for 8 000**.

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
the table (Mishra's Factory, Jade Statue), `reads_pumps`' no
activated self-pump on the side OPPOSITE the seat being swept — which in
practice is the same list `pumps_to_attack` already keeps, seventeen
cards, and Big Green vs White Knights holds none of them —
`counters_by_shape`'s no COUNTERSPELL on either side (the reading is
inside `_try_counter`, which no seat without one ever reaches) and
`reads_lethal_x`'s no life-for-mana spell, which in this pool is Channel
and nothing else; Big Green vs White Knights holds neither, and is
525-475 byte-identical to its own null in every arm of eight more runs at
1 000 games and 1075-925 in both at 2 000 — the third
pass's Time Walk
sweep FAILED its first control on exactly that (Blue Skies' Ancestral
Recall), and a failed control makes the deltas beside it no measurement
at all. `CONTRIBUTING.md`
has the rule.

AND A KNOB THAT DEFAULTS ON AT SORCERER IS A KNOB THE NEXT SWEEP HAS TO
PIN. `reads_gaze`, `reads_manlands`, `reads_pumps`, `counters_by_shape`
and `reads_lethal_x` are on at Sorcerer and Wizard — and
`checks_before_casting` is on at the WIZARD — so a measurement of some
OTHER knob taken against a number published before 2026-09-10 must force
all six off on both seats (`--profile-a wizard:reads_gaze=off,`
`reads_manlands=off,reads_pumps=off,counters_by_shape=off,`
`reads_lethal_x=off,checks_before_casting=off`,
and the same for `--profile-b`) or it is measuring several changes at
once. The last two matter more than the first three for anything with a
counterspell in it: `counters_by_shape` moves The Deck against Mountain
Artillery by eleven points. That is how both of those passes proved their own null, and it is
the general rule every knob since `plays_engines` has quietly needed.
PIN. `reads_gaze`, `reads_manlands`, `reads_pumps`,
`reinforces_blocks` and `reads_race` are on at Sorcerer and Wizard — and
`holds_tricks` is on at the WIZARD — so a measurement of some OTHER knob
taken against a number published before 2026-09-10 must force all six off
on both seats (`--profile-a
wizard:reads_gaze=off,reads_manlands=off,reads_pumps=off,reinforces_blocks=off,`
`reads_race=off,holds_tricks=off`,
and the same for `--profile-b`) or it is measuring several changes at
once. The two combat rows of 2026-09-10 pinned each other exactly that
way: the `reads_race` sweeps below are taken with `holds_tricks=off` on
both seats and the `holds_tricks` sweeps with `reads_race=off`. That is how each of those passes proved its own null, and it is
the general rule every knob since `plays_engines` has quietly needed. It
holds inside the SUITE as well and not only in the Lab:
`tests/ai/test_ai_pump_plan_broken_2026_09_10.gd`'s null arm pins
`reinforces_blocks` off beside `pumps_to_attack`, because on that board
the block reinforcement would put a third body on the Hill Giant the
regenerator holds but does not kill — two changes read as one.

AND THE CONTROL FOR A KNOB THAT LIVES IN COMBAT IS THE ALL-LAND PAIR.
`reinforces_blocks` fires wherever a block is declared, and a block is
declared in every game with a creature in it, so the only pair it cannot
fire on is a pair with no creature at all: forty Forests against forty
Mountains, which decks out at 68 turns and plays 1000-1000. It is
byte-identical to its own null in every arm of every run of 2026-09-10
(2 000 games an arm on the Big Green and Priestess sweeps, 1 000 on the
matrix), and it is the same control `crack_back_margin` needs, for the
same reason — the crack-back search reads THEIR creatures and there are
none. `reads_race` takes it too, and for the same reason: the knob reads the
REACH of both boards and moves a rung of the block ladder, so a pair with
a creature in it exercises it in every game, and a creatureless pair is
the only one where both clocks are NEVER and no margin ever moves. Two forty-land lists are not shipped decks and do not need to be;
write them beside the run.
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

DEVELOP AFTER COMBAT, BUILT AND REFUSED (`develops_late`, 2026-09-10).
`docs/forge/casting.md` P1 is the note's own top-ranked "feels like a
competent human" row, and its reproduction is not in doubt: the pilot
reaches its main-phase planner in EITHER main step, the first one it
reaches is Main 1, and so every land, creature, artifact, enchantment,
draw spell, discard and tutor it has ever played went down before its own
combat. A Wizard on four Forests with an Ironroot Treefolk in hand and a
Grizzly Bears on the table played the land, cast the Treefolk, and stood
at their declare-blockers with all of it shown and no mana up. With the
knob on the same board reaches Main 2 with the cast still legal and five
lands open.

THE FIRST SWEEP READ −4.7 ±4.4 AND THE CENSUS SAID WHY, which is the
hazard the row carries and the one worth recording whatever happens to
the knob: a cast held for Main 2 is mana that looks open in between, and
what spends it is THIS PILOT'S OWN ATTACK. Big Green's Llanowar Elves is
tapped for mana in Main 1 at HEAD and therefore never attacks; with the
hold on it stands untapped at the declaration and is sent. Over 200 games
against White Knights, mana sources sent to attack went 1.49 → 3.00 a
game, the pilot cast a whole spell FEWER each game (7.89 → 6.84) and its
creature count at turn six fell 1.60 → 1.39. `AiPlayer._main2_mana_held`
is the answer and it is Forge's own (`reserveManaSourcesForMain2` /
`HELD_MANA_SOURCES_FOR_MAIN2`): the bodies the second main phase's cast
needs are not sent to attack, with the lands asked first so a body is
held only when it is actually needed. With it the same pair reads −0.5
±4.4 and the development is level again — turns ending with a castable
card still in hand 42.1% against 41.8%, sources left open 1.97 against
1.82.

AND WITH THAT FIXED THE ANSWER IS STILL NO. Nine pairs at 1 000 games an
arm, seed 11, the control PASS byte-identical in every one of them:

| pair | null | on | delta |
| --- | --- | --- | --- |
| Big Green vs White Knights | 53.3% | 52.8% | −0.5 ±4.4 |
| The Deck (1996-02) vs Mountain Artillery | 32.2% | 32.0% | −0.2 ±4.1 |
| The Deck (1996-02) vs White Knights | 21.1% | 21.9% | +0.8 ±3.6 |
| Vampire Lord vs Big Green | 26.7% | 24.7% | −2.0 ±3.8 |
| Kzzy'n — The Dragon Lord vs Big Green | 19.2% | 18.4% | −0.8 ±3.4 |
| White Knights vs Big Green | 47.5% | 44.6% | −2.9 ±4.4 |
| Blue Skies vs Big Green | 60.7% | 59.6% | −1.1 ±4.3 |
| Mountain Artillery vs Big Green | 49.9% | 46.8% | −3.1 ±4.4 |
| Black-Red Raiders vs Big Green | 52.1% | 50.3% | −1.8 ±4.4 |

Not one delta is clear of its interval and EIGHT OF NINE ARE NEGATIVE, a
drift of about a point and a quarter against the knob.

THE FLIPS ARE THE INSTRUMENT THAT IS CLEAR, and they are why this is a
refusal rather than a shrug. A timing change touches nearly every game —
8,825 of the 9,000 ended differently under the knob — and of those, 748
CHANGED HANDS: **316 to a win and 432 away**. A fair toss over 748 sits at
374 ± 14, so 316 is four standard deviations out. Eight of the nine pairs
lean the same way, and the paired count says plainly what nine separate
intervals could not afford to: the knob costs games.

That is the same shape `crack_back_margin` was refused for the same day,
and the ladder's own first rule settles it: a capability is monotone, as good or better one
rung up, and a knob that costs the Sorcerer and the Wizard a point is not
that.

NO HALF OF IT ACCOUNTS FOR THE DRIFT, and each was measured on its own
from the Deck Lab. The LAND DROP alone ends 860 of 1 000 games differently
and flips exactly one each way — a wash, and the guards are why: Forge's
`hasRelevantAbsOTB` plays the land whenever a permanent of ours has an
ability the mana could pay for, which in this pool is every firebreather,
every Factory and every Icy. The MANA SINK alone moves nothing on a deck
without one and is load-bearing on a deck with one, because without that
gate the knob defeats itself — with the hand held, `_try_cast_best`
answers "" in Main 1 and a Jayemdae Tome spends on a card the mana the
hold exists to keep open. And pinning `pumps_to_attack` off on both seats
leaves the loss exactly where it was (Mountain Artillery vs Big Green
−2.5 against −3.1, White Knights vs Big Green −2.9 against −2.9), so it
is not the pilot's own open-mana reading either.

WHAT IS LEFT IS THE TIMING ITSELF, and the honest sentence is about this
pool and this Lab rather than about Magic: neither seat reads a hand, a
hand size or an open land as a bluff, so the information the hold buys is
worth nothing here, while the board it prices one phase later is worth
something. The row is therefore not refused for good — it is refused
until there is an opponent that punishes an open board, which is
`holds_tricks` and a hand read (`docs/AI-next-wave.md`). Every preset
ships `false`, the whole mechanism is in the tree behind the field, and
the question is one command:
`--sweep develops_late=on,off --null off`.

THE CONTROL FOR A TIMING KNOB IS THE FORTY-FACTORY PAIR, and P1 was wrong
to say there is no honest one. A timing knob fires on any deck with a
nonland card in hand, a mana sink or a held land drop — so the pair it
cannot fire on must have no spells at all AND no land drop worth holding.
Forty Mishra's Factories against forty Mishra's Factories is that pair:
no nonland card ever reaches the hand, and `hasRelevantAbsOTB` sees the
Factory's own animation and plays the land in Main 1 every time. It is
500-500 and byte-identical to its own null in every arm of all eighteen
sweeps of 2026-09-10, on both trees — the ones taken before
`AiPlayer._main2_mana_held` existed and the ones taken after. Forty Forests against forty Mountains is NOT a control
for this knob — the land-drop half fires on it (harmlessly, as it
happens, which is a pool fact and not a licence).
THE TWO BURN SPELLS THAT KILL TOGETHER (2026-09-10, the CHAIN half of
`holds_x_burn`, `docs/forge/casting.md` P7) is a WASH ON THE WIN RATE
whose flips lean one way on every pair and at both rungs, and a
malfunction removed. It ships as an EXTENSION of the knob it belongs to
rather than as a knob of its own.

- **THE REPRODUCTION IS ONE BOARD AND IT IS NOT ARGUABLE.** A Fireball
  and a Lightning Bolt in hand, four Mountains, a Serra Angel across the
  table, and the shipped Wizard PASSES. `_best_victim` asks
  `EffectIntent.kills` of ONE card at a time and both cards answer
  honestly — three is not four, and three is not four — while three of
  the four mana on the table kill a 4/4 flier outright. On, the Fireball
  is cast for X=1 and the Bolt finishes it in the same main phase.
- **ONE KNOB AND NOT TWO, and the argument is that two would contradict
  each other.** At a reach the hold refuses, a separate chain knob would
  point the same card at the same creature on the same turn — and the
  hold's whole sentence is that a small X burn is the finisher thrown
  away, which is twice as true of a chain, because a chain spends the
  card beside it as well. So the chain is asked UNDER the hold, both are
  lifted together by `_in_danger`, and Forge arranges it the same way:
  its `CHANCE_TO_CHAIN_TWO_DAMAGE_SPELLS` is forced to 100 exactly where
  its hold stops refusing.
- **THE NUMBERS.** Seed 11, 2 000 games an arm, `--null 0`, control Big
  Green vs White Knights byte-identical to its own null (1083-917) in
  every arm of every run. The HEAD column is the same command on the
  same seeds with the CHAIN absent — the hold half alone, which shipped
  earlier the same day — so the two columns differ by the chain and by
  nothing else.

| pair | null | HEAD 3 / 5 | with the chain 3 / 5 | games that turned at 5 |
| --- | --- | --- | --- | --- |
| Mountain Artillery vs Big Green | 49.2% | 49.1 / 49.3 | 49.5 / **50.2** | 606 — 56 won, 37 lost |
| Black-Red Raiders vs Big Green | 52.3% | 52.3 / 51.9 | **53.4** / 53.0 | 453 — 46 won, 32 lost |
| Mountain Artillery vs White Knights | 54.4% | 53.4 / 54.3 | 54.5 / **55.5** | 654 — 81 won, 57 lost |

- **NOT ONE DELTA IS CLEAR OF ITS INTERVAL** (±3.1 at this size) and that
  is said plainly. What is not a coin is the SIGN and the flips: all six
  arms are positive with the chain and three of the six were negative
  without it (−0.1, −0.3 and −0.9), and across the three pairs and both rungs **2 715 of
  12 000 games end differently, 291 flipped to a win against 203 flipped
  away** — where the hold alone, on the same twelve thousand seeds,
  flipped **120 to a win against 144 away** across 1 522. The
  footprint quadruples at the Sorcerer's 3 (83 and 33 games without the
  chain against 357 and 323 with it), which is the chain firing where
  the hold had already let the reach through.
- **THE HOLD IS WHAT THE CHAIN ANSWERS TO, AND THE NUMBERS SHOW IT.** At
  the Wizard's 5 the chain fires only past a reach of five or past turn
  ten; at the Sorcerer's 3 it opens from four lands on. That is why the
  Sorcerer's arm moves LESS here than the Wizard's on two of the three
  pairs: the hold is refusing the small chains, which is what it is for.
- **AND THE KNOB'S CONTROL PAIR CHANGED**, which is a fact about the
  knob's new footprint rather than a failure of the null. The chain's
  second half releases a held burn spell that kills a creature ONLY
  because of the damage already marked on it, and Blue Skies holds three
  Psionic Blasts — a printed four, an instant — so the pair the HOLD was
  measured against now moves seven of two thousand games at 3 and at 5.
  A control for this knob must hold no targeted burn of ANY kind on
  either side, X or printed; Big Green vs White Knights holds none
  (`DeckLab/README.md`).


THE SWEEP THAT WAITS FOR THE COMBAT IT ANSWERS (2026-09-10, the DISK
DEFERRAL and the after-board STATICS, both extensions of `times_sweeps`)
is **the clearest GAIN of the wave on the deck that owns the card**, and
it is one of the few rows where the knob's own delta moves from nothing
to something without a line of the null changing.

- **THE REPRODUCTION, from a headless probe.** A Nevinyrral's Disk and
  two Jayemdae Tomes of ours, three Grizzly Bears of theirs, nothing else
  on the table: `activated Nevinyrral's Disk` in our own first main
  phase, both Tomes in the graveyard, on a turn where waiting costs
  nothing at all. `times_sweeps` had made their combat an EXTRA moment
  and never a preferred one, and `_sweep_value` carries a relief read off
  an attack that has not happened, so the guessed attack paid for the
  early activation.
- **AND THE FIRST CUT LEARNED ITS SECOND HALF FROM A PROBE.** Deferred
  out of our main phase, the Disk simply went off at their UPKEEP
  instead — one step before their draw, before they had cast a card,
  with the attack still unguessed. Their upkeep is one phase EARLIER
  than their combat, not later, so the same wait applies there; their
  END step is not deferred, and that is also why no deferred sweeper can
  be stranded, since a combat that never comes still ends in a mana sink
  that fires it.
- **THE STATICS HALF, and the note's own example is the one card that
  cannot show it.** `_sweep_relief` read its survivors' attack legality
  off the board as it STOOD, so a Moat of ours went on holding the
  ground in a reading of the board the same sweep had just destroyed the
  Moat on: at two life, with a Moat and a Disk against a Serra Angel and
  a regenerating 2/2, the relief answered **1008.00** — four points
  priced as lethal plus `LETHAL_WORTH` for a sweep that "is the out" —
  while the 2/2 walks in for two the moment the Moat is gone. It reads
  **4.00** now. What the row's own wording asks for — *a Moat the Disk
  takes no longer holds the ground* — needs a creature the DISK DID NOT
  KILL, and a Disk kills every creature a Moat was holding: the only
  survivors it leaves are regenerating ones (its printed line carries no
  clause against regeneration, which this engine models), which is the
  board the test pins. Said plainly: the clause is right, and the card
  the note names is the one card that can only show it with a shield up.
- **THE NUMBERS.** Seed 11, 2 000 games an arm, control Blue Skies vs
  Black-Red Raiders — no sweeper on either side — byte-identical to its
  own null in every arm of every run. The HEAD column is the same
  command on the same seeds without the deferral and without the statics
  reading.

| pair | null | HEAD `on` | with the deferral | games that turned |
| --- | --- | --- | --- | --- |
| Witch (4 Nevinyrral's Disk) vs Big Green | 9.5% | 9.8% (+0.4 ±1.8) | **14.4% (+4.9 ±2.0)** | 768 — **111 won, 12 lost** |
| The Deck (playable, 2 Disks) vs Black-Red Raiders | 50.6% | 51.1% (+0.5) | 51.6% (+1.0 ±3.1) | 163 — 23 won, 4 lost |

- **+4.9 ±2.0 IS CLEAR OF ZERO** and the flips are not close: 111 games
  flipped to a win against 12 flipped away, where the same knob without
  the deferral flipped 17 against 10 on the same seeds. The Witch is the
  deck the row is about — four Disks, a board of Clay Statues and
  Skeletons that does not mind losing the table — and holding the Disk
  for the attack is exactly what a player does with it.
- **THE NULL DID NOT MOVE.** The Witch pair's `off` arm is byte-identical
  across the two trees, 2 000 of 2 000, and The Deck pair's is 1 999 of
  2 000. Both control arms PASS inside each tree; between the trees the
  control moves 209 of 2 000 in BOTH arms alike, and that is the CHAIN
  above firing on Blue Skies' Psionic Blasts and Black-Red Raiders'
  Bolts, not this row.


THE NO-HARM MATRIX FOR BOTH ROWS TOGETHER, the five starters at 1 000
games a matchup, seed 11, every knob at its shipped value on both seats —
the tree with the chain and the deferral against the same command on the
tree without them:

| matchup | before | after | games of 1 000 |
| --- | --- | --- | --- |
| Big Green vs Black-Red Raiders | 474 | 460 | −14 |
| Big Green vs Blue Skies | 420 | 419 | −1 |
| Big Green vs Mountain Artillery | 505 | 500 | −5 |
| Big Green vs White Knights | 544 | 544 | 0 |
| Black-Red Raiders vs Blue Skies | 417 | 417 | 0 |
| Black-Red Raiders vs Mountain Artillery | 437 | 435 | −2 |
| Black-Red Raiders vs White Knights | 413 | 416 | +3 |
| Blue Skies vs Mountain Artillery | 580 | 573 | −7 |
| Blue Skies vs White Knights | 705 | 705 | 0 |
| Mountain Artillery vs White Knights | 524 | 531 | +7 |

One standard deviation at that size is sixteen games, so not one matchup
moves by as much as a sigma and the ten together move nineteen games of
ten thousand. The three that do not move at all are the three with
neither a burn spell nor a sweeper in reach of the two rows, and the
largest mover is the pair with three Lightning Bolts and a Fireball on
one side of it — which is the chain, arriving where the sweeps said it
would.


### THE HAND UNDER A SQUEEZE AND THE BOARD UNDER A PRISON (2026-09-10, `minds_the_vise`)

Wave 4's second row (`docs/AI-next-wave.md`, `docs/forge/casting.md` P4,
`docs/arzakon.strategy` §3D and §4 items 2 and 3). Three probes at HEAD,
a Wizard in seat 0:

- **THE DRAW.** Seven cards in hand and a Black Vise across the table —
  three damage at our own upkeep, every upkeep — and `_hand_room` came
  back 2, so two more cards were welcome. At a hand of FIVE, where
  `_draw_need` returns exactly **0.00**, the Jayemdae Tome's tick was
  offered at 2.50 and taken. Half of P4's clause (a) is therefore
  **already built and always was**: `_draw_need` already returns 0.00 at a
  hand of five and six, −3.00 at seven and eight and −4.00 at nine. The
  half that was missing is the ROOM.
- **THE CAST.** A Grizzly Bears out of a hand of six under a Vise priced
  at **4.00** — the printed card, the Vise unread. It reads 4.50 now, and
  a Wheel of Fortune out of a hand of one under the same Vise falls from
  4.00 to **2.50**, because the hand it leaves us with is seven.
- **THE ANSWER.** Their Black Vise and their Jayemdae Tome, one
  Disenchant in hand: `_victim_value` **1.00 against 4.20**, and
  `_best_victim` took the Tome. Their Moat with two Craw Wurms of ours
  standing behind it: **3.20**, and the Disenchant took the Tome again.

**THE NOTE'S RACK CLAUSE IS ONE SUBTRACTION OUT, and checking it is the
reason the reading has a sign in it.** P4 ends
*"The Rack shares (a)-(c) with the threshold at three"*. The Rack's X is
**3 minus** the hand: at seven cards the Vise deals 3 and the Rack deals
0; at nothing the Vise deals 0 and the Rack deals 3. A pilot that
answered a Rack the way it answers a Vise would empty its hand into the
card and take the maximum every upkeep. So the reading is the SLOPE and
not a threshold, the relief is signed (a Grizzly Bears out of the last
card of a hand costs 3.50 under a Rack where it is worth 4.50 under a
Vise) and the room is one-directional — it can refuse a draw and can
never demand one.

**THE POOL, BEFORE THE NUMBERS.** `EffectIntent.hand_toll_of_line` finds
**exactly three cards in the whole pool** — Black Vise, The Rack and
Storm World — and a census test pins that. **Every deck P4 names for its
own measurement is unplayable**: `the_deck_weissman_1995_05` (Chaos Orb),
`sligh_geeba_1996` (9 proxies), `necro_montesanti_1996` (2) and
`ptcs_justice` (8). Thirty-one decks hold a Black Vise and eleven load;
the two with a playset are `sargent_2009_astral_visionary` and the 1997
`swamp_thing`. **The Rack has two decks and neither loads**, and Storm
World is in no deck at all, so the slope is pinned by `tests/ai/` alone
(§5). Seven decks hold a Moat and three load, all of them The Deck.

*Re-counted by the whole-`decks/` census of 2026-09-11 (`DeckLab/README.md`,
"The proxy census"), which moves three of those numbers and confirms the
rest: `necro_montesanti_1996` is down to ONE proxy (Necropotence — Juzám
Djinn shipped after this was written), `ptcs_justice` holds TWELVE, and
the Black Vise decks that load are TWELVE (`noobcon2014_stalin` is the
twelfth). The Rack's two, Storm World's none, and the Moat's seven-and-
three are unchanged.*

**THE NUMBERS.** Seed 11, 1 000 games an arm, control Big Green vs White
Knights — no hand toll and no grounding static on either side —
**533-467, byte-identical to its own null in every arm of every run**.

| pair (seat A is the seat facing the card) | null | `on` | games that turned |
| --- | --- | --- | --- |
| The Deck (Feb 1996) vs Astral Visionary (4 Black Vise) | 45.9% | **52.7% (+6.8 ±4.4)** | 603 — **92 won, 24 lost** |
| Blue Skies vs Swamp Thing (4 Black Vise) | 63.8% | 64.9% (+1.1 ±4.2) | 237 — 30 won, 19 lost |
| White Knights vs Astral Visionary (4 Black Vise) | 95.1% | 95.1% (+0.0 ±1.9) | 90 — 3 won, 3 lost |
| White Knights vs The Deck (2 Moat) | 76.4% | 77.8% (+1.4 ±3.7) | 46 — **15 won, 1 lost** |
| Black-Red Raiders vs The Deck (2 Moat) | 62.9% | 62.9% (+0.0) | **0 — a pool fact** |

**+6.8 ±4.4 IS CLEAR OF ZERO**, and it is the pair the row is about: a
control deck that wants to hold cards, against four Black Vises. The
flips are not close either — 92 to a win against 24 away, where a fair
toss over 116 sits at 58 ± 5.4.

**AND THE PAIR HAS TO BE ONE THE VISE CAN DECIDE.** White Knights against
the same four Vises is 95.1% on both arms and 3 flips each way: a
seventeen-Plains weenie deck empties its hand by turn four whatever it
knows, and it wins that matchup nineteen times in twenty. What the knob
needs on seat A is a deck that WOULD have sat on a full hand — which is
what The Deck is, and why its row is the one that moves.

**THE LAST ROW IS A POOL FACT AND NOT A NULL.** The prison half is read
inside `_victim_value`, which nothing consults unless a card in hand can
point at an artifact or an enchantment — and **Black-Red Raiders holds no
such card at all** (Terror is a creature answer, Bolt and Fireball are
damage). Nothing to answer the Moat with, nothing to price. Put the same
Moat in front of White Knights' two Disenchants and the reading fires:
46 games of a thousand end differently and fifteen of them are won
against one lost.

**NO HARM.** No shipped starter holds a Black Vise, a Rack, a Storm World
or any grounding static, so the knob cannot fire on the starter meta at
all — Big Green against the whole field at 1 000 games a matchup is
**0 of 4 000 games different**, four win rates unmoved to the tenth of a
point, and the control byte-identical beside them.

**AND THE NULL IS PROVED AGAINST HEAD ITSELF, not merely against an
`off` arm.** The manual's own `pays_sacrifices` sweep — Dracur (Spells of
the Ancients) vs Big Green, seed 11, 1 000 games an arm, control Big
Green vs White Knights — was run three ways: on HEAD's own
`engine/ai/{ai_player,ai_profile,effect_intent}.gd`, on this tree with
both knobs pinned off, and on this tree with the presets exactly as they
now ship. **All three `games.csv` files are byte for byte the same 6 000
games** — 22.9% null, control 533-467 in every arm. The third of those is
a fact about the pair as well as about the knobs: neither fires on it,
because Dracur holds no Vise and Big Green's graveyard never offers its
Regrowth an extra turn or a wheel.

### THE OLD LOOPS (2026-09-10, `runs_loops`)

Wave 4's third row (`docs/AI-next-wave.md`, `docs/forge/casting.md` P5,
`docs/arzakon.strategy` §3C and §4 item 6). Three probes at HEAD, all
three at the same seam — `Evaluator.card_value` reads the printed card
and a loop piece prints nothing:

- **A WHEEL OF FORTUNE PRICED AT 4.00 EITHER WAY ROUND.** Our hand seven
  and theirs nothing (a gift of six cards): 4.00. Ours one and theirs
  seven (a gain of six): **4.00, the same number.**
- **TIME WALK PRICED AT 3.00 WITH THREE SERRA ANGELS ON THE TABLE** — an
  extra turn worth twelve damage, a draw and a land drop, priced at a
  Counterspell. It reads **20.70** now.
- **A REGROWTH TAKING THE SERRA ANGEL OVER THE TIME WALK**, 10.00 against
  3.00, every time — which is why §3C's loop could never start.

The order falls out of the pricing rather than out of a fourth rule: a
turn taken with a returner in hand is credited the card it does not spend
(`w_hand`), which puts the Walk at 4.50 against the Regrowth's 3.00 on an
empty board, so the Walk is in the graveyard when the Regrowth is cast.

**THE POOL, AND THE NOTE'S OWN DECKS.** `looping_dolan_1996` and
`churning_dolan_1996`, the two lists P5 names for its measurement, **both
hold a Zuran Orb and cannot be played**. Twenty-nine decks in `decks/`
hold Time Walk, Regrowth and Timetwister together and **nine load** —
and every one of them holds exactly ONE of each, because all three are
restricted. The three-card loop is therefore rare by construction, and
the win rate is the wrong instrument for it on its own; what moves game
to game is the three readings underneath.

**THE NUMBERS.** Seed 11, 1 000 games an arm, control White Knights vs
Mountain Artillery — no wheel, no extra turn, no graveyard return on
either side — **469-531, byte-identical to its own null in every arm of
every run.** (Big Green vs White Knights is NOT a control here: Big
Green's one Regrowth is exactly the ask this knob re-prices.)

| pair | null | `on` | games that turned |
| --- | --- | --- | --- |
| The Deck (Feb 1996) vs Black-Red Raiders | 33.0% | 35.2% (+2.2 ±4.1) | 218 — 41 won, 19 lost |
| The Deck (Feb 1996) vs White Knights | 19.4% | 22.5% (+3.1 ±3.6) | 243 — 44 won, 13 lost |
| Berlin, n00bcon 2016 (The Deck) vs Black-Red Raiders | 26.9% | 29.6% (+2.7 ±3.9) | 206 — 37 won, 10 lost |
| Kiska Ra (Spells of the Ancients) vs Big Green | 24.2% | 25.8% (+1.6 ±3.8) | 167 — 20 won, 4 lost |

**NOT ONE DELTA IS CLEAR OF ITS INTERVAL, AND THAT IS SAID PLAINLY.**
What is not a coin is the paired count, which is the instrument
`holds_x_burn`'s chain half shipped on: **all four arms are positive**,
834 of 4 000 games end differently, and **142 flipped to a win against 46
flipped away**, where a fair toss over 188 sits at 94 ± 6.9. Four pairs,
four positives, four one-sided flip counts, on two different Deck lists
and a 1997 enemy. It ships at the Wizard on that, and on
`holds_x_burn`'s and `reads_pumps`' precedent.

**NO HARM.** Of the five shipped starters only Big Green holds a card the
knob can read at all — its one Regrowth — so Big Green against the whole
field is the only starter question there is, and the answer is **0 of
4 000 games different**: its graveyard never holds an extra turn or a
wheel, so `_graveyard_worth` answers `Evaluator.card_value` on every card
the Regrowth is ever offered. Both of this pass's knobs together move the
starter meta by nothing at all, over 8 000 games.
**THE FINISHER, AND WHAT AN ANGEL IS ACTUALLY WORTH** (2026-09-10,
`checks_before_casting`'s second and third readings; docs/ROADMAP.md,
"THE DECK, THIRD PASS" §6). The third pass left the Angel open with a
census that priced it, and the census reproduces on today's tree —
`decks/variants/the_deck_playable.deck` against the five starters, 150
games a matchup with the mulligan on, seed 4242, Wizard on both seats:
**the wins come at turn 52.1 / 52.6 / 48.8 / 52.8 / 52.2 on the mean**
against the pass's 52.5 / 56.0 / 48.9 / 48.1 / 57.9, 162 of the 358 by
the opponent drawing from an empty library (the pass: 31 of 64), with
The Deck at a mean 23.3 life; **the losses come at 18.1 to 24.2 on the
mean** against 15.6 to 22.1, **191 of the 392 by turn 16** (48.7%, where
the pass read 42 of 86 = 48.8%) and **161 of those 191 were keeps of one
to three lands** (84.3%, where the pass read 35 of 42 = 83.3%). A deck
that cannot close, exactly as described.

THE ANGEL DOES NOT CLOSE, AND THE REASON IS ON ITS OWN SIDE OF THE
TABLE. `decks/variants/the_deck_serra.deck` is the plan's own list — two
Serra Angels for two Mishra's Factories — and on the same command it
measures 47.1% against the base list's 47.7% with **the win arriving
THREE TURNS LATER** (54.4 against 51.6) and 251 of its 353 wins by
library-out where the base had 162 of 358. The Deck plays three copies
of the pool's one feeder, and a feeder eats at EVERY player's upkeep:
fifty games against White Knights at HEAD cast 56 Angels and lost **33
of them at our own upkeep to our own enchantment**, for 29 attacks in
fifty games. The pilot had no reading of it at all — `trusts_abyss` asks
the question of THEIR board, and nothing asked it of ours.

THE ROW SHIPS AS ONE HALF OF TWO, AND THE HALVES WERE MEASURED APART.
Both are `_cast_veto`'s own question — would this cast commit the card
into a table that takes it straight back, or into a race it loses — so
neither is a knob of its own; the appetite rides `checks_before_casting`
and the race is the field `holds_the_closer`, which ships at its null.
The Serra variant against White Knights, 2 000 games an arm, seed 11,
`--mulligan on`, control Big Green vs White Knights (no feeder, no
counterspell) PASSING byte-identical, 1099-901, in every arm of every
run:

| arm | win rate | delta | games that ended differently | changed hands |
| --- | --- | --- | --- | --- |
| the null (both halves off) | 34.2% | — | — | — |
| the APPETITE alone | **35.0%** | +0.8 ±2.9 | 453 of 2 000 | **28 to a win, 12 away** |
| the RACE alone, on top of it | 34.5% | **−0.4 ±2.9** | 61 of 2 000 | 6 to a win, **14 away** |
| both halves | 34.5% | +0.3 ±2.9 | 502 of 2 000 | 32 to a win, 26 away |

On the tree WITHOUT either reading the same sweep reads 34.2% / 34.2%
with **0 games of 2 000 different**: the incumbent one-ply veto never
fires on this pair at all, so the whole footprint above is the finisher's.
Every `off` arm is byte-identical ACROSS the two trees, 2 000 of 2 000 —
the null is the null. What the appetite buys in the game rather than on
the scoreboard: 56 Angels cast and 33 eaten becomes 38 cast and 21 eaten
for the same 28 attacks — eighteen cards not spent on a five-mana body
that, summoning-sick until the upkeep that eats it, could only ever have
blocked once. A fair toss over 40 changed hands sits at 20 ± 3.2, and 28
against 12 is not one.

AND THE RACE HALF IS REFUSED, on its own pair and on the starter matrix
alike. −0.4 with fourteen games lost to six won is not a gain; and the
five-deck matrix at 1 000 games a matchup, the shipped presets on both
seats, says where the cost lands: with the race half on, **six of the ten
matchups do not move a single game** and the four that do are the four
that involve BLUE SKIES — the one starter holding a counterspell beside
its creatures — which gives up about fifty games of four thousand
(419→434 and 417→436 as the column deck, 573→570 and 705→691 as the row
deck). A flier deck's Mahamoti Djinn is its clock, not its finisher, and
the reading cannot tell them apart from the hand alone. With the field at
its null the same matrix is byte-identical to the tree before this row —
**0 games of 10 000, all ten matchups** — because no deck in `decks/`
holds a feeder.

AND THE PLAN'S OWN CLAIM IS HALF TRUE, WHICH IS WORTH WRITING DOWN. "An
Angel shortens the win by ten to twenty turns and changes nothing about
the loss" is right about the shortening and wrong about the price. The
same variant with the three feeders taken OUT for two Moats and a
Factory — a scratch list, not shipped — wins at **turn 35.0 on the mean,
16.6 turns sooner**, and only 31 of its 266 wins are by library-out
against the base's 162 of 358. Its win RATE is **35.5% against 47.7%**.
The Angel closes when the Abyss leaves, and the Abyss is worth about
twelve points of win rate. That is why Weissman's own lists carry Moats
where they carry Angels, and it is a DECK question rather than an AI
one.

**AND THE DECK QUESTION IS SETTLED (2026-09-11): THE VARIANT IS A STUDY
LIST, AND THE ANGEL SHAPE THAT WORKS ALREADY SHIPS.** The row above left
one thing to a human — a variant in the tree that measured worse than the
list it varies and slower than it too — and the first thing to test was
whether its census had been taken before `_fed_on_arrival` closed the
malfunction. It was re-run at HEAD on the same command (the five starters,
150 games a matchup, seed 4242, Wizard both seats, `--mulligan on`,
`--no-elo`), with a scratch harness replaying the Lab's own seeds game for
game so the win TURN and the win REASON could be read — the Lab's
`games.csv` carries neither, and the harness's win rates are the Lab
report's to the game (381-369 and 370-380).

| list, 150 × 5 at HEAD | win rate | win turn | by library-out | wins by damage, and when |
| --- | --- | --- | --- | --- |
| `the_deck_playable.deck` | **50.8%** (381-369) | 50.3 | 161 of 381 (42%) | 220, at 46.6 |
| `the_deck_serra.deck` | **49.3%** (370-380) | **52.9** | 244 of 370 (66%) | 126, at **38.4** |
| `the_deck_weissman_1994_95_winter.deck` | **48.8%** (366-384) | **29.3** | 11 of 366 (3%) | 355, at 28.5 |
| scratch: the shell with 2 Moats for the 3 feeders | 36.4% (273-477) | 33.5 | 23 of 273 (8%) | 250, at 31.9 |
| scratch: the same with ONE Abyss left | 40.7% (305-445) | 47.5 | 176 of 305 (58%) | 129, at 28.5 |

THE FIX DID NOT RESCUE THE VARIANT AND DID NOT HAVE TO. Game for game on
the same seeds the base list and the Serra variant differ in 563 of 750
games and **173 change hands — 81 to a win for the Angels against 92
away**, where a fair toss over 173 sits at 86.5 ±6.6: the win rate is a
WASH, and the two and a half turns are not. The appetite reading is live
and visible in the same run — **533 Angels cast in 750 games and 210 still
eaten at our own upkeep**, because the reading refuses a cast into a
feeder ALREADY on the table and cannot refuse one drawn or replayed after
the body lands, and `_in_danger` lifts it when the body has to block — so
what the census reads now is not
the malfunction but the deck: the Angel closes eight turns faster than the
Factory when it lands (38.4 against 46.6) and lands too seldom to matter,
and the list spends the difference decking the opponent instead.

THE ITEM'S OWN BAND IS REACHED BY THE LIST THE ITEM NAMED, WHICH ALREADY
SHIPS. `decks/community/the_deck_weissman_1994_95_winter.deck` — four
Serra Angels, two Moats, no Abyss, no Factory — wins **twenty-one turns
sooner** than the playable list with 97% of its wins by damage, for two
points of win rate that the interval does not separate (±3.6 on each), and
its losses are where they were (19.8 on the mean against 19.3). "An Angel
shortens the win by ten to twenty turns and changes nothing about the
loss" is TRUE of that list and false of a half conversion — which is what
the two scratch rows above are, and what yesterday's "the Abyss is worth
twelve points" was actually pricing.

SO NOTHING WAS ADDED AND NOTHING WAS REMOVED, and the reason the variant
stays is measurement rather than play. It is **the only playable deck in
`decks/` that holds a feeder and a creature at once**, so it is the only
list on which this knob's appetite reading and the refused field
`holds_the_closer` can fire at all: `the_deck_playable` holds the feeder
and no creature, two lists hold The Abyss in a sideboard that a free-play
run never swaps in, and the seven others that hold it maindeck name a card
the pool does not implement and cannot be dealt. Its header now says so,
and says what it costs; `VARIANT_TOTAL` stays at 2 and `SHIPPED_FILES` at
319.

**WHETHER A CONTROL DECK'S KEEP SHOULD WANT THREE: NO** (2026-09-10, the
Angel's second half, wave 1's row 2 continued). The census above says 35
of the 42 short losses were keeps of one to three lands, and the question
that follows is whether `AiMulligan`'s keep band should ask for three
mana instead of two. It was MEASURED before anything was built, at the
size the mulligan row asked for — `the_deck_weissman_1994_95_winter` vs
`white_knights`, **4 000 games an arm**, seed 11, `--mulligan on`, the
floor put on seat A only through a scratch field the Lab could sweep:
**43.4% at the shipped floor, 42.4% at a floor of three (−1.0 ±2.2)**,
with 1 497 of the 4 000 games ending differently and **565 changing
hands, 263 to a win against 302 away** where a fair toss sits at 282 ±
12. The control (two all-land decks, where every hand goes back to the
same four cards under either floor) is 2000-2000 byte-identical in every
arm, 4 000 of 4 000.

WHY IT LOSES IS IN THE HANDS, and the hand census is the argument rather
than the win rate: a floor of three nearly TRIPLES the mulligan rate —
sevens thrown back over 4 000 hands go 16.6% → 46.0% on the Winter list,
8.3% → 27.8% on the playable one, 11.6% → 35.8% on White Knights and
16.6% → 47.3% on Big Green — and the mean kept hand falls from 6.78 to
6.08 cards. The census of the games says the trade is not there to be
had: The Deck's sevens KEPT on exactly two mana win 44.6% of 130 games,
and the whole pool of sixes that would replace them wins 45.5% of 55. A
point of win rate for seven tenths of a card is the wrong way round.
**So `AiMulligan` is untouched — no floor, no field, no knob** — and the
short losses stay what the census called them: hands that had the mana
and lost anyway.

### THE DECKING COUNT (2026-09-10, `counts_the_race`)

Wave 4's last row and the plan's (`docs/AI-next-wave.md`,
`docs/forge/casting.md` P3, `docs/arzakon.strategy` §4 item 4).
`paces_draws` has read the two libraries as a race since 2026-09-07 and it
counts CARDS, which is exactly right while each side loses one a turn — a
draw step takes one from each library in turn, so a lead in cards IS a
lead in turns. A MILL breaks that equality, and every reading built on it
is then wrong by the ratio. Four probes at HEAD, and the first is not a
mispricing at all:

- **A MILLSTONE IS NEVER ACTIVATED.** `{2}, {T}: target player mills two
  cards` reaches `AiPlayer._ability_option` and falls out of its last
  `else` — *"pumps, regeneration, mana, untaps, unknowns: not here"* —
  because nothing there has an arm for a payload that is a card off a
  LIBRARY. With three Islands untapped and the opponent's library at
  **two**, where the activation is the game (CR 704.5b), the option is
  still `{}` and `_try_activate` returns `''`. **Not one card had ever
  been milled in this AI's life.**
- **OUR OWN MILLSTONE MAKES NO DIFFERENCE TO THE PACE.** Our library at
  12 against their 30, a Millstone of ours on the table: their clock is
  **ten** turns and ours is **twelve**, a race we hold by two — and
  `_library_slack` answered **`1 << 20`**, "the race is lost already,
  draw for value", because 12 − 30 is negative.
- **THEIR MILLSTONE IS PRICED AT 2.60 WHILE IT KILLS US.** Our library at
  six, their Millstone and their Jayemdae Tome across the table, one
  Disenchant in hand: `_victim_value` read **2.60** against the Tome's
  **4.20** and `_best_victim` took the Tome. It is `minds_the_vise`'s
  malfunction one row over, in the other currency.
- **A TIMETWISTER IS CAST INTO A LIBRARY WE HAVE EMPTIED.** Ours at 40,
  theirs at **3** with twenty cards in their graveyard: `_size_and_aim`
  priced it **11.50** and cast it, and their library came back at 21.
  That is `docs/arzakon.strategy` §4 item 4 word for word.

On, the four are one reading and nothing is named. `AiPlayer._mill_rate`
is the cards a turn a library loses to repeatable mills — a `{T}` ability
counted ONCE, because the tap is what makes a rate, and an unbounded one
refused the way `EffectIntent.TOLL_UNKNOWABLE` refuses a count it cannot
do. `_deck_clock` is the library over that rate plus its draw step, in
turns. `_library_slack` counts those turns instead of cards, and with no
mill on either battlefield it is the integer expression it has been since
2026-09-07. `_ability_option` buys a mill at `LETHAL_WORTH` when it decks
them and at what a card is worth otherwise — `w_hand` a card, rising with
the share of the library it takes, which is `_face_damage_value`'s own
sentence about a life total said about a library — at the mana sink and
never in the main phase, which is where a Millstone belongs.
`_mill_relief` prices taking one of THEIRS off the table by the cards it
hands us back, and by the game when one more activation would empty us.
And `_hands_back_the_race` refuses a wheel that shuffles the GRAVEYARDS
back (`EffectIntent.wheel_recycles`, one more fact off the line the wheel
count is already read from) when it would lengthen the loser's clock in a
race we hold — one-directional, silent on a race we are LOSING, where a
Timetwister is the card that saves us.

**THE HORIZON IS THE DECKING CLOCK AND NOTHING ELSE.** Four rows of the
same day asked this one for a game clock; §5 has the ruling and its
reasons in full. In one line: a library is the only quantity in this game
that never grows back, so turns counted off it are a fact and turns
counted off anything else are a guess — and the bound is `PACE_HORIZON`,
the libraries' own, with no new constant anywhere in the row.

**THE POOL, AND WHY THE HEADLINE CANNOT BE MEASURED.** Millstone is the
only card in this pool with a `MillEffect` at all, five decks play one in
the maindeck, and **not one of the five loads** — `ptcs_regnier`,
`ptcs_loconto` and `wc1995_redi`, the three `docs/forge/casting.md` P3
names for its own measurement, among them. So the whole mill half is
pinned by `tests/ai/test_ai_counts_the_race_2026_09_10.gd` and by nothing
else, exactly as The Rack's slope is. What the Lab CAN put the question
to is the wheel half, and only in the games P3 itself prescribes: life out
of the picture, two long control decks, the decking race the thing that
ends it.

**THE NUMBERS.** Seed 11, 2 000 games an arm, `--lives 400,400`, control
Big Green vs White Knights — no mill and no wheel on either side —
**1058-942, byte-identical to its own null in every arm of both sweeps,
2 000 of 2 000 games**, and the `off` arm replays the null game for game
in all four pairs.

| pair (seat A) | null | `on` | games that turned |
| --- | --- | --- | --- |
| The Deck (Weissman, Feb 1996) vs The Deck (playable) | 60.0% | 61.4% (+1.4 ±3.0) | 282 — 31 won, 3 lost |
| The Deck (Weissman, Fall 1994) vs The Deck (playable) | 79.5% | 80.3% (+0.8 ±2.5) | 328 — 21 won, 4 lost |
| The Deck (Weissman, Fall 1994) vs The Deck (Weissman, Summer 1996) | 86.0% | 86.6% (+0.6 ±2.1) | 382 — 34 won, 21 lost |
| The Deck (Weissman, Fall 1994) vs Kiska Ra (Spells of the Ancients) | 94.9% | 95.0% (+0.1 ±1.4) | 92 — 2 won, 0 lost |

**NOT ONE DELTA IS CLEAR OF ITS INTERVAL, AND THAT IS SAID PLAINLY** —
the last pair is at 94.9% and has almost nowhere to move. What is not a
coin is the paired count, the instrument `runs_loops` and
`holds_x_burn`'s chain half shipped on: **all four arms are positive**,
1 084 of 8 000 games end differently, and **88 flipped to a win against 28
flipped away**, where a fair toss over 116 sits at 58 ± 5.4. It is a WASH
ON THE WIN RATE that removes a visible malfunction — a Millstone that had
never been activated once, and a Timetwister handing back a win three
turns away — and it ships as that.

**NO HARM.** Big Green against the whole starter field, 1 000 games a
pair: **0 of 4 000 games different**, and 0 of the control's 1 000 beside
them. No shipped starter holds a mill or a wheel, so the starter meta
cannot move and does not.

## 5. Where the ladder still ends short

- **THE POOL'S OWN CEILING, COUNTED ONCE (2026-09-11).** Half the entries
  below and half of §4's measurement notes end the same way — *the deck
  the note names cannot be played* — so the whole of `decks/` was walked
  rather than one deck at a time (`DeckLab/README.md`, "The proxy
  census"). **101 of 319 deck files are proxy-blocked, over 212 distinct
  card names, and NOT ONE of those 212 is a card this pool is meant to
  hold**: 211 were first printed in Fallen Empires through Weatherlight
  (1994-97), sets outside the eight — Ice Age alone accounts for 65 of
  them — and the 212th is Chaos Orb, excluded by name because a dexterity
  card has no honest software form. Twenty of the twenty-four decks that
  are ONE name away are one Chaos Orb away. **So the bound on
  `counts_the_race`'s mill, on `minds_the_vise`'s Rack slope, on
  `reads_pumps`' fourteen blind matchups and on every "the pair cannot be
  played" line in this file is STRUCTURAL, not a backlog** — the eight
  sets hold 897 distinct names and `cards/sets/` holds 897 files, so there
  is no unwritten in-scope card to write and nothing that could be added
  there would lift any of them. The right reading of those notes is that
  `tests/ai/` is the instrument for those knobs and always will be. What
  WOULD lift them is a set the pool does not cover, which is a scope
  decision and not an AI one.
- `counter_threshold` is an absolute evaluator number, so a Wizard on a
  deck with pain lands spends life on counters a Sorcerer keeps; that is
  the open knob question above, to be instrumented before it is touched.
- `Evaluator.card_value` is `permanent_value`'s PRINTED twin and carries
  none of the profile numbers the battlefield price carries, so the two
  can disagree about the same card and today they would: a Wall of Stone
  is 7.0 to a discard pick, to a tutor's fallback, to the sideboard's
  weighting and — the one that shows at the table — to
  `AiPlayer._try_counter`'s bar, which prices the spell on the stack with
  `card_value` and nothing else. A MAGICIAN SPENDS A COUNTERSPELL ON A
  WALL OF STONE (7.0 against its own 7.0 threshold) AND LETS A HYPNOTIC
  SPECTER (5.5) RESOLVE. Combat note P6 names `counter_threshold` among
  the consumers that inherit `permanent_value`'s ranking and it is not
  one of them; the malfunction is real and it is `card_value`'s. Not
  fixed on 2026-09-10 because P6's own edit was under measurement that
  day and widening a no-knob constant change while measuring it is how a
  measurement stops meaning anything (§4, "THE PRICE OF A BODY THAT
  CANNOT ATTACK").
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
- `checks_before_casting` reads only the answer the table is ALREADY
  SHOWING. Casting note P8 asks for a second clause — a guessed
  Lightning Bolt behind open red mana, gated on `AiMatchMemory.copies_seen`
  having shown that colour deals damage — and it is not built, for a
  structural reason rather than a preference: `AiMatchMemory` belongs to
  the SIDEBOARD, no `AiPlayer` carries one, and free play (which is every
  game the Deck Lab measures) has none at all, so the clause would have
  been inert in the very runs that measure it. Giving the pilot a match
  memory is its own piece of work and it is not this one. Two smaller
  things are open at the site: the projection cannot count the SWING their
  creatures make next turn, because the body it is asking about is not on
  the table to block it, and it does not know that tapping out costs us
  the Fog we were holding — `position_score` counts lands and not mana.
  (`docs/forge/combat.md` P4) rather than this knob's. **STILL OPEN after
  `reinforces_blocks` landed (2026-09-10):** that knob is a SECOND PASS
  over a block already declared and never a first one, so it can add a
  body to a wall that blocked — it cannot put a body in front of an
  attacker the ladder declined altogether. The missing rung is still
  missing.
- `reinforces_blocks` inherits `reads_pumps`' asymmetry and it shows on
  its own safe pass. The gap the reinforcement has to CLOSE is read at the
  size their open mana makes the attacker (`_band_kills` asks
  `_pump_reach`), so a Frozen Shade behind three Swamps is a 3/4 and the
  Grizzly Bears alone is no answer to it. Whether the body we ADD survives
  is read at the PRINTED attacker, because their pump killing a body of
  ours is deliberately not read on defence — so a Bears added against that
  Shade counts as a free, safe reinforcement and may in truth die to the
  breath. That is the same sentence the 2026-09-10 cut is built on (a
  blocker of ours that dies to their breath has SPENT their mana), read
  one rung further down; it is pinned in
  `tests/ai/test_ai_reinforces_blocks_2026_09_10.gd` rather than left to
  be rediscovered. The consequence worth naming: a body the safe pass
  reads as free is charged nothing by the price rule, so the `* 1.5` bound
  never sees it.
- `reinforces_blocks` prices the bodies that DIE and not the whole pair,
  which means it does not charge for the block's second-order cost — a
  body put on an attacker is a body that cannot block the NEXT attacker,
  and the pass runs after every attacker has been answered, so the ladder
  has already had first pick. Forge has the same ordering. What it also
  does not price is the wall's own permanence: a Wall of Stone that stops
  a Craw Wurm every turn for the rest of the game is worth more than the
  one kill the reinforcement buys, and the reading has no horizon to say
  so (`counts_the_race`'s row, `docs/AI-next-wave.md` wave 4). The
  measurement is what says it comes out ahead anyway.
- `develops_late` ships at the null on every rung (§4), so three things
  it exposed are open rather than fixed. THE MAIN-2 RESERVE BOOKS ONE
  CARD: `AiPlayer._main2_reserve` answers with the single most valuable
  sorcery-speed cast the open mana could make and a bar of 3.0, so a
  second cheap cast — a Llanowar Elves at 1.5 — is not booked and the
  body that makes its mana is still sent to attack. THE COMBAT TRICKS ARE
  NOT BOOKED AT ALL: only the firebreathing path reaches that reserve
  (through `AiPlayer._pump_reserve`), and `_defensive_combat_response`,
  `_offensive_combat_response`, the shield and the window caster all spend
  against `_held_reserve` alone — measured at 1.00 responses a game
  against 1.03, so it is not what refused the row, but it is the seam
  P1's own risk clause names. AND A LORD IS NOT READ: Crusade's
  `PlayMain1:TRUE` is a card script in Forge and a STATIC ability here, so
  `EffectIntent` sees no target and no pump, and a lord held to Main 2
  pumps nothing this turn. None of the three is worth building while the
  knob is off.
- `holds_x_burn` is the HOLD half of its row only. The CHAIN — two burn
- ~~`holds_x_burn` is the HOLD half of its row only. The CHAIN — two burn
  spells that kill together, the first sized for its share and the
  second's cost booked out of the reserve — is wave 3's.~~ **Closed
  2026-09-10 — BUILT, as an EXTENSION of the knob rather than a knob of
  its own** (§2, §4). What is left open under it is named rather than
  hidden. The chain's FIRST half must be the X spell: a pair of PRINTED
  shots (two Lightning Bolts on a Craw Wurm) is a chain this pool can
  make and this reading cannot, because both cards are held instants and
  nothing in the main phase would release the first of them — the
  release (`AiPlayer._finishes_damaged`) is a reading of damage ALREADY
  marked, and the first shot of a two-Bolt chain has nothing to borrow
  from. Two X spells are refused on arithmetic and that one is correct
  and closed: each X spell pays a coloured pip of overhead, so one of
  them reaches further alone than two do. And the chain prices the
  victim and never the CARDS: spending a Fireball and a Bolt on one
  Serra Angel is two cards for one, which the reading says nothing about
  — the hold above it is what keeps that from being cheap, and past turn
  ten nothing does.
- `AiPlayer._in_danger` reads the board's clock and nothing else: burn in
  their hand, an upkeep price we cannot pay, a Vise ticking — none of
  those lift the hold, and the first of them is a hand read this AI does
  not do at all.
- ~~The mana planner does not know that a Mishra's Factory, a Library or a
  Strip Mine is worth more untapped than a Forest: among equal sources
  it takes them in battlefield order, so a second animation can be paid
  by tapping the first animated body when the Factories come before the
  plain lands.~~ **Closed 2026-09-11 — FIXED in the planner itself
  (`ManaPlanner.holds_untapped`, the last key of
  `cheapest_source_first`), an engine change with no knob and therefore
  no null.** `animates_to_attack` excludes the body it has already
  animated; what was open was the tie-break under it, and it is now the
  one question the sort had never answered. THE READING IS TWO SHAPES,
  both printed on the permanent: an activated ability whose cost includes
  {T}, which is the same tap the mana ability wants (CR 107.5) — in this
  pool SIXTEEN cards, from Library of Alexandria's draw and Strip Mine's
  land destruction to a Desert's shot at an attacker, a Pendelhaven's
  pump and the five mana batteries' charge counter — and an
  ability that ANIMATES the source, because a tapped creature can neither
  attack (CR 508.1a) nor block (CR 509.1a) and Mishra's Factory's
  animation costs {1} and no tap at all, so the first shape alone would
  have priced the Factory for its Assembly-Worker pump and read a manland
  printed without one as a plain land. WHAT IS LEFT OPEN UNDER IT is
  named rather than folded in. THE DUAL STILL WINS: the tie-break is the
  LAST key, below `source_options`, so a Library of Alexandria beside a
  LONE Tundra is still spent first — the dual's flexibility is an
  ordering the planner already had and moving it is a second change with
  a second measurement. A MANA CREATURE IS NOT READ HERE: a Llanowar
  Elves is worth something untapped too, and that is the AI's combat
  reading (`_attackers_excluded`, `_main2_mana_held`) rather than the
  planner's sort — a planner that pushed every mana creature behind every
  land would be re-deciding combat from inside a comparator. AND
  PAYABILITY IS NOT READ: whether the foreclosed ability could be paid
  for depends on the rest of the turn, while the source list is built
  once per decision off the battlefield alone.
  WHAT IT MEASURED AS, and the honest word for it is a WASH. Dracur
  (Spells of the Ancients) vs Big Green at every rung: 33.5 → 33.5,
  25.8 → 26.0, 23.6 → 23.6, 22.3 → 22.2; The Deck (playable) vs
  Black-Red Raiders — the pair that holds all three of the cards the row
  names — 10.0 → 10.0, 2.3 → 2.1, 44.0 → 44.2, 51.8 → 51.7. At 4 000
  games a side, 52.7% → 52.8% and 22.2% → 22.1%. The paired count is a
  coin as well and that is the difference from `counts_the_race`, which
  shipped a wash on 88 flips for against 28 away: here **20 000 games
  tree against tree end 3 558 differently, 85 flipped to a win against 77
  away**, where a fair toss over 162 sits at 81 ± 6.4.
  WHAT IS NOT A COIN IS THE OPTION COUNT, and it moves one way only.
  Counted off the engine's own duel log over 200 games a rung: The Deck's
  Library draw activated 293 → 319 at the Wizard and 246 → 269 at the
  Sorcerer, its Factory animated 1 203 → 1 264 and attacking 963 → 998,
  Dracur's Strip Mine 51 → 54, Arzakon's Factory attacking 36 → 39. Not
  one counter falls, and the pilot's games come in about a turn shorter
  (36.6 → 35.5 mean turns on The Deck pair). Nothing measurable is worse:
  the control pair Big Green vs White Knights is byte-identical between
  the trees at every rung, no pre-existing test moved, and the whole
  five-starter matrix is 0 of 2 000 games different.
  SO IT SHIPS ON AN ARGUMENT THAT IS NOT THE WIN RATE, and the argument
  is the one the evaluator constants of 2026-09-10 did not have. That row
  proposed an INVENTED NUMBER against an incumbent and the measurement
  had to carry the whole case; this row invents no constant at all — the
  reading is a count of printed abilities — and there was no incumbent to
  defend, because battlefield order is the order of an array rather than
  an answer anybody chose. And the seat that decides it is the HUMAN one:
  `DuelScreen._auto_tap_for_pending` plans through this same file, so a
  player's double-click was spending their Library of Alexandria on a
  generic pip a basic could have paid, which is a defect no difficulty
  knob can gate — and the 1997 auto-tapper's own default flags
  (`AUTOTAP_NO_NONBASIC_LANDS`) say the original would not have touched
  the land at all.
  THE POOL FACT WORTH KEEPING: not one of the five shipped starters holds
  any of the sixteen cards this reading can find, so the starter
  gauntlet is not an instrument for it; the decks that put the question
  are The Deck's lists, the 1997 enemies (seventeen of the lists under
  `decks/1997/` hold a Desert, thirteen a Mishra's Factory, five a Strip
  Mine, and both Arzakons play all five mana batteries) and the
  tournament and community lists, 104 of which hold a Factory, a Strip
  Mine or a Library.
- ~~And no rung animates a Factory to BLOCK on the opponent's
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
- ~~`times_sweeps` holds an activated sweeper only from the moment it is
  offered in the opponent's combat; a Disk that is worth firing at its
  own main phase still fires there, when waiting for their attack would
  cost nothing but a Disenchant's window. The relief's "after" board is
  the sweep's survivors under the statics as they stand — a Moat the
  Disk takes with the board still holds the ground creatures the Disk
  did not kill.~~ **Closed 2026-09-10 — both BUILT, as an EXTENSION of
  the knob** (§2, §4). Three things under them are left open and are
  worth naming.
  THE DEFERRAL DOES NOT BOOK ITS OWN MANA. It declines the activation
  and nothing keeps the cost open, so an ability scored after it in the
  same `_try_activate` pass can spend the mana the deferred sweeper will
  want in their combat. `AiPlayer._held_reserve` is a reserve for CARDS
  and the ability scorer only reads it; a reserve for a deferred
  ACTIVATION is a second mechanism and was not built for a row about
  timing.
  THE STATICS READING IS ONE FACE OF THE QUESTION. What
  `AiPlayer._ground_the_sweep_opens` answers is attack LEGALITY — a Moat,
  an Arboria, an Island Sanctuary, an Evil Eye. The other faces of "the
  after board must apply what the sweep removes" are an ANTHEM the sweep
  takes (a Crusade, a Bad Moon: the survivors are read at the size the
  anthem still gives them) and a keyword an aura granted. Those want a
  real recalculation of the CR 613 layers on a board that does not
  exist, inside a per-X loop, and the cheap exact answer that works for
  `cur_cant_attack` — it is set by a static and by nothing else, so a
  sweep that takes every static on the table cannot leave one grounding
  anything — has no equivalent for a number. Where a static source
  survives the sweep the reading stays conservative on purpose, and a
  FLOATING static (one whose source has already left the battlefield) is
  not counted at all.
  AND THE DISK UNDER OUR OWN MOAT IS NOT A MALFUNCTION THE ROW FIXES.
  With a Moat of ours and three Craw Wurms across the table the Disk
  fires in our main phase on both arms and always did: the board swing
  is 47.20 and the relief is correctly 0, because the ground is held.
  What is wrong there is not the timing but the HORIZON — the Moat
  answers every ground creature still in their deck and nothing in this
  engine prices a permanent's future (`counts_the_race`'s row,
  `docs/AI-next-wave.md` wave 4).
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
- **THE TOLL'S STREAM IS STILL THE HORIZON'S, AND `minds_the_vise` DID
  NOT BRING ONE** (2026-09-10). `docs/forge/casting.md` P4 asks for the
  Black Vise "priced at the damage it will deal over `PACE_HORIZON`
  turns", and that is a rate times a number of turns this engine does not
  have — the same refusal the `EffectIntent.TOLL_BEATS` census made the
  same day for `prices_liabilities`, and for the same reason
  (`_face_damage_value` scales one hit by the share of a life total,
  `Evaluator.position_score` is a snapshot, `PACE_HORIZON` is a library
  clock under a knob of its own, and `CombatSearch` sees one turn). What
  shipped prices ONE BEAT — the damage the card is about to deal, which
  is a number the table is showing — so a Vise squeezing for three reads
  4.45 against a Jayemdae Tome's 4.20 and a Vise squeezing for nothing
  reads its printed 1.00, which is the right answer to both boards but
  is NOT the note's. **AND `counts_the_race` LANDED THE SAME DAY AND
  ANSWERED NO** (the bullet below), which closes this rather than
  deferring it: the only clock this engine can count forward honestly is
  the DECKING one, so a toll's stream stays one beat and that is the
  reading, not a stand-in for a later one. The two liability rows that
  were sent here close the same way.
- **P4's LAST CLAUSE — the Wall or the Bear not cast under a Moat — IS
  THE DEFENDER DISCOUNT UNDER ANOTHER NAME, and that constant was
  measured and refused on the same day** (§4, "THE PRICE OF A BODY THAT
  CANNOT ATTACK"). A creature that arrives grounded is worth its blocking
  half alone, which is exactly what `defender_scale` prices, and the
  answer over all nine wall pairs the pool can play was 1 340 of 9 000
  games different with 65 flipped to a win and 56 away — a coin. Pricing
  the same discount off `cur_cant_attack` instead of off the DEFENDER
  keyword would widen a refused constant rather than test a new reading,
  so it was left. The half of the clause that DID ship is the other
  direction: the Moat itself is priced by the attack it holds, so the
  Disenchant goes at it.
- **THE RACK CANNOT BE MEASURED IN THIS POOL** (2026-09-10). Two decks in
  `decks/` play it and neither loads (`wc1995_blumke`, 9 proxies;
  `winds_of_chains_justice`, 3), so the slope reading — the half
  `docs/forge/casting.md` P4 has backwards — is pinned by
  `tests/ai/test_ai_minds_the_vise_2026_09_10.gd` and by nothing else.
  Storm World, the pool's third hand toll, is in no deck at all.
- **THE LOOP'S OWN MEASURE IS NOT IN THE LAB.** Both `docs/AI-next-wave.md`
  and `docs/forge/casting.md` P5 ask for "the median turn at which the
  loop first runs, from `games.csv`" — and `games.csv` carries
  pair, decks, value, arm, game, seed, on-the-play, won, turns, stalled,
  drawn and a fingerprint, and nothing whatever about which card was cast
  when. The instruments the Lab actually has for a knob this rare are the
  win rate, the PAIRED count of games that end differently, and the flips
  each way; `runs_loops` was read on those and the reading is in §4. A
  per-card census would be a change to `DeckLab/simulate.gd`, which is
  not this pass's.
- **THE HORIZON: WHAT `counts_the_race` BROUGHT, AND WHAT IT REFUSED TO
  INVENT** (2026-09-10). Four rows of that day ended by naming this one as
  the thing they lacked — the land sweep's rebuild, the wall that blocks
  every turn forever, the Disk fired under our own Moat, the Vise's
  stream — and all four asked the same question: *how many turns has this
  game left*. The answer the row shipped is narrow and is a RULING rather
  than an omission.
  **ONE CLOCK IN THIS ENGINE COUNTS FORWARD HONESTLY, AND IT IS THE
  DECKING ONE.** A library is monotone: it only ever shrinks, its draw
  step is a rule and not a choice, and a mill on the table mills again
  next turn unless somebody takes it off. So `library ÷ (1 + the mill
  aimed at it)` is a number of turns that is a FACT about the table
  (`AiPlayer._deck_clock`), and it needs no constant that is not already
  here — the bound is `PACE_HORIZON`, the libraries' own twenty draw
  steps, which is the sentence that horizon was written to say.
  **EVERY OTHER RATE THE ENGINE CAN SEE IS REVISABLE INSIDE A TURN, and
  that is why the general horizon is refused.** A combat clock moves the
  moment a creature is cast, blocks or dies — which is exactly why
  `reads_race` will not read one more than `RACE_HORIZON` (four) turns
  out, and the same objection applies with more force at ten or twenty. A
  toll stops the turn its permanent leaves the battlefield. A mana
  drought's "turns to rebuild" is a hand, a curve and a land count, and
  half of it (theirs) is hidden. And what a Moat still answers — the Disk
  deferral's own example — is a question about the CARDS LEFT IN A
  LIBRARY, which is a hidden zone this AI is forbidden to read
  (`docs/forge/README.md`, "no hand reads"). A number of turns multiplied
  by any of those is a guess wearing a fact's clothes, and this repository
  has twice ruled that an invented constant is worse than the silence
  (`EffectIntent.TOLL_BEATS`, `TOLL_UNKNOWABLE`). So the three rows that
  wanted a game clock keep the readings they shipped with — one beat, one
  turn, one board — and this row does not hand them a longer one it
  cannot defend. What it does hand them is the shape of the argument: ask
  first whether the quantity being counted forward can grow back.
- **THE MILL CANNOT BE MEASURED IN THIS POOL, AT ALL** (2026-09-10, and
  it is the third such finding in two days). Five decks in `decks/` hold
  a maindeck Millstone — `tournament/ptcs_regnier`, `ptcs_loconto`,
  `wc1995_redi`, `ptny1996_sclafani` and
  `extended_community/os_tinker_the_deck_menendian_2014` — and **not one
  of them loads**: every one is proxy-blocked (exit 2). Three of the five
  are the decks `docs/forge/casting.md` P3 names for its own measurement.
  Two more decks name the card and neither counts: `wc1995_hernandez`
  says "Millstone control" in a comment and plays none, and
  `ptdallas1996_baca` has two in its SIDEBOARD, which the Lab never swaps
  in without `--best-of`. Millstone is also the ONLY card in the pool
  with a `MillEffect` at all. So the whole mill half of this row — the
  activation, the rate, the pace correction and the relief — is pinned by
  `tests/ai/test_ai_counts_the_race_2026_09_10.gd` and by nothing else,
  exactly as The Rack's slope is, and what the Lab can measure is the
  wheel half.
- **AN ACTIVATED ABILITY CANNOT BE COUNTERED IN THIS ENGINE, so half of
  P3's clause (b) is not buildable rather than not built.** The note asks
  `_try_counter` to treat "a draw at us that decks us OR a Millstone
  activation" as ALWAYS. The draw half was already there before this row
  — `counters_by_shape`'s third shape, since 2026-09-10 — and the
  activation half has nowhere to live: `TargetSpec.Kind` has `SPELL` and
  no `ABILITY`, `_try_counter` returns immediately unless the top of the
  stack is `Mtg.StackKind.SPELL`, and no card in this pool counters an
  ability. It would be an engine row and a card row, not an AI knob's.
- **THE MILL RATE IS THE ONE THE PERMANENT PRINTS, NOT THE ONE ITS MANA
  ALLOWS.** `AiPlayer._mill_rate` counts a `{T}` mill once a turn and
  never asks whether its controller can pay the `{2}` on the turn in
  question: the clock is a question about many turns and the mana is a
  question about one. It therefore slightly overstates BOTH clocks — for
  our own library that is the safe direction, and for theirs it is the
  plan the pilot is actually executing. A mill with no tap in its cost
  has a rate the reading cannot bound and is refused outright, which is
  `TOLL_UNKNOWABLE`'s ruling again; no such card is in the pool.
- **THE WHEEL GUARD HAS NO MIRROR IN `_try_counter`.** A Timetwister of
  OURS that would hand back a race we hold is refused
  (`AiPlayer._hands_back_the_race`); a Timetwister of THEIRS that would
  hand back a race THEY hold is not counted as an ALWAYS by
  `_counter_shape`, which reads the two HANDS for a wheel and not the two
  libraries. It is the same reading from the other side of the table and
  it is left open on purpose: `counters_by_shape`'s wheel clause is a
  hand reading with its own null, and widening it is that knob's row.
- What the engine should eventually know about the old loops a player
  brings to the highest table — Channel-Fireball, the infinite turn, the
  Vise behind a Moat, decking — is `docs/arzakon.strategy`, section 4.
  Two of its four are now the pilot's: item 2 (empty the hand under a
  Vise, never wheel into one) and item 6 (recognise the three-card loop),
  as `minds_the_vise` and `runs_loops`. Items 1 and 4 — counter by what a
  spell does, and count the library against a mill — are
  `counters_by_shape` and `counts_the_race`, both shipped on 2026-09-10.
  **All four of section 4's AI items are now the pilot's**, and what each
  of them could not reach is written above rather than left to be found.

class_name AiProfile
extends RefCounted
## The AI difficulty surface — every knob the game tunes lives here, so
## "make the AI stronger/weaker/different" never means touching decision
## code. Presets carry the ORIGINAL game's difficulty names.
##
## Design (informed by mage-go's ai/personality.gd continuous-weights
## approach and the original's difficulty behavior documented in the lore
## doc): difficulty is primarily MISTAKE RATE, not different rules — weak
## AIs know how to play and sometimes don't; strong AIs simply stop
## fumbling. That matches how the 1997 game scaled ("the AI makes less
## mistakes" — Dana Huyler FAQ 1.1) and keeps every difficulty honest.
##
## Knobs:
## - mistake_chance: probability an intended action degrades (a cast is
##   skipped, an attacker stays home, a block is dropped). Rolled on the
##   game RNG — deterministic under seed.
## - aggression 0..1: tilts combat risk-taking and burn-to-face choices.
##   0.5 is balanced; the Apprentice swings recklessly high.
## - chump_threshold: the PANIC LINE — how low (in life) before the AI
##   starts chump blocking to survive, and before damage already dealt is
##   worth a damage-prevention effect (§6.8's window).
## Future knobs land here too (eval weight scaling, search depth when the
## minimax lands — mage-go's search/ package is the reference).

## Display name, and the key the UI shows for the difficulty.
var profile_name := "Custom"

## Probability in [0, 1] that an intended action degrades — a cast skipped,
## an attacker left home, a block dropped. Rolled on MtgGame.rng, so a
## seeded duel replays the same mistakes.
var mistake_chance := 0.0

## Combat and burn risk appetite in [0, 1]; 0.5 is balanced. Higher means
## more attacks that trade badly and more burn thrown at the face.
var aggression := 0.5

## THE PANIC LINE: the life total at which the AI starts spending resources
## purely to survive. Higher = panics earlier, which is why the strong
## profiles carry the LARGER number — a Wizard that sees lethal two turns
## out throws bodies in front of it sooner.
##
## Two users, one meaning. It is the chump-BLOCK trigger (life after the
## incoming attack), and since the 1997 damage windows landed it is also
## the bar at which damage already on the table is worth a prevention
## effect (`AiPlayer._packet_worth`, docs/duel-todo.md §6.8) — the same
## question one step later in the turn, so it is deliberately not a second
## number to tune.
var chump_threshold := 5

## THE HAND'S WEIGHT in [method Evaluator.position_score] — and the one
## evaluator number a profile carries rather than reading the file's
## constant ([constant Evaluator.W_HAND], which is this default; the two
## are pinned to each other by
## `tests/ai/test_ai_w_hand_2026_09_10.gd`, since the evaluator reads the
## profile and so the profile may not name the evaluator).
##
## NOT A DIFFICULTY KNOB, and the only field here that is not. Every
## preset ships the same value and no rung moves it. It is here because
## `apply_overrides` is how the Deck Lab puts a NUMBER on a seat, and the
## Forge study's casting note P11 asks for the hand:life ratio — 1.5
## here, 2.5 in Forge — to be settled by a sweep rather than by argument:
## `--sweep w_hand=1.5,2.0,2.5`.
var w_hand := 1.5

## THE DEFENDER'S DISCOUNT and THE ABILITY BONUS in
## [method Evaluator.permanent_value] — two more evaluator numbers a
## profile carries rather than reading the file's constant
## ([constant Evaluator.DEFENDER_SCALE], [constant Evaluator.ABILITY_BONUS],
## which are these defaults).
##
## NOT DIFFICULTY KNOBS, exactly as [member w_hand] is not: every preset
## ships the same values and no rung moves them. They are here because
## `apply_overrides` is how the Deck Lab puts a NUMBER on a seat, and the
## Forge study's combat note P6 asks for a defensive body's price to be
## settled by a measurement rather than by an argument:
## `--sweep defender_scale=0,0.4`, `--sweep ability_bonus=0,0.5`.
var defender_scale := 0.0

## See [member defender_scale].
var ability_bonus := 0.0

## Gates the whole reactive game: counterspells, Fog, combat tricks, holding
## mana open — and, since §6.8, the 1997 DAMAGE-PREVENTION and REGENERATION
## windows, which are a priority round whose only legal actions are fast
## effects and so belong to exactly the same appetite. The Apprentice plays
## pure "my turn only" Magic, which is EXACTLY the right feel for the
## lowest difficulty: with the fork on it simply lets the automatic
## prevention order apply, the way every duel worked before the fork
## existed.
var holds_instants := true

## Minimum Evaluator threat value worth spending a Counterspell on. A HIGHER
## number is a pickier AI that lets more through, which is the weakness the
## Magician's 7.0 encodes; the Wizard's 5.0 answers threats a tier smaller.
var counter_threshold := 5.0

## How many cards this profile may move between its deck and its sideboard
## between the duels of a match ([AiSideboard], M4 phase 2.x). 0 = does not
## sideboard at all, which is the Apprentice: adapting between duels is a
## whole layer of play, and the bottom difficulty not having it is the same
## honest weakness as [member holds_instants] being false there.
##
## Difficulty scales through this number and through
## [member mistake_chance], which fumbles individual swaps — there is
## deliberately no second difficulty concept for sideboarding.
var sideboard_swaps := 0

## THE CRACK-BACK SEARCH's budget in leaf evaluations, or 0 for a profile
## that does not look past its own combat ([CombatSearch], M4 phase 3).
##
## A CAPABILITY, like [member holds_instants] and
## [member sideboard_swaps] — not a second difficulty concept. Reading the
## opponent's counter-swing before committing an attacker is a whole layer
## of play, and the bottom two difficulties not having it at all is the
## same honest weakness as the Apprentice never holding an instant. The
## Sorcerer gets half the Wizard's budget, so its search truncates on the
## wide boards the Wizard still resolves; the ladder therefore stays
## monotone in this knob as it does in every other.
var combat_search_nodes := 0

## THE ENGINE ROOM: does this profile understand an activated ability whose
## payoff is CUMULATIVE rather than a board swing this turn — a land that
## becomes the deck's only clock, a Scepter that takes a card off their
## hand every turn, a Tome that turns mana it has nothing else to do with
## into cards?
##
## A CAPABILITY, like [member holds_instants] and
## [member combat_search_nodes] — not a second difficulty concept. Reading
## a permanent as a THING THAT PAYS OVER TIME rather than as a number on
## the board today is a whole layer of play, and the bottom two
## difficulties not having it at all is the same honest weakness as the
## Apprentice never holding an instant. Everything it gates is priced from
## numbers the AI already had, and nothing it gates is card-named.
##
## It is what a control deck is MADE of: an AI without it answers every
## threat correctly and then never wins, because the cards that turn
## survival into a victory are all of this shape (docs/ROADMAP.md, "the
## control sweep").
var plays_engines := false

## THE TRADE: does this profile activate an ability whose cost is one of
## its OWN permanents — a Strip Mine that goes to the graveyard to take a
## land with it, a Goblin Digging Team that dies demolishing a Wall, a
## Scavenger Folk traded for a Disk?
##
## A CAPABILITY, like [member plays_engines] — not a second difficulty
## concept. Weighing a permanent you hold against the one it buys is a
## whole layer of play, and the bottom two difficulties not having it at
## all is the same honest weakness as the Apprentice never holding an
## instant. Until 2026-09-06 no profile had it: `_ability_available`
## refused every sacrifice rider outright, and 2,733 battlefield-turns of
## Strip Mine produced zero activations (docs/ROADMAP.md, "the control
## sweep", still open). Everything it gates is priced by the body that
## goes ([method AiPlayer._sacrifice_price]) against the body it takes,
## and nothing it gates is card-named.
var pays_sacrifices := false

## THE WINDOW: does this profile cast a spell whose ONLY legal moment is
## outside its own main phase — a Festival at their upkeep, a Siren's Call
## before they declare attackers, a Reset once they are past their upkeep,
## a Teleport in the declare-attackers step?
##
## A CAPABILITY, like [member plays_engines] and [member pays_sacrifices]
## — not a second difficulty concept. Knowing that a card in hand has a
## moment, and that the moment is on the other side of the table, is a
## whole layer of play, and the bottom two difficulties not having it at
## all is the same honest weakness as the Apprentice never holding an
## instant. Until 2026-09-06 no profile had it: the main-phase planner
## refused every "Cast this spell only ..." rider by asking it, and
## nothing outside the main phase asked at all, so twelve cards in the
## pool sat in hand for the whole duel (docs/ROADMAP.md, the dead-card
## sweep's class 1). Everything it gates is priced from the board by
## [method AiPlayer._window_worth]; the only thing named by card is the
## SHAPE of a card-local effect ([constant EffectIntent.WINDOW_SHAPES]),
## the way [constant EffectIntent.CARD_LOCAL] names one.
var casts_timed_spells := false

## THE LIFE A TAP COSTS: does this profile know that a City of Brass is
## not a Plains? On, the planner taps the painless source first, never
## taps a source whose damage would be the last of its life ([method
## AiPlayer._pain_excluded]), and prices the life an ability's taps would
## cost against what the ability buys ([method AiPlayer._try_activate]).
## On for EVERY profile: an Apprentice that kills itself tapping for a
## Grizzly Bears is not a weak player, it is a broken one. It is a knob
## only so the Deck Lab can run the null.
var minds_pain := true

## THE HOST: does this profile hang a friendly aura only on a creature
## that gets something from it? On, what the aura grants is read off
## its own words ([method EffectIntent.aura_gifts]) and a host that has
## the keyword already, or is offered an attacker's gift (vigilance,
## fear, landwalk, unblockability) while it cannot attack, is passed
## over ([method EffectIntent.aura_fits]); with no fitting host the
## aura waits in hand. The owner's playtest (2026-09-08): *"the AI put
## 'eternal warrior' aura - vigilance on the wall - this is complete
## nonsense!"* On for EVERY profile, like [member minds_pain]: vigilance
## on a Wall is not a weak play, it is no play. A knob only so the Deck
## Lab can run the null.
var fits_auras := true

## THE OPENING HAND: does this profile judge its own opening hand, or
## throw back only the hand with no land or nothing but land? On, the
## judgment is [AiMulligan]'s — lands against a keep range that narrows
## with the hand, then whether those lands cast anything; off, the plain
## rule every agent has ([method DecisionAgent.choose_mulligan]). The
## owner's playtest (2026-09-08): *"ok maybe for ai lets write some
## mulliganning logic!"* On for EVERY profile, like [member fits_auras]:
## keeping one Island under six red cards is not a weak start, it is no
## start. A knob only so the Deck Lab can run the null.
var mulligans := true

## THE TRIBUTE: when a card makes this profile give up one of its own —
## The Abyss at its upkeep, a Lord of the Pit's or a Lich's tribute, a
## Mana Vortex's land, an Elder Spawn's Island, a Sylvan Library's extra
## draw — does it give up the LEAST valuable? Until 2026-09-08 the
## answer to every such ask was the card the seat valued MOST
## ([method AiPlayer.answer_card] priced every card ask as a gain), so
## an AI under The Abyss fed it a Serra Angel and kept the Bears beside
## it, and a Lord of the Pit ate its master's best creature every turn.
## On, an ask that is a loss — the candidates all its own, the prompt a
## sacrifice, a destruction or a discard — is answered with the cheapest
## body ([method AiPlayer._own_value]) or card. On for EVERY profile,
## like [member minds_pain]: feeding the Abyss your Angel is not a weak
## play, it is no play. A knob only so the Deck Lab can run the null.
var feeds_worst := true

## THE WRONG SIDE OF THE TABLE: does this profile keep its own permanents
## out of the slots of a spell it reads as harmful? Off, a slot the
## opponent's board cannot fill is filled from ours and the cast priced
## as if that cost nothing — "tap X target creatures" padded with our own
## creatures once theirs run out (Winter Blast: 112 of the 293 creatures
## it named in sixty Ape Lord games were the caster's own, 2026-09-08),
## "destroy X target Mountains" with our own Mountains. The owner's
## playtest (2026-09-08): *"Opponent cast Detonate on its own artifact??
## (Artifact was not harming, it was Mana Vault)"* — {1}{R} paid to
## destroy its own untapped Mana Vault and take one damage. That cast was
## the reader's fault first: Detonate had no row in [constant
## EffectIntent.CARD_LOCAL], so the picker's fallback for an effect it
## could not classify shopped our side, and the row is what closes it.
## This knob is the rule that fallback was the one exception to, stated
## where the slots are filled ([method AiPlayer._extra_targets]): a
## permanent of ours goes into a harmful slot only when the evaluator
## prices giving it up BELOW ZERO ([method AiPlayer._own_value]) — a
## liability, which no reading of this evaluator produces today, so the
## slot stays empty and the spell waits for a board that fills it. The
## reading is the evaluator's; no card name is asked. Two places the
## picker looks at our side on purpose are not this knob's: a slot
## stated relative to an earlier pick (Glyph of Delusion's Wall,
## TargetSpec.sibling_filter — a partner, not a victim) and the
## 2026-09-04 fallback itself, where the harmful reading is the thing
## doubted. On for EVERY profile, like [member feeds_worst]: tapping
## your own creatures to fill out a Winter Blast is not a weak play, it
## is no play. A knob only so the Deck Lab can run the null.
var spares_own := true

## THE LIABILITY: does this profile know that a permanent of its own can
## be worth LESS than nothing to it? [method Evaluator.permanent_value]
## floors at zero — a Mana Vault is an artifact of mana value one, so it
## is worth 1.0 whatever it is doing — and every question of the form
## "what does giving this up cost us" reads that floor ([method
## AiPlayer._own_value]). So [member spares_own]'s one door, a permanent
## of ours a harmful spell may take BECAUSE giving it up is worth less
## than nothing, could not open, and the tests that landed with it said
## so in as many words. The owner's Detonate, 2026-09-08: the AI should
## not blow up a working Mana Vault, and it should blow up one it cannot
## untap.
##
## On, [method AiPlayer._own_value] answers with what the permanent is
## still worth TO US minus what keeping it will cost us, and that number
## may be negative. Three readings, all off the card's printed words and
## the live board, none off a card's name:
##
##  * THE RECKONING. A permanent whose own printed line says that losing
##    it loses the GAME ([method EffectIntent.loses_the_game_on_leaving])
##    is never given up at any price. A Lich is the pool's one such card
##    and the evaluator priced it at 3.2 — below a Grizzly Bears — so a
##    seat asked to feed its own Lich answered with the Lich and lost the
##    game on the spot. That is a malfunction, not a weakness, and it is
##    why this knob is on at every rung.
##  * THE DEAD WEIGHT. A permanent that is tapped, does not untap in our
##    untap step, and whose every ability needs it untapped is doing
##    nothing for us for as long as it stays that way, whatever its
##    printed cost says ([method AiPlayer._dead_weight]) — a Mana Vault we
##    cannot pay {4} for, a Grizzly Bears under a Paralyze. Its worth is
##    zero, not its mana value — but only while EVERY price printed to
##    free it is out of reach, and since 2026-09-10 that includes the
##    price printed on what is ATTACHED to it ([method
##    AiPlayer._untap_prices]). Paralyze locks the creature and offers the
##    {4} on the AURA; a Serra Angel under one with four mana open used to
##    read as dead weight and go to the first "give up one of yours" ask
##    ahead of a Grizzly Bears.
##  * THE TOLL. What such a permanent still TAKES from us each turn, read
##    off its own trigger lines ([method EffectIntent.toll_of_line]:
##    "deals 1 damage to you" at a beat of the turn that comes round
##    whether we like it or not), charged at the reaper's rate ([method
##    AiPlayer._life_price]) for the turns our mana still needs to reach
##    the price the card itself names to stop it — and never more than
##    our whole life is worth. A toll with no printed price to stop it is
##    not read: a Serendib Efreet's point a turn is what the card costs,
##    not a liability, and the evaluator's snapshot cannot price a stream
##    that has no end. RULED for good on 2026-09-10 — the honest price is
##    the stream times a HORIZON, no reader in this engine estimates the
##    turns a game has left, and an invented constant would be worse than
##    the silence ([method AiPlayer._liability_price]). A SYMMETRIC toll
##    ("deals 1 damage to that player") is ruled the same day and for a
##    reason of its own ([constant EffectIntent.TOLL_WORDS]).
##
## What the knob then lets the pilot do is stated where the decisions
## are: the harmful spell's slot ([method AiPlayer._extra_targets]) and
## its single target ([method AiPlayer._pick_for_spec]) may be a
## liability of ours, but only when the effect actually TAKES IT OFF THE
## TABLE — tapping our own dead Vault relieves nothing — and the cast is
## priced with the relief and charged for the damage the card deals its
## own target's controller ([method AiPlayer._cast_value]).
##
## AND THE SAME STING THE OTHER WAY ROUND (2026-09-10). [member
## EffectIntent.damage_to_target_controller] was born under this knob and
## only its own-side half was charged, so a Detonate that cost us X to our
## own face gained the same X against theirs for nothing. Both halves are
## priced now, under this knob and no other, because the field is this
## knob's and a half-read field is what made the pilot blind to a lethal
## Detonate: their life goes on the AI's own clock ([method
## AiPlayer._face_damage_value]) and a lethal sting is worth the game.
##
## On for EVERY profile, like [member spares_own] and [member
## feeds_worst], and the Lich is the reason: a seat that sacrifices the
## enchantment it cannot lose is not playing worse, it is not playing.
## A knob only so the Deck Lab can run the null.
var prices_liabilities := true

## THE FALLOUT: does this profile price what its own spell does to its own
## side of the table on the way past? [member spares_own] keeps our
## permanents out of a harmful spell's SLOTS; this is the other half — the
## damage a spell deals to everything, ours included, once the slots are
## filled and it resolves. The reader has no field that can sum it
## ([constant EffectIntent.BLASTS] is where such a spell says so), and
## [method AiPlayer._cast_value] priced only the victims it named.
##
## Volcanic Eruption is the pool's one card of the shape — "destroy X
## target Mountains, then deal that many damage to each creature and each
## player" — and the census that named it had it right for the wrong
## reason: it resolved no cast in sixty games because it is a SIDEBOARD
## card in all three decks that hold it (Conjurer, Mind Stealer, Thought
## Invoker, `.vRed` sections), so a free-play census never draws it. Put
## it in a hand and the pilot casts it every time, at the biggest X its
## Islands will pay for and with no reading of the blast at all. Three
## boards, probed 2026-09-09:
##
##  * NINE ISLANDS, SIX MOUNTAINS, US AT FIVE. Cast for X=6, life -1,
##    game over, the opponent at 12 — a seat that kills itself with its
##    own sorcery.
##  * OUR BOARD THE BETTER ONE. A Mahamoti Djinn and two Serra Angels
##    against four Mountains and a Goblin: the Angels burn, to take four
##    lands and a 1/1.
##  * TWO MOUNTAINS, NINE ISLANDS. X=6 paid for two — four mana for
##    nothing, because the X buys TARGETS and there were only two.
##
## On, the planner walks every affordable X, prices the blast the way it
## prices a sweeper ([method AiPlayer._sweep_value]: what dies on each
## side on the board scale, both life totals at the reaper's rate, and
## never an X that is lethal to us), refuses an X that would put us on
## [member chump_threshold] or below it unless the blast wins the game
## outright, and keeps the cheapest X worth casting at all ([method
## AiPlayer._size_blast]). The panic line is what gives the rule a
## per-rung shape without a number of its own.
##
## On for EVERY profile, like [member prices_liabilities] and [member
## minds_pain]: an Apprentice that Erupts itself to death is not a weak
## player, it is a broken one. A knob only so the Deck Lab can run the
## null — off, the card is sized and priced exactly as it was before
## 2026-09-09.
var prices_fallout := true

## THE COUNT: does this profile size a card-advantage spell to the hands
## and libraries in front of it? On, an X discard is cast for the cards
## its target actually holds and waits while they hold none; an X draw is
## sized to the room in its own hand and never past its own library; a
## draw that would only be discarded at cleanup is not made; and a draw
## spell that can empty the OPPONENT'S library is pointed at them for the
## win ([method AiPlayer._size_and_aim], [method AiPlayer._hand_room]).
##
## A CAPABILITY, like [member plays_engines] — not a second difficulty
## concept. Counting the cards on the other side of the table before
## paying for a spell that acts on them is a whole layer of play, and the
## bottom two difficulties not having it is the same honest weakness as
## the Apprentice never holding an instant. Until 2026-09-07 no profile
## had it: the pilot cast Mind Twist for X=20 at an empty hand and
## Braingeyser for X=19 into a library of nine, and lost a third of its
## long games by drawing from an empty library at 30 to 47 life
## (docs/ROADMAP.md, "The Deck, second pass"). Everything it gates is
## read from [EffectIntent]'s draw and discard fields; nothing is
## card-named.
var counts_cards := false

## THE LEVELLER: does this profile price a spell that levels every
## player down to the smallest board — lands, hands, creatures — by what
## each side would actually lose? On, the leveller is cast when the
## count is in our favour by a Bears' worth ([constant
## AiPlayer.SWEEP_BAR], the sweeper's own bar) and held otherwise; off,
## it is cast for its printed worth like any two-mana sorcery, which is
## how the pilot came to sacrifice seven lands and four cards for
## nothing at fifteen lands to their eight (docs/ROADMAP.md, "The Deck,
## second pass"). Sorcerer and Wizard. What it gates is [method
## AiPlayer._level_value], a count on the Evaluator's scale; the one
## card-named thing is the READING ([constant EffectIntent.LEVELLERS]),
## because the pool's one leveller is a card-local effect, the way a
## window card's shape is named.
##
## AND SINCE 2026-09-10 THE LAND SWEEP, which is the same sentence with
## only the land clause: a sweeper whose every kill is a LAND levels both
## manabases to nothing, so it is priced by what each side would lose
## rather than by a head count. Two things follow ([method
## AiPlayer._land_sweep], [forge] `DestroyAllAi.java:146-163`). Each land
## it takes is worth what it is worth to its controller ([method
## Evaluator.land_value]: scarcity, a dual, the only source of a colour,
## a land that does more than make mana) instead of [method
## Evaluator.permanent_value]'s flat 1.0, so a Library of Alexandria and
## three duals are not four Plains. And whatever THEIR board gets through
## that ours does not is charged against the swing at the reaper's rate
## ([method AiPlayer._drought_clock], [method AiPlayer._life_price]): an
## all-lands sweep kills nothing on the table, so both boards go on
## hitting each other with no mana to answer with, and the pilot used to
## Armageddon on the land count alone with two Serra Angels facing it.
var levels_boards := false

## THE PACE: does this profile pace its optional draws to the race of the
## libraries? Every optional draw — a Tome tick, a Library of Alexandria
## at seven, an Ancestral for three, a Braingeyser sized for its own
## hand, a tutor — is a card off the library, and a library is the other
## clock in a game of Magic: the player who has to draw from an empty one
## loses (CR 704.5b). The race is the two library counts and WHOSE draw
## step comes next ([method AiPlayer._library_slack]): on, a draw that
## would hand the OPPONENT that race is refused once the end is within
## sight ([constant AiPlayer.PACE_HORIZON] cards of our own library); a
## race already lost is not ours to protect, and a draw that keeps it
## costs nothing. Off, the pilot draws for value alone, which is how a
## sixty-card deck of card-drawers lost to forty-card starters on an
## empty library at twenty life and more (docs/ROADMAP.md, "The Deck,
## second pass"). Sorcerer and Wizard. Nothing here names a card: the
## rule reads [member EffectIntent.draws], [member EffectIntent.searches]
## and the two library counts.
var paces_draws := false

## THE TUTOR'S PICK: does this profile fetch the card THIS TURN wants, or
## the dearest card in the library? Off, a search asks one question —
## [method Evaluator.card_value], the printed worth of a card as a thing
## to have — so a Demonic Tutor on two lands with a hand of four-drops
## fetches a fourth four-drop, and a Mahamoti Djinn is taken ahead of the
## creature we could cast next turn because it is bigger. On, the pick
## is made in the order the casting note ranks it (docs/forge/casting.md
## P9, [method AiPlayer._tutor_pick]): a LAND when we are short of them
## and hold none, taken for the colour the hand is missing; then the best
## of what NEXT TURN'S mana can cast; then the card worth most on THIS
## BOARD rather than on its own — a sweeper priced by what the sweep
## would swing, a leveller by what each side would lose, everything else
## by its printed worth. Sorcerer and Wizard: it is a layer of play (the
## turn ahead read into a card choice), not a number, and an Apprentice
## that fetches the biggest card it owns is playing a poorer game rather
## than a broken one. Nothing here names a card — the seam is a card ask
## whose candidates all sit in the LIBRARY, which is the shape every
## tutor in this pool has ([method AiPlayer._tutor_ask]).
var tutors_for_the_turn := false

## THE SECOND LEGEND: does this profile keep in hand a permanent whose
## arrival would be a card thrown away? A legend whose name is already
## on the battlefield — either side's — is buried the moment it lands
## (the legend rule as 1997 played it: the newcomer loses), and a world
## enchantment buries every other world on arrival (CR 704.5k), a world
## of OURS with it — the same card twice, or a world traded for a world.
## A world of THEIRS is what ours is for, and is not held. Off, the pilot
## cast its second and third The Abyss over the first, four mana and a
## card each time (docs/ROADMAP.md, "The Deck, second pass"). Sorcerer
## and Wizard. Nothing here names a card: the rule reads the supertype
## bits and the names on the battlefield ([method
## AiPlayer._arrival_wasted]).
var holds_duplicates := false

## THE FACTORY ANIMATED FOR NOTHING: does this profile animate a
## permanent only when the attack that pays for it would actually be
## declared? An animation is priced by the attack it enables and nothing
## else ([method AiPlayer._animation_value]), and until 2026-09-08 that
## price was read off a blocker count of its own while the declaration
## it was paying for was made by a different reader — the attack
## legality of the whole board (our own Moat stops a Factory as surely as
## theirs), the cohort, and the crack-back search, which held an
## animated body home as next turn's blocker, a body that is a land
## again at cleanup. So the pilot paid a mana a turn, sometimes two, for
## a 2/2 that then declared nothing (docs/ROADMAP.md, "The Deck, third
## pass"). On, the animation is tried under the journal — the body is
## animated, the declaration made by the attack code itself, and both
## unmade — and paid for only when it would attack; and the crack-back
## model stops counting a body that is a creature only until end of turn
## as a blocker on their turn. Off, the two readers disagree as before.
## Sorcerer and Wizard, with [member plays_engines], which is the only
## way an animation is ever bought. Nothing here names a card: the rule
## reads [AnimateSelfEffect]'s duration and the attack code's own answer.
var animates_to_attack := false

## THE SWEEP THAT ANSWERS AN ATTACK: does this profile price a board
## wipe by the pressure it relieves, and hold one it can activate for
## the attack it answers? A sweeper's worth was, until 2026-09-08, the
## board it takes minus the board it costs, on the Evaluator's scale and
## nothing else ([method AiPlayer._sweep_value]) — which for a control
## deck is the wrong sum: its own engines — the Tome, the Scepter, the
## Tower — priced a board of three 2/2s as a loss to sweep, while those
## 2/2s took the pilot from twenty to nothing with the Disk untapped
## beside them (docs/ROADMAP.md, "The Deck, third pass": six of twenty
## losses to Black-Red Raiders ended that way). On, two readings: the
## damage their creatures would push through our blockers is counted
## before and after the sweep — a creature of theirs an Abyss takes at
## their upkeep never attacking ([method AiPlayer._upkeep_meals]) — and
## the relief priced at the reaper's rate ([method AiPlayer._life_price]),
## lethal-worth when the sweep is the out; and a sweeper that can be
## ACTIVATED is offered in their combat too, once the attackers are
## declared and before the damage — the moment the wipe is also a Fog
## (Weissman's own Disk timing). The sweeper's own body still counts as
## a loss: the first cut left it out as "the activation's price" and
## fired a Disk at twenty life to kill a lone 3/3. Off, the sweep is
## priced as a trade of permanents and fired only at the three ability
## moments. Sorcerer and Wizard. Nothing here names a card: the rule
## reads [member EffectIntent.sweeper], the combat maths the attack code
## already shares, and the appetite an upkeep trigger declares
## ([member TriggeredAbility.kills_each_upkeep]).
var times_sweeps := false

## THE ABYSS AS AN ANSWER: does this profile save a counterspell when the
## creature spell on the stack is one its Abyss will eat? The counter
## decision ([method AiPlayer._try_counter]) priced every opposing spell
## by its printed worth against [member counter_threshold], so a Wizard
## with The Abyss on the table and {U}{U} open spent its Counterspell on
## the Serra Angel the enchantment would have destroyed at its
## controller's next upkeep — and had nothing left for the Disenchant
## that came for the Abyss (docs/ROADMAP.md, "The Deck, third pass"). On,
## a creature spell whose body would be the next meal of a feeder on the
## table — one that declares an appetite ([member
## TriggeredAbility.kills_each_upkeep]) whose target rule the body
## satisfies, with no cheaper legal creature of theirs to be fed first —
## is let through: it dies at their next upkeep having done no more than
## block once. A creature their board already shelters (a Bears to feed
## first) is still a threat and still countered. Off, every spell is
## priced as printed. Sorcerer and Wizard. Nothing here names a card:
## the rule reads the appetite the trigger declares and the Evaluator's
## own scale, so a second feeder in the pool is answered the same way.
var trusts_abyss := false

## THE FIREBREATHER THAT NEVER SWUNG: does this profile judge a creature
## of its own at the size the mana it has OPEN can make it, when the
## attack is declared? The owner's playtest (2026-09-09): *"when
## creatures can have greater power or defense by some action (like
## paying mana), the ai opponent does not use this before attack for
## example (even if opponent has free mana available). In other words:
## Opponent does not pump Carrion Ants :)"*. The declaration read
## [member CardInstance.cur_power] and nothing else ([method
## AiPlayer._choose_attack_cohort] drops a body with no power at all
## before it prices anything), so a Carrion Ants with four Swamps
## untapped — a 4/5 for the asking — was a 0/1 that could never be worth
## sending, and every firebreather in the pool that starts at zero
## (Frozen Shade, Killer Bees, Carrion Ants) stayed home for the whole
## duel. What happened AFTER the declaration was already right: an
## unblocked attacker breathes fire for the damage ([method
## AiPlayer._offensive_combat_response]) and a blocked one pumps to win
## or survive its trade ([method AiPlayer._combat_self_pumps]) — the two
## routines had simply never been given an attacker to work with.
##
## On, three readings. The declaration is made under the journal with
## every candidate grown to the size its share of the open mana can
## reach ([method AiPlayer._attack_choice_once_pumped]) — the same probe
## shape [member animates_to_attack] uses, and for the same reason: the
## price and the declaration must be read by one reader. The mana is
## counted the way the firebreathing itself spends it, with the second
## main phase's best cast and the held instant kept whole ([method
## AiPlayer._pump_reserve]), so a Counterspell's mana is never a point of
## trample damage. And an ability with a per-turn cap is counted at its
## cap, not at the mana (a Fire Drake with five Mountains open is a 2/2,
## not a 6/2) — the cap reading is this knob's everywhere it is asked,
## the blocked pump included.
##
## AND THE BLOCK, SINCE 2026-09-09 — the knob's meaning GREW, and the
## name is the half it was born for. The first pass read the attack
## only, so the same Carrion Ants with six Swamps open declared no block
## at all against a Craw Wurm and took six to the face: [method
## AiPlayer._plan_blocks] and [method AiPlayer._best_block_for] read
## [member CardInstance.cur_power] and [member CardInstance.cur_toughness]
## straight down the ladder, and a 0/1 kills nothing and survives
## nothing. [method AiPlayer._block_choice_once_pumped] is the attack
## probe mirrored — the same [method AiPlayer._reachable_pumps], the same
## journal, the same unmaking — and the PANIC LINE is read inside it, so
## the residue that opens the chump rung is the damage that lands once
## the blocks we can afford have been made. That is one capability, not
## two: mana spent before a combat declaration to make a declaration
## that does not otherwise exist. [member animates_to_attack] is named
## for its attack half and rules on the block in the same breath.
##
## THE THREE THE READER COULD NOT SEE, also 2026-09-09 and also here.
## Dragon Whelp and Nalathni Dragon breathe through a card-local
## `EffectBase` rather than a [PumpEffect] — they must, because the
## breath carries a fuse — so [member EffectIntent.pump_self] is false
## for both and no pump path had ever touched them. They are read
## through [constant EffectIntent.CARD_LOCAL_PUMPS], and the reading is
## gated HERE rather than in the reader's own tables, which are ungated:
## an ungated row would have moved this knob's null, and it would have
## sold Dragon Whelp's fourth breath with no cap read at all. The fuse
## itself ([method AiPlayer._activations_left]) hands every reader three
## breaths and no more; the fourth is for the attack that ends the game
## and nothing else. Rainbow Knights, the third of them, is refused by
## rule: its {W}{W} rolls +0, +1 or +2 at resolution, and what it
## guarantees for two white mana is nothing.
##
## AND WHAT THE PROBE PROMISES, THE RECOVERY DELIVERS (2026-09-09, the
## third pass, and both halves of it were named as open the day the
## second one landed). A declaration probe hangs the WHOLE bonus a body's
## share of the pool can reach; [method AiPlayer._combat_self_pumps] then
## buys the breaths for real and buys FEWER — a toughness bonus only when
## it saves the body, a power bonus only when it wins the trade. Where
## the ladder asks a kill-or-survive question the two agree by
## construction. Where it reads a MAGNITUDE they did not, and there were
## exactly two such readings.
##
## The TRAMPLER's overflow was one: the panic line and the chump rung's
## price both measured a trampler's surplus against the toughness the
## PROBE put on the blocker, so a Carrion Ants and a Scathe Zombies
## ganging a Force of Nature read the swing as nothing through and took
## five — neither kills an 8/8 alone, so nothing was ever bought and the
## swarm blocked at 0/1 with six Swamps up. Under-reading lethal is the
## direction that kills a pilot, and at eight life against that swing
## plus a Hill Giant it did. [method AiPlayer._absorbed_by] asks the
## recovery's own question of every blocker the trial plans instead.
##
## The ONE POOL was the other: [method AiPlayer._pump_shares] divides it
## among the bodies and the declaration is made on that division, but the
## recovery priced every body against the whole remaining pool, so the
## first body down the battlefield could spend what the second was priced
## with — a Carrion Ants taking three of four Swamps to save itself while
## the Vampire Bats beside it, allotted two, stayed a 0/1 and died for
## nothing. The split is written down where the declaration is made
## ([member AiPlayer._pump_plan]) and spent down one activation at a
## time, with a second uncapped pass for the mana no plan wanted. The fix
## is in the RECOVERY and not in the probe on purpose: the probe already
## reserves per body, and a second reservation written beside it is two
## plans that can disagree.
##
## AND THE TWO THINGS THAT PASS LEFT (2026-09-09, the fourth, and the
## same seam once more): where the declaration asks a question the
## recovery has to ask the SAME question, and where a breath is priced it
## has to be priced against the SAME reserve.
##
## The GANG's breath was the first. The block ladder's third rung
## declares a gang — two bodies whose combined damage kills — on the
## probe's sizes, and [method AiPlayer._combat_self_pumps] then asked
## each of them whether the breath let IT kill the attacker alone. In a
## gang none of them does, so the pilot declared the gang and bought
## nothing for it: on the third pass's own board — a Carrion Ants and a
## Scathe Zombies in front of a Force of Nature, six Swamps open, the
## gang priced at exactly the eight damage an 8/8 needs — both bodies
## died at 0/1 and 2/2, five trampled through, the trampler walked away
## and every Swamp was still untapped. [method AiPlayer._band_kills] is
## the ladder's own gang question as a predicate, and the recovery, the
## trampler's residue ([method AiPlayer._absorbed_by]) and the
## declaration all ask it now. The mates are priced at what the plan
## still owes them, so every body of a gang reaches the same verdict and
## they buy together; and because that pricing IS the plan, the question
## is asked only in the pass that honours it.
##
## The COUNTERSPELL's mana was the second, and it is older than this knob
## (a note of 36058fc's). Every breath in the file is priced against
## [method AiPlayer._pump_reserve] — the second main phase's best
## sorcery-speed cast AND the held instant or counter the reactive game
## is waiting on — except the one [method
## AiPlayer._offensive_combat_response] buys for an unblocked attacker,
## which booked the first of the two and spent the second. A Carrion Ants
## unblocked behind four Swamps and two Islands with a Counterspell in
## hand: the declaration priced it at four breaths and the recovery
## bought six, tapping every land, and the counter could not be paid for.
## One reserve now, and the lethal clause still overrides it — mana kept
## for a turn that will not happen is kept for nobody.
##
## What that pass did NOT do, by ruling: [method
## AiPlayer._offensive_combat_response] still does not consult the plan.
## It spends off it, and it costs nothing — by the time it runs the
## bodies it serves are UNBLOCKED and every point they buy is face
## damage, which is fungible between them, so any split of the same pool
## lands the same total. The reasoning is at the site.
##
## AND THE BURN ON THE STACK (2026-09-09, the fourth reading and the
## fourth time this knob's meaning has grown). [method
## AiPlayer._save_from_the_stack] is the arm that answers a removal spell
## aimed at one of ours, and against a BURN spell it knew exactly one
## answer: a pump INSTANT in hand ([method
## AiPlayer._find_pump_instant]). So a Frozen Shade with four Swamps
## untapped — a 4/5 for the asking, three of those Swamps enough to put
## it out of a Lightning Bolt's reach — died to the Bolt with the mana
## still on the table, and so did every firebreather in the pool with a
## toughness line. The machinery to price and buy the breath was already
## there and had been since this knob's first pass; the save path simply
## never asked it. [method AiPlayer._pump_out_of_reach] asks it, with the
## same reserve ([method AiPlayer._pump_reserve]: the second main
## phase's cast and the held instant), the same per-turn cap ([method
## AiPlayer._activations_left]) and the same one-activation-per-call
## shape [method AiPlayer._combat_self_pumps] uses. It is tried BEFORE
## the pump instant, because the breath spends mana that untaps and the
## instant spends a card that does not.
##
## A CAPABILITY, like [member animates_to_attack] — not a second
## difficulty concept, and the same layer of play: mana spent to make a
## body a size the pilot has to decide on now. Sorcerer and Wizard, for
## that reason; the Magician already breathes fire on an attacker that
## got through and already answers the stack with a Giant Growth, because
## both of those hang off [member holds_instants], and the ceiling
## between them is the ramp the owner ruled for on 2026-09-07. Nothing
## here names a card in the AI: the shape is [member
## EffectIntent.pump_self] read off the ability's own effects, the two
## card-local breaths are a table in the reader beside the window shapes
## and the levellers, the price is the planner's, and an ability whose
## cost is a BODY stays invisible ([method
## AiPlayer._ability_available]). An ability whose cost is a COUNTER is
## [member spends_counters]'s ruling, not this one's — with that knob off
## it stays invisible here as it always was.
var pumps_to_attack := false

## THE COUNTER THAT WAS NEVER SPENT: may this profile pay a cost of
## "remove N <kind> counters from this permanent"? Until 2026-09-09
## [method AiPlayer._ability_available] refused EVERY such ability
## outright, alongside the exile and discard riders the mana planner
## cannot model — so in the whole history of this AI no counter had ever
## been removed as a cost. The report that surfaced it was Osai Vultures:
## the bird accumulates carrion counters at every end step a creature
## died and never spends the two that make it a 2/2, blocking at 1/1 and
## dying for nothing. A Scavenging Ghoul never regenerates off a corpse
## counter either, and a creature holding Life Matrix's grant never
## regenerates at all.
##
## WHAT MAKES A COUNTER SPENDABLE, and it is not "all of them". A counter
## is a resource with other uses, and unlike tapping a land, removing one
## can cost the permanent its own substance: a Triskelion's +1/+1
## counters ARE the 4/4, and a pilot that pings three times has priced
## the damage and not the two points of body it gave up each time, which
## is the same blindness [member pays_sacrifices] was gated for. So the
## rule is NOTHING BUT THE COST MAY READ IT, and the two readers that can
## are asked off the card's own text and the live board:
##
##  * the NAME. A counter whose kind parses as a P/T delta — "+1/+1",
##    "-0/-2", "+1/+0" — is read by the characteristics pipeline itself
##    ([method ContinuousEffects.parse_pt_counter], which is how "any P/T
##    counter a card invents just works"), so removing one shrinks the
##    creature. Refused, Triskelion included.
##  * the LIVE FIELD. [member CardInstance.damage_eats_counters] names
##    the counter kind a permanent sheds instead of taking damage — a
##    Rock Hydra's heads are its life, point for point. Refused.
##
## Everything else this pool holds is FUEL: carrion, corpse and husk
## counters that a trigger of the card's own puts back, a matrix counter
## whose only use is the regeneration it was printed to buy, a dream
## counter that Rasputin refills each upkeep. Nothing prices the counter
## itself, and nothing has to: to every reader the pilot owns — the
## evaluator, the combat maths, the damage replacement — fuel is worth
## zero until it is spent, so the effect the existing readers already
## price IS the whole of the trade. What the ruling deliberately does
## NOT reach is a counter some OTHER ability of the same card reads —
## a clock, a Time Vault's turn counter, an Armageddon Clock's doom
## counter — because a card's own script cannot be read from outside it;
## in this pool no such counter is a COST (the Clock removes a doom
## counter as an EFFECT and the Oracle Time Vault has no counters at
## all), so the rule reaches nothing it should not, and the day one
## lands the card declares it.
##
## A CAPABILITY, and the same shape as [member pays_sacrifices]: a cost
## the mana planner does not model, paid for an effect the scorer already
## prices. Sorcerer and Wizard, for that reason — an Apprentice that
## never regenerates its Scavenging Ghoul is playing a poorer game, not a
## broken one, exactly as one that never cracks a Strip Mine is. Nothing
## here names a card: the counter's kind is read through the pipeline's
## own parser and the permanent's own live field.
var spends_counters := false

## WHICH COUNTER, AND WHAT THE UNLESS-COST'S X IS: does this profile pick
## the counterspell it answers a spell with, or fire whichever one sits
## first in its hand?
##
## Until 2026-09-10 [method AiPlayer._try_counter] walked the hand in
## order and cast the first card that could legally answer the spell on
## the stack, so a Mana Drain and a Power Sink in the same hand were
## spent by the shuffle: whichever the deck had dealt first went on
## whatever came first, and the Sink — the card that stops a spell for
## two mana while the caster is tapped out — was as likely to be left
## holding the bag for a Serra Angel. The same routine paid Power Sink's
## X "as deep as the mana goes", which against a tapped-out opponent
## meant eight Islands spent to make a one-mana price unpayable.
##
## With the knob on the counters that can answer THIS spell are ranked
## before one is cast — can we pay for it, does it actually stop the
## spell (a printed "unless its controller pays" price the caster can
## simply pay is no counter at all), what it costs us now with its X
## included, then the narrow card before the wide one and the card the
## evaluator would rather not keep — and an unless-cost's X is the
## smallest one the caster cannot pay, which is their open mana plus one.
## The two halves are the same reading from opposite ends, which is why
## they are one knob: what a soft counter costs and whether it works are
## both "how much mana can they still reach".
##
## A CAPABILITY, and it belongs to the rung [member holds_instants]
## belongs to: MAGICIAN and up. An Apprentice never casts a counterspell
## at all, so the knob is as inert there as [member counter_threshold] is
## — and the ranking is not a second difficulty dial, it is the layer
## being played competently or by the shuffle. Nothing here names a card:
## the unless-cost is the card's own oracle line and the narrowness is
## whether its own [TargetSpec] carries a filter.
var ranks_counters := false

## THE X BURN HELD FOR A BIGGER ONE: the smallest X this profile will pay
## to point an X burn spell at a CREATURE while the game is still young,
## or 0 for a profile that fires it at whatever it can size to.
##
## A NUMBER and not a switch, because what is being held is a size. An X
## burn is the only card in a hand whose worth grows with the turn — a
## Fireball is two damage on turn three and eight on turn nine, and the
## deck holds it because it is the reach — and
## [method AiPlayer._size_x_burn] sizes X to the victim, which is right,
## and then fired a two-point Disintegrate at a Grizzly Bears on turn
## three: one of the deck's two finishers spent on a bear, on a board a
## Lightning Bolt answers for one mana.
##
## The hold is bounded by the game's own age (the burn waits only while
## the turn count is under twice this number) and lifted by the pilot's
## own readings rather than by any constant: a burn that wins the game is
## taken before this is asked at all, and a pilot whose life the board in
## front of it is about to take ([method AiPlayer._in_danger], the panic
## line read against their clock) spends the card it was holding for turn
## nine. The face arm still runs under the hold, so a burn worth throwing
## at a player within reach of it is still thrown.
##
## A CAPABILITY, and the same shape as [member times_sweeps]: knowing
## that a card is worth more later than now is a whole layer of play, and
## the bottom two rungs not having it is the same honest weakness as the
## Apprentice never holding an instant. SORCERER 3, WIZARD 5 — the
## ladder is monotone in it, the larger number being the more patient
## pilot; the numbers are Forge's own Reckless and Default thresholds
## (docs/forge/casting.md P7), and its coin flip over them is not ported.
var holds_x_burn := 0
## THE THREE READS THE COMBAT MATHS NEVER MADE (2026-09-10): does this
## profile see the printed lines that decide a combat without ever
## appearing in the damage arithmetic?
##
## Every kill this AI predicts goes through [method AiPlayer._dies_to],
## and until this landed that predicate was power against toughness and
## nothing else. Three shapes in this pool settle a combat some other
## way, and the pilot walked into all three:
##
##  * THE GAZE. A Cockatrice or a Thicket Basilisk destroys whatever it
##    blocks or is blocked by, at end of combat, whatever the numbers
##    said. Reproduced 2026-09-10: a Craw Wurm swings into a Cockatrice
##    at `_attack_risk` 0.0 — "we kill it and live" — and the seat
##    declares the attack; on the other side of the table the same
##    reading keeps our OWN Cockatrice at home, because rung 1 of the
##    block ladder cannot see that the 2/4 kills the 6/4 it steps in
##    front of. The reading is [method EffectIntent.is_gaze], a BLOCKED
##    trigger whose printed line destroys that creature at end of
##    combat, with the trigger's own condition put to a probe event so
##    the "non-Wall" rider answers for itself (CR 603.4).
##  * RAMPAGE (CR 702.23). The engine applies +N/+N for each blocker past
##    the first ([method MtgGame.declare_blockers]) and the block ladder's
##    gang rung ignored it: two Grizzly Bears in front of a Craw Giant
##    read 2+2 against a toughness of 4 and gang up, and the 8/6 that
##    actually stands there kills them both and tramples four through.
##    Counted now wherever a gang is priced — the ladder's rung 3, the
##    band predicate the recovery shares, and the crack-back model's own
##    resolution.
##  * THE EXECUTIONER. An untapped Royal Assassin with {1}{B}{B} open is
##    the reason a non-vigilant attacker of ours does not come home:
##    tapping to attack is what makes it a legal target. Reproduced the
##    same day: a Hypnotic Specter swings past a 1/1 Assassin it cannot
##    be blocked by, `_attack_risk` -1.0 ("nothing over there may block
##    it"), and is in the graveyard before the damage step with their
##    life still twenty. Read as a shape ([method
##    EffectIntent.destroys_the_tapped] plus the spec's own refusal of
##    the body standing still), the way Forge's
##    `canBeKilledByRoyalAssassin` reads it.
##
## READS, not strength — which is why the rung is a question the numbers
## answer rather than a ruling. Sorcerer and Wizard, with the other
## combat capabilities, and measured at every rung so the ramp ruling
## (docs/ai-difficulty.md §1) can be applied to what it costs the bottom
## of the ladder. Nothing here names a card: two printed lines and one
## engine field ([member CardInstance.cur_rampage]).
var reads_gaze := false

## THE LAND THAT IS A BLOCKER, AND THE ONE OF OURS THAT COULD BE
## (2026-09-10): does this profile count a permanent that can animate
## itself as a body in the combat about to happen — theirs when we
## attack, ours when we block?
##
## TWO HALVES OF ONE READ, and they ship together because either one
## alone is a lie. [method AiPlayer._attack_choice] lists their untapped
## CREATURES as the blockers an attack is priced against, so a Mishra's
## Factory with {1} open is invisible to the cohort and to the crack-back
## model, and a Grizzly Bears walks into a 2/2 that eats it for a mana
## (reproduced 2026-09-10). And no rung animated a Factory to BLOCK at
## all: [method AiPlayer._animation_value] prices an animation by the
## attack it enables and returns 0.0 at every moment but our own first
## main phase, so on their turn the same three lands sat untapped while
## a Grizzly Bears hit us for two (reproduced the same day, `declared 0
## block(s)`, three untapped lands). Ship only the first and the pilot
## grows timid about a body the AI across the table never actually makes;
## ship only the second and it makes a body the reading opposite still
## cannot see. Together they are one fact about the same permanent.
##
## On, the attack declaration is made with their affordable animations
## HUNG ON under the journal — the same probe shape [member
## animates_to_attack] uses, and for the same reason: one reader for the
## price and the declaration — and the block is bought at the moment
## [method AiPlayer._defensive_combat_response] already owns, once their
## attackers are declared, when the declaration itself says the body
## would be used and would come back ([method
## AiPlayer._would_block_once_animated]). Off, a manland is a land.
##
## Sorcerer and Wizard, with [member animates_to_attack] and [member
## plays_engines] — the same layer of play, mana spent to make a body
## that was not there. The Factory is rare in the 1997 lists and common
## in the tournament ones. Nothing here names a card: the shape is
## [member EffectIntent.animates] read off the ability's own effects,
## and the price is their open mana counted the way [method
## AiPlayer._shieldable] already counts it — untapped permanents, public
## to both seats.
var reads_manlands := false

## THEIR PUMPS ARE PUBLIC (2026-09-10): does this profile read the
## activated pump on a creature it does NOT control as part of that
## creature's size, or take the printed numbers on trust?
##
## [method AiPlayer._shieldable] has counted their open mana against their
## cheapest REGENERATION shield since the block audit, so a Drudge
## Skeletons with {B} up is a wall to every kill this pilot predicts — and
## nothing else on their side of the table was ever read that way. A
## Shivan Dragon with three Mountains open was a 5/5 and a Frozen Shade
## with four Swamps was a 0/1. Reproduced 2026-09-10 on the owner's own
## board: our Grizzly Bears against their 0/1 Shade behind four untapped
## Swamps reads `_attack_risk 0.00` — "we kill it and live" — the swing is
## declared, and the Bears is in the graveyard with the Shade still
## standing and their life still twenty.
##
## On, [method AiPlayer._pump_reach] answers what their body can grow to:
## the cheapest self-targeting [PumpEffect] ability with no tap cost,
## times the activations their OPEN SOURCES pay for — capped by the card's
## own "activate only N times each turn", by the pool being ONE pool
## shared among the bodies of theirs this combat can ask it of, and then
## by the smallest count past which no kill-or-survive answer on the board
## could still change. Forge counts ONE activation, which under-reads a
## Shade badly; counting all of them is the honest read of public mana,
## and the caps are what keep it from being a fantasy — a Shade behind ten
## Swamps facing one Grizzly Bears is read at +2/+2, not +10/+10.
##
## ONLY THE KILL TEST READS IT, never the face damage: a pump that does
## not change who dies is still their mana to spend, and the cohort still
## prices its damage through. The reading enters at [method
## AiPlayer._dies_to]'s own seam, through the bonus parameters that
## predicate already carries, so the attack risk, the block ladder, the
## gang and the crack-back matrices ask one question and get one answer.
##
## AND IT IS ASYMMETRIC, because the Lab said so rather than because the
## design did. Their pump deciding whether THEIR body dies is read
## everywhere. Their pump deciding whether OURS dies is read only where we
## are choosing to SEND a body into it — the two halves of the attack
## declaration — and not where we are choosing to put one in FRONT of it:
## read there, it took a whole block declaration away (three Carrion Ants
## behind six Swamps walking past three Hill Giants) and measured -2.4
## +-2.8 on Mountain Artillery against Vampire Lord, against -0.2 for the
## other half. The reason it is not merely a tuning: a blocker of ours
## that dies to their breath has SPENT their mana, and mana spent killing
## a blocker is mana that did not reach our face — this engine breathes
## fire at the player with an unblocked attacker, on both sides of the
## table. An attacker of ours that dies to it has bought nothing at all.
##
## Sorcerer and Wizard, with the other combat reads. It is the mirror of
## [member pumps_to_attack], which sizes OUR body by OUR open mana and had
## never once feared the same mana on the other side of the table — so a
## profile with one and not the other does to the opponent what it cannot
## see coming. Nothing here names a card: the shape is [member
## EffectIntent.pump_self] read off the ability's own effects, and their
## mana is counted the way [method AiPlayer._shieldable] already counts it
## — untapped permanents, public to both seats.
var reads_pumps := false

## COUNTER BY WHAT THE SPELL DOES (2026-09-10, `docs/forge/casting.md`
## P2): does this profile read the SHAPE of the spell on the stack and the
## answers in its own hand, or price the card with one number and compare
## it with [member counter_threshold]?
##
## [method AiPlayer._try_counter] asked [method Evaluator.card_value]
## against the bar and nothing else, and a printed worth is the wrong
## instrument for the two spells at either end of it. Probed at HEAD, a
## Wizard on eight Islands with a Counterspell in hand:
##
##   Wrath of God 5.00 · Fireball 2.50 · Time Walk 3.00 · Wheel 4.00
##
## — so a Sorcerer (bar 5.5) watched a Wrath of God take four Serra Angels
## off its own table, and every rung let a Fireball for eight resolve at
## eight life, a Time Walk resolve, and a Wheel of Fortune hand the other
## seat seven cards while taking seven away. At the other end it spent the
## Counterspell on a Serra Angel with a Swords to Plowshares in hand and a
## Plains untapped.
##
## On, [method AiPlayer._counter_shape] answers ALWAYS, NEVER or "ask the
## bar" before the bar is asked, and every clause is a shape:
##
##  * ALWAYS a SWEEPER that takes more off our board than off theirs by a
##    2/2's worth ([constant AiPlayer.SWEEP_BAR], the same bar our own
##    sweeps clear); ALWAYS damage aimed at us that is lethal or crosses
##    the panic line, the X on the stack read as it was paid; ALWAYS a
##    draw at OUR library that decks us; ALWAYS an extra turn; ALWAYS a
##    wheel ([member EffectIntent.wheels]) while our hand is the fuller.
##  * NEVER when a card in hand ANSWERS the spell later and cheaper — the
##    Terror we hold for their creature, the Disenchant for their
##    enchantment — and the mana to cast it is on the table at their next
##    end step, which is [method AiPlayer._answered_later] and the half
##    that needed the plan and not merely the card. Lifted when the
##    counter is the last card in hand, and never reached at all when an
##    ALWAYS clause has already fired.
##  * Between the two, today's threshold, unchanged.
##
## That is Weissman's rule — *the counter is kept for what nothing else in
## the hand can answer* — and `docs/ROADMAP.md` calls it "a capability of a
## different kind". It COMPOSES with [member ranks_counters] rather than
## replacing it: this knob decides WHETHER a spell deserves a counter, and
## that one decides WHICH counter answers it.
##
## P2's SIXTH CLAUSE — a control-stealing aura on our best creature — was
## measured against the tree and NOT BUILT: [method AiPlayer._try_counter]
## has raised the threat to the worth of any card of OURS the top spell
## targets since long before this knob, so a Control Magic on a Serra Angel
## is already priced at the Angel's 10.00 and countered at every rung. A
## second copy would fire only on a steal the bar itself refuses. The board
## is pinned on both arms in
## `tests/ai/test_ai_counters_by_shape_2026_09_10.gd`.
##
## Nothing here names a card. The sweep is [member EffectIntent.sweeper]
## with the engine's own kill rule put to both boards, the burn is
## [method EffectIntent.damage_at] at the stack's own X, and the answer in
## hand is [method EffectIntent.answers_creatures] with the planner asked
## whether the mana will be there.
##
## [forge] the instinct is `ComputerUtil.shouldCounterSpell` and the
## ApiType categories of `AiController.canPlayAndPayFor`
## (forge-ai/src/main/java/forge/ai/ComputerUtil.java, commit b09a3d3f):
## a type reading beats a cost reading. Its CMC buckets are not copied
## (`docs/forge/casting.md` §10) and neither are its magic numbers.
var counters_by_shape := false

## "X EQUALS MY LIFE" (2026-09-10, `docs/forge/casting.md` P6): does this
## profile know that life can be spent as mana when the mana is lethal?
##
## Channel opens a mana source paid for in life
## ([member MtgPlayer.life_for_mana]), and no seat had ever paid a point:
## the card is a card-local effect, so [member EffectIntent.adds_mana] was
## false, the Dark Ritual gate never asked about it, and it was cast as a
## plain three-point spell. Probed at HEAD — a Wizard holding Channel and
## Fireball with two Forests and a Mountain, the opponent at twenty — the
## pilot cast Channel into an empty board on the spot, paid no life, and
## finished the turn with the Fireball still in hand and the Channel in
## the graveyard.
##
## On, a life-for-mana spell is cast ONLY in a step where the life it
## opens makes an X burn in hand lethal ([method
## AiPlayer._life_mana_enables]), and once it is open the life is paid and
## the burn fired in ONE action ([method AiPlayer._lethal_life_mana]), so
## no rung can pay life for mana it then fails to spend. The life is capped
## at what leaves us alive after their board's next unblocked swing —
## `life − 1 − their attack` — because a Fireball that wins is a Fireball
## cast from at least one life.
##
## Sorcerer and Wizard. Forge never gets here at all: Channel is
## `AI:RemoveDeck:All` there and `willPayCosts` keeps a margin of four
## (`docs/forge/casting.md` §8), so this is ours.
##
## THE DEFENDER'S HALF OF P6 IS NOT HERE, and both reasons are on the
## record. The counter against a lethal X spell is one of
## [member counters_by_shape]'s ALWAYS clauses, exactly as P6 asks ("counts
## it as ALWAYS (P2)") — one line, one knob. And the Circle of Protection
## in the prevention window DID NOT REPRODUCE: with the 1997 fork on
## (`RulesOptions.damage_prevention_window`, `--rules fifth`) the shipped
## pilot already answers a Fireball for six at six life with the Circle and
## lives, because [method AiPlayer._packet_worth] prices a packet that
## kills us at [constant AiPlayer.LETHAL_WORTH]; with the fork off there is
## no window for any seat to act in. Nothing was built for it.
var reads_lethal_x := false


## THE ONE-PLY VETO (2026-09-10; the Forge study's casting note P8, and
## Forge's own `OnePlaySafetyChecker`): does this profile look at the
## POSITION a cast would leave it in — after the spell resolves and after
## the one answer the table is already showing has been taken — before it
## commits to the cast?
##
## A CAPABILITY, like [member holds_instants] and [member plays_engines].
## [method AiPlayer._try_cast_best] prices a cast by what the card is
## worth and what its victim is worth ([method AiPlayer._cast_value]) and
## never by the position afterwards, so a Savannah Lions was cast into an
## untapped Prodigal Sorcerer and pinged off the table before it had
## blocked once — the card gone, the board unchanged, and the pilot
## reading the cast as a gain. Reading one ply out is a whole layer of
## play and the top of the ramp is where it belongs: it is the layer a
## player NOTICES, the seat that stops walking into the answer standing
## on the table.
##
## It is the cheapest form of simulation a headless GDScript engine can
## afford — no game copy, one arithmetic projection of
## [method Evaluator.position_score]'s own terms per candidate
## (`docs/forge/casting.md` §6.4).
var checks_before_casting := false
## SAFE BLOCK, THEN FINISH IT (2026-09-10): once the block ladder has put
## a body in front of an attacker and the attacker LIVED, does this
## profile come back with a second body that finishes it?
##
## [method AiPlayer._best_block_for] is a ladder and it RETURNS on the
## first rung that answers. The free absorb (rung 1.5, "a wall soaks the
## hit at zero cost — what walls are FOR") therefore pre-empts the value
## trade below it and the gang below that: with a Wall of Stone on the
## table the wall blocks alone, every time, and the trade or the gang that
## would have KILLED the attacker is never reached. Reproduced 2026-09-10
## on two boards, both of them a survivor and a body left standing at
## home:
##
## [codeblock]
## their Serra Angel 4/4    ours: Wall of Swords 3/5, Wall of Swords 3/5
##     _plan_blocks -> ["Wall of Swords"] ; band kills it: false
##       + Wall of Swords -> kills it: true ; that body dies: false
##
## their Craw Wurm 6/4      ours: Wall of Stone 0/8, Water Elemental 5/4
##     _plan_blocks -> ["Wall of Stone"] ; band kills it: false
##       + Water Elemental -> kills it: true ; that body dies: true
## [/codeblock]
##
## The first of those costs NOTHING — two walls that both live through a
## Serra Angel and together deal it exactly four — and the pilot declined
## it for a year.
##
## On, [method AiPlayer._reinforce_blocks] runs once over the finished
## plan: for every attacker met by a band that survives it and does not
## kill it, the SAFE bodies first (bodies that live through the attacker
## at the size the gang makes it) and then, only if the safe ones do not
## finish the job, ONE body that dies to close the kill exactly — and that
## one is priced. [forge] `AiBlockController.reinforceBlockersToKill`
## (`AiBlockController.java:795-858`, commit `b09a3d3f`,
## docs/forge/combat.md P4) is the shape, with one thing tightened: Forge
## adds its safe bodies whether or not the attacker ends up dead, and this
## commits nothing unless the band it builds actually kills — a body added
## for nothing is a body exposed to a combat trick for nothing.
##
## THE PRICE IS WHAT THE BLOCK PUTS AT RISK, which is the rung 3 rule
## ([method AiPlayer._best_block_for], `price <= attacker_value * 1.5`)
## asked of the pair the reinforcement makes: the bodies of that pair that
## DIE, against the attacker's worth. The survivor already on the
## attacker is not spent and is not charged — but it is re-asked at the
## size the gang makes the attacker, so a rampage that turns the pair into
## two corpses is charged for both ([member reads_gaze] owns that number).
## Forge's own bound is kept on top of it: the body that dies must be
## worth strictly less than the attacker it kills.
##
## Sorcerer and Wizard, with the other combat reads. Nothing here names a
## card: the shape is a band that survives without killing, and every
## predicate in it — [method AiPlayer._band_kills], [method
## AiPlayer._dies_to], [method AiPlayer._shieldable] — is one the ladder
## above it already asks.
var reinforces_blocks := false

## THE CRACK-BACK ASKED BELOW LETHAL (2026-09-10): how far under our own
## life total the counter-swing has to reach before [method
## AiPlayer._search_hold_back] is worth running.
##
## The search's gate is `reach >= life` and it is exact — if every
## creature they control connecting still leaves us alive, no attack we
## could declare LOSES THE GAME to the counter-swing. That is a true
## sentence and it is not the only question worth asking: an attack that
## costs us eight life for one point of damage is a bad attack at twenty
## life too, and nothing above the gate ever prices it. The search itself
## has priced life since it was built ([method CombatSearch._fdv], one
## point per point scaled by the share of the remaining total it takes),
## so the change is the GATE and nothing else: run when
## `reach >= life - crack_back_margin`.
##
## 0 is today's gate exactly, and **0 is what every preset ships**.
## Apprentice and Magician have no search at all
## ([member combat_search_nodes] is 0 there), so the number is inert below
## the Sorcerer whatever it says.
##
## THE NUMBERS REFUSED THE RUNG, AND THAT IS THE RESULT (2026-09-10,
## `docs/ai-difficulty.md` §4). `docs/forge/combat.md` P8 asked for the
## Wizard at [member chump_threshold]'s 6 and said plainly that this is
## the THIRD attempt at a question two earlier brakes failed. Swept at
## 0/6/10 over twenty arms, seed 11, control PASS byte-identical in every
## one of them: not a single delta is clear of its interval, the flips are
## a coin (212 won to 228 lost at 6, 330 to 360 at 10), and where the knob
## moves a deck systematically it moves the CREATURE deck the wrong way —
## Big Green against Blue Skies −2.4 then −4.3, a green deck that stops
## attacking into a deck it cannot block anyway. So the gate stays where
## it was and the field stays, the way [member w_hand] stayed: the
## question is now one Deck Lab command instead of a patch to this file.
## THE COST WAS NEVER THE PROBLEM — the wider gate measured 0.96x and
## 0.92x the null's seconds per game on one pair and 0.94x and 1.06x on
## another, against P8's budget of two — because opening the gate does not
## make one declaration dearer ([constant CombatSearch.MIN_SLICE] and
## [member combat_search_nodes] are untouched), it runs the same search on
## SMALLER boards, which are the cheap ones.
##
## What the question needs is a reading of the RACE and not a lower bar:
## the swing the reproduction refuses is a 4/4 flier they cannot block
## trading four damage for twelve, which is `reads_race`'s row
## (`docs/AI-next-wave.md`, combat P1) rather than this gate's.
var crack_back_margin := 0

## DEVELOP AFTER COMBAT (2026-09-10): does this profile keep its hand shut
## until the attack is over?
##
## **EVERY PRESET SHIPS `false`, which is the pilot unchanged.** The row is
## built, tested and measurable from one Deck Lab command, and the numbers
## refused the rung — see THE LAB SAID NO below and
## `docs/ai-difficulty.md` §4.
##
## THE REPRODUCTION IS REAL AND IT IS NOT A NUMBER.
## [method AiPlayer.act] reaches [method AiPlayer._main_phase_action] in
## EITHER main step and the first one it reaches is Main 1, so every land,
## creature, artifact, enchantment, draw spell, discard, tutor and Regrowth
## this pilot has ever played went down BEFORE its own combat — and with
## it the mana. At HEAD, a Wizard on four Forests with an Ironroot Treefolk
## in hand and a Grizzly Bears already on the table:
##
## [codeblock]
## MAIN1 act -> 'played a land'          (untapped lands 5)
## MAIN1 act -> 'cast Ironroot Treefolk' (untapped lands 0)
## ...their declare-blockers, with all of it shown and no mana up
## MAIN2: nothing in hand, nothing open
## [/codeblock]
##
## On, the same board reaches Main 2 with the Treefolk still legal
## ([method MtgGame.cast_refusal] answers "" there) and five lands open
## through the combat.
##
## [forge] `PermanentAi.java:38` (commit `b09a3d3f`) is the default —
## `!ph.is(PhaseType.MAIN1) || ... || ComputerUtil.castPermanentInMain1(ai, sa)`
## — and `ComputerUtil.castPermanentInMain1` (`ComputerUtil.java:1141-1297`)
## is the list of exceptions. Ours is that list read off [EffectIntent] and
## the board rather than off a card's `SVar:PlayMain1`
## (`docs/forge/casting.md` §1.7, P1), and it is five sentences
## ([method AiPlayer._main1_worthy]):
##
## 1. A WIN IS NEVER POSTPONED — a cast [method AiPlayer._cast_value]
##    prices at [constant AiPlayer.LETHAL_WORTH] is made now. Main 2 would
##    do as well and a pilot that holds a game it has already won is one
##    bad interaction away from losing it.
## 2. FLOATING MANA IS LOST AT THE STEP BOUNDARY (CR 500.4), so anything
##    in the pool spends now (`:1191-1205`).
## 3. A HASTE CREATURE ATTACKS THIS TURN (`:1217-1220`).
## 4. A MANA SOURCE HELD IS MANA HELD: a non-creature permanent with a
##    printed mana ability — a Mox, a Sol Ring, a Basalt Monolith — goes
##    down before combat. Forge's own line is the zero cost (`:1181`, the
##    Moxen carry `PlayMain1:TRUE`); a mana CREATURE is summoning sick and
##    buys this turn nothing, so it waits with the rest.
## 5. WHAT CHANGES THIS COMBAT ([method AiPlayer._changes_this_combat]):
##    a spell or activation aimed at a permanent THEY control, which is
##    Forge's own first interrupt — removing a blocker lets more attackers
##    through in one's own Main 1 (`:1246-1259`) — and one aimed at a
##    permanent of OURS, the aura or the pump that makes the attack bigger
##    (`castSpellInMain1`'s pump clause, `:1299-1361`); plus a permanent
##    that animates ITSELF into an attacker. All of them ask for an attack
##    to be coming first, Forge's `PlayMain1:TRUE` being literally "when
##    the AI has creatures".
##
## Everything else waits for Main 2, the MANA SINK with it — without that
## last gate the knob defeats itself, because with the hand held
## [method AiPlayer._try_cast_best] answers "" in Main 1 and a Jayemdae
## Tome spends on a card the mana the hold exists to keep open.
##
## THE LAND DROP is held by the same rule
## (`AiController.isSafeToHoldLandDropForMain2`, `:1404-1516`) with Forge's
## own four guards: not on turn 1 or 2 (`:1415-1418`, too obvious), not
## with an empty board (`HOLD_LAND_DROP_ONLY_IF_HAVE_OTHER_PERMS`,
## `:1423`), not when a card in hand becomes castable with it
## (`canCastWithLandDrop`, `:1443`), and NOT WHEN A PERMANENT WE CONTROL
## HAS AN ABILITY THE MANA COULD PAY FOR (`hasRelevantAbsOTB`,
## `:1504-1512`) — that last because this pilot sizes its attack and its
## block by the mana it is holding ([member pumps_to_attack],
## [member reads_manlands]), so a land kept in hand is a Carrion Ants that
## reads one point smaller at the declaration.
##
## THE HAZARD THE ROW CARRIES, AND THE LAB FOUND IT BEFORE THE ARGUMENT
## DID: a cast held for Main 2 is mana that looks open in between, and what
## spends it is THIS PILOT'S OWN ATTACK. Big Green's Llanowar Elves is
## tapped for mana in Main 1 at HEAD and therefore never attacks; with the
## hold on it stands untapped at the declaration and is sent, and the mana
## it makes is gone. Mana sources sent to attack went 1.49 to 3.00 a game,
## the pilot cast a whole spell FEWER each game (7.89 to 6.84) and its
## creature count at turn six fell from 1.60 to 1.39 — and the first sweep
## read −4.7 ±4.4. [method AiPlayer._main2_mana_held] is the answer and it
## is Forge's own (`reserveManaSourcesForMain2` /
## `HELD_MANA_SOURCES_FOR_MAIN2`, `AiController.java:722-757`): the bodies
## the second main phase's cast needs are not sent to attack, the lands
## asked first so a body is held only when it is actually needed. With it
## the same pair reads −0.5 ±4.4 and the development is level again (turns
## ending with a castable card still in hand 42.1% against 41.8%).
##
## THE LAB SAID NO, AND THAT IS THE RESULT. Nine pairs at 1 000 games an
## arm, seed 11, control PASS byte-identical in every one of them: −0.5,
## −0.2, +0.8, −2.0, −0.8, −2.9, −1.1, −3.1, −1.8. Not one delta is clear
## of its interval and EIGHT OF NINE ARE NEGATIVE, a drift of about a point
## and a quarter against the knob — and the PAIRED count is the instrument
## that is clear, because a timing change touches nearly every game: 8,825
## of the 9,000 ended differently and 748 CHANGED HANDS, 316 to a win and
## 432 away, where a fair toss over 748 sits at 374 ± 14. No half of it
## accounts for that: the land drop alone moves 860 games of 1 000 and
## flips one each way, the mana sink alone nothing, and pinning
## [member pumps_to_attack] off on both seats leaves the loss exactly
## where it was. What is left is the timing
## itself — in a Lab where neither seat reads a hand, a hand size or an
## open land as a bluff, the information the hold buys is worth nothing,
## and the pilot pays for it in a board it prices one phase later.
##
## So the knob stays at the null on every preset, the way
## [member crack_back_margin] stayed at 0: the question is one Deck Lab
## command (`--sweep develops_late=on,off --null off`, control
## `DeckLab/README.md`) instead of a patch to this file. What the row
## needs before it can be reopened is an opponent that PUNISHES an open
## board — `holds_tricks` and a hand read (`docs/AI-next-wave.md`) — since
## hiding a card from a seat that never guesses is a cost with no buyer.
var develops_late := false
## WHO IS THE BEATDOWN (2026-09-10): does this profile read the two clocks
## of the race — how many turns we need to kill them, how many they need
## to kill us — and let the difference move what a voluntary BLOCK TRADE
## is allowed to cost?
##
## Rung 2 of [method AiPlayer._best_block_for] takes a trade nothing
## forces on it whenever the body it spends is worth no more than
## `attacker_value + 0.5`, and that margin is the same number at twenty
## life as at four. Reproduced 2026-09-10, one board and its mirror:
##
## [codeblock]
## their Craw Wurm 6/4 | our Serra Angel 4/4, us at 20 and them at 4
##     our_clock 1, their_clock 4 -- we win next turn
##     block: [Serra Angel] -- the body that wins the game, given away
##
## their Erhnam Djinn 4/5 | our Craw Wurm 6/4, us at 8 and them at 20
##     our_clock 4, their_clock 2 -- two turns from dying
##     block: [] -- the Wurm is worth ONE POINT more, so it lets it through
## [/codeblock]
##
## On, [method AiPlayer._trade_margin] moves that margin in the three
## states `docs/forge/combat.md` P1 writes: DEMAND A GAIN (−0.5) when
## their clock is more than a turn longer than ours, ALLOW A SMALL LOSS
## (+1.5) when ours is more than a turn longer than theirs, and 0.5 —
## the incumbent — inside a turn of each other or when neither clock is
## inside [constant AiPlayer.RACE_HORIZON]. Both clocks are read off
## public numbers alone: the two life totals and the printed power each
## side could swing with once everything untaps ([method
## AiPlayer._race_reach], the durable half [method
## AiPlayer._could_attack_next_turn] already asks of theirs), so a side
## with no creature has a clock of never and moves nothing.
## [forge] after `AiBlockController.java:1050` (`diff = life * 2 - 5` — a
## voluntary trade must gain more the healthier you are) and
## `AiAttackController.java:1117-1136` (`ratioDiff`) at `b09a3d3f` — read
## as a RACE rather than as a life total, because twenty life in front of
## a board that kills in two is not health.
##
## THE OTHER HALF OF P1 IS BUILT, MEASURED AND REFUSED, and that is the
## larger part of this row's result. P1's headline is the ATTACK bar:
## [method AiPlayer._combat_tolerance] moved by
## `clamp(their_clock - our_clock, -2, +2)` stat points plus one for a
## clock they cannot block (Forge's `turnsUntilDeathByUnblockable`). It
## was built exactly so — with a floor at zero, because a risk of 0.00 is
## a FREE exchange and a negative appetite refuses attacks that cost
## nothing, and with the horizon above — and the Deck Lab said no. Over
## the eight starter matchups it moves most, 1 000 games an arm, seed 11:
## **42 games ended in a win against 170 in a loss**, White Knights
## against Black-Red Raiders −3.1 and Blue Skies against Mountain
## Artillery −1.9. Dropping the evasive clause changed nothing (58 to
## 165); the clamp itself is what moves the deck it should have left
## alone, which is the risk P1 names in its own Risk paragraph and the
## third time this month one number has been asked to carry a brake.
## Under the SAME eight matchups the block half alone reads 16 won to 17
## lost with every delta between −0.2 and +0.2 — a wash, and the wash is
## what ships. `docs/ai-difficulty.md` §4 has all four arms.
##
## Sorcerer and Wizard, with the other combat reads. Nothing here names a
## card, and nothing is read that the seat may not see.
var reads_race := false

## THE TRICK'S MANA, BOOKED (2026-09-10): does this profile keep the mana
## for a pump instant in hand open through its own combat, so that the
## body it sent on the strength of the trick can actually be saved?
##
## [method AiPlayer._attack_choice] already sends ONE extra body when a
## pump in hand makes the attack sound ([method
## _attack_is_reasonable]'s `bonus`), and [method
## AiPlayer._offensive_combat_response] already spends the pump to win a
## block. What sits between them is the first main phase, which knows
## nothing about either: [method AiPlayer._held_reserve] books removal, a
## draw and a counterspell and skips a pump outright (`or intent.pumps`),
## so the {G} of a Giant Growth is spent on a Grizzly Bears and the trick
## is a dead card for the turn. Measured on HEAD before a line was
## written, 200 games of Big Green against White Knights: the pilot
## reached declare-blockers holding a pump instant 2,051 times and in
## **531 of them (25.9%) could no longer pay for it**.
##
## On, the pump's cost joins the reserve every sorcery-speed cast is
## already priced against — but only where the trick has a JOB: only on
## our own turn, only before the blocks are in, and only when there is a
## body of ours that the pump makes a sound attacker and that is not one
## without it ([method AiPlayer._trick_bait], which is the rider's own
## question asked one phase earlier). An empty board on the other side
## books nothing, because with nothing to block us every attack is
## already sound. Its worth is the bait's own worth, so [method
## AiPlayer._try_cast_best]'s 1.5x rule lets a clearly better cast go
## ahead of it, exactly as it does for a held Counterspell.
## [forge] after `ComputerUtilCard.java:1593-1607` (the held mana sources
## for declare-blockers) at `b09a3d3f`, `docs/forge/combat.md` P5 and
## `docs/forge/casting.md` P13 — without Forge's 65% roll, which is a
## personality and not a capability (`docs/forge/combat.md` §10).
##
## P5's OTHER HALF DID NOT REPRODUCE and is not built: "remember the
## body's id for the turn so the offensive response prefers it" answers a
## question the pilot is almost never asked. Over those same 200 games the
## response found TWO OR MORE of its own attackers that the pump could
## save in exactly ONE declare-blockers step, because the rider sends one
## bait and the cohort's own bodies are the ones it already priced as
## sound. Re-measured on the tree that books the mana it is 2 in 200.
##
## Wizard only: a trick held through a combat is the last rung of the
## reactive ramp, and it composes with [member holds_instants] rather than
## widening it — the reservation is a subset of what that knob may already
## keep open.
var holds_tricks := false


## THE HAND UNDER A SQUEEZE AND THE BOARD UNDER A PRISON (2026-09-10,
## `docs/forge/casting.md` P4, `docs/arzakon.strategy` §4 items 2 and 3).
##
## Two printed shapes on THEIR side of the table that this pilot has never
## read, and both of them decide what our own hand should be doing:
##
##  * THE SQUEEZE — a permanent whose upkeep trigger deals damage counted
##    off the cards in a hand ([method EffectIntent.hand_toll_of_line]).
##    Reproduced at HEAD: a Wizard holding seven cards with a Black Vise
##    across the table went on drawing (the Tome's tick is offered at a
##    hand of five, where `_draw_need` returns exactly 0.00) and cast by
##    printed worth alone, so nothing about the three damage a turn
##    reached a single decision.
##  * THE PRISON — a permanent of theirs whose static holds our creatures
##    at home (`CardInstance.cur_cant_attack`, set by a static and by
##    nothing else — the reading [method AiPlayer._ground_the_sweep_opens]
##    already makes). A Moat is priced by [method Evaluator.permanent_value]
##    at 3.20, a four-mana enchantment's flat cost-times-0.8, whatever it
##    is holding back.
##
## Three readings, and the null is the pilot unchanged because each one is
## zero with no such permanent on the table:
##
##  1. THE ROOM ([method AiPlayer._vise_room]): the cards our hand can
##    still take before the squeeze charges for them — under a Black Vise,
##    the room up to four and no further, so no Ancestral, no Tome tick
##    and no wheel is drawn into a hand the card is already counting.
##  2. THE RELIEF ([method AiPlayer._vise_relief]): a cast is worth the
##    point of damage it takes off our next upkeep, charged at the
##    reaper's own rate ([method AiPlayer._life_price], half a point at
##    twenty and two under seven). SIGNED, which is the half
##    `docs/forge/casting.md` P4 has backwards — under a Rack, whose X is
##    three MINUS the hand, emptying the hand is what costs — and read
##    through the hand the card actually leaves us with, so a WHEEL that
##    refills us to seven is charged for the refill instead of credited
##    for the cast.
##  3. THE PRICE ([method AiPlayer._prison_relief]): what taking the
##    permanent off the table is worth, on the same scale the pilot
##    prices damage at everywhere else — the squeeze's next beat, ours
##    minus theirs so a symmetric toll is worth only the difference, and
##    the prison's held attack read as the damage the freed bodies would
##    put through their blocks. Before it, one Disenchant against a Black
##    Vise and a Jayemdae Tome went to the TOME (4.20 against 1.00) and
##    left the Vise squeezing.
##
## WHAT IS NOT BUILT, and the reason is a ruling this repository already
## made. P4 asks for the Vise priced "at the damage it will deal over
## `PACE_HORIZON` turns" — a STREAM times a horizon, and there is no
## horizon in this engine (`docs/ai-difficulty.md` §5, and the census at
## [constant EffectIntent.TOLL_BEATS] that closed the same question for
## [member prices_liabilities] on 2026-09-10). Every reading here prices
## ONE BEAT, which is a number the table is showing.
##
## AND [member counts_the_race] LANDED THE SAME DAY AND ANSWERED NO, which
## closes this rather than deferring it: the only clock this engine can
## count forward honestly is the DECKING one, because a library is the one
## resource that never grows back. A toll's stream is not that, so it
## stays one beat and this is the reading, not a stand-in for a later one.
var minds_the_vise := false


## THE OFFER (2026-09-11) — does this profile PRICE a "you may pay"
## before it answers it?
##
## THE PILOT HAD NEVER ANSWERED ONE. [method DecisionAgent.answer_yes_no]
## returns the card author's hint, [AiPlayer] overrode it with nothing,
## and 68 card files put such a question to a seat: every offer in the
## pool was answered by whatever its author wrote as the default, which
## for a mana price is almost always "can we afford it". Reproduced at
## HEAD, a Wizard in seat 0 with four TAPPED Mana Vaults, a Sol Ring, a
## Mox Ruby, three Mountains and an Island — seven mana on the table and
## a Fireball in hand:
##
##     [Upkeep] Pay {4} to untap Mana Vault? — yes   (x4)
##     -> Vaults untapped: 1 of 4
##     -> mana left for the whole turn: 3      (declined: 7)
##     -> our life: 13                         (declined: 12)
##
## It spent the board to untap ONE Vault, arrived at its own first main
## phase with three mana instead of seven, and bought one point of life
## with four. The Fireball went from X=6 to X=2 for it.
##
## THE ONE READING, AND WHY THERE IS EXACTLY ONE. An offer has two halves
## — what it takes and what it buys — and the two are comparable only
## when they are in the SAME CURRENCY at the SAME BEAT. A mana price
## against a mana source is: pay {4} this upkeep, have {C}{C}{C} this
## upkeep, and be asked again next upkeep. Nothing is projected forward,
## so the horizon this repository has now refused four times
## ([method AiPlayer._liability_price], [constant
## EffectIntent.TOLL_UNKNOWABLE], [member minds_the_vise], [member
## counts_the_race]) is not needed and not invented.
##
## Every OTHER shape in the survey is a STOCK against a STREAM and is
## ruled unreadable for that reason, not left for later:
##
##  * PAY-OR-LOSE-A-PERMANENT (an upkeep rent: Cosmic Horror's
##    {3}{B}{B}{B}, the five Elder Dragon Legends, The Tabernacle at
##    Pendrell Vale, Forethought Amulet, Rohgahh of Kher Keep, Dance of
##    Many, Scarwood Bandits). The rent is charged every upkeep and the
##    permanent is kept ONCE: pricing it needs the turns the game has
##    left, and no reader in this engine estimates that. THE ONE
##    EXCEPTION IS WHY THIS SHAPE IS HERE AT ALL AND NOT ONLY THE UNTAP:
##    when the permanent rented is itself a mana source, both halves are
##    streams and the horizon cancels — an Energy Flux charging {2} a
##    turn for a Mox that makes one is a mana down every upkeep, and
##    charging {2} for a Sol Ring is a wash the pilot pays.
##  * PAY-OR-SOMETHING-HAPPENS-TO-YOU (Naf's Asp, Primordial Ooze,
##    Mishra's War Machine, Chain Lightning's copy, Tempest Efreet's
##    ante) — mana or a card against damage or a life total, two
##    currencies with no rate between them that this engine carries.
##    [method AiPlayer._pain_excluded] is the whole of what it does
##    carry, and it fires only where the pain would KILL us.
##  * PAY-TO-UNTAP A BODY (Brass Man, Island Fish Jasconius, Paralyze's
##    host, Magnetic Mountain's) — mana against a creature's turn, which
##    is a block, an attack, or neither, and is the combat search's
##    question rather than a price.
##  * PAY-TO-KEEP-AN-EFFECT, the spell tax (Force Spike, Nether Void, In
##    the Eye of Chaos, Invoke Prejudice) — the mana is already
##    committed when the question is asked, so "can we afford it" IS the
##    answer and the hint is right.
##  * PURE UPSIDE, which is over half of the 68 (the six life rods,
##    Verduran Enchantress's draw, Nether Shadow's return, Eureka,
##    Gaea's Touch, Sylvan Library's two cards). Nothing is taken, or
##    what is taken is spare; these DESERVE NO READING and get none.
##
## WHAT THE KNOB THEN DOES, in [method AiPlayer.answer_yes_no], and it
## can only ever turn a YES into a NO, and only at a beat that comes round
## on its own ([constant AiPlayer.OFFER_BEATS]), which is what makes the
## price a RENT rather than a purchase made once. The price is read off
## the offer's own line ([method EffectIntent.offer_price], the parser
## [method EffectIntent.toll_of_line] already uses on a printed trigger);
## the subject is the permanent OF OURS the question is about, found by
## matching the question against the names on our own table rather than
## against anything written in this repository (58 of the pool's 70 offers
## put that name in the question — [method AiPlayer._offer_subject]); and
## the reading fires only where that permanent's whole worth is the mana
## it makes ([method AiPlayer._makes_only_mana] — not a creature, not a
## land, and nothing it does survives being tapped). Then: refuse a price
## the source cannot make back, unless the damage the offer escapes
## covers the gap at the reaper's own rate ([method AiPlayer._life_price],
## so a Mana Vault IS untapped at twelve life and below, where the point
## it saves is worth the mana it costs).
##
## WHAT THE POOL PUTS ON IT, counted rather than claimed
## (`tests/ai/test_ai_prices_offers_2026_09_11.gd`): twenty-four cards
## print a mana escape at one of the beats and exactly ONE of them is a
## mana-only permanent — Mana Vault, the card `b3d3f18` measured its own
## regression on — and seventeen permanents in the pool make only mana,
## which is what an upkeep rent granted from outside (Energy Flux's {2} on
## every artifact) can be put about.
##
## A CAPABILITY, like [member counts_cards] and [member counts_the_race],
## and not a difficulty concept: counting what a price buys before paying
## it is a layer of play, and the bottom two rungs paying every rent they
## can afford is the same honest weakness as the Apprentice never holding
## an instant. Sorcerer and Wizard. It is deliberately NOT [member
## prices_liabilities]' third growth, which would have been the easy
## move: that knob prices a PERMANENT and is on for every profile, so an
## answer riding inside it could never be measured apart from the Lich
## reading, and every published `prices_liabilities` number would have
## gone stale the day this shipped.
var prices_offers := false


## THE OLD LOOPS (2026-09-10, `docs/forge/casting.md` P5,
## `docs/arzakon.strategy` §3C and §4 item 6) — Time Walk priced as a
## turn, Regrowth aimed at it, and the wheel priced by the two hands
## instead of by its printed worth.
##
## THREE THINGS REPRODUCED AT HEAD, all three at the same seam — a card
## whose worth is a fact about the BOARD was priced by
## [method Evaluator.card_value], which reads the printed card and nothing
## else:
##
##  * A WHEEL OF FORTUNE PRICES AT 4.00 EITHER WAY ROUND. With our hand at
##    seven and theirs at nothing it is a gift of six cards; with ours at
##    one and theirs at seven it is a gain of six. The pilot read 4.00 for
##    both.
##  * TIME WALK PRICES AT 3.00 WITH THREE SERRA ANGELS ON THE TABLE — an
##    extra turn worth twelve damage, a draw and a land drop, priced at a
##    Counterspell. This is the flat 3.0 `docs/arzakon.strategy` §5
##    complains of, measured.
##  * A REGROWTH WITH TIME WALK AND A SERRA ANGEL IN THE GRAVEYARD TAKES
##    THE ANGEL, every time, because 10.00 beats 3.00 and the pick is
##    [method Evaluator.card_value] alone.
##
## On, all three are priced from what the seat can see and none of them by
## a name: an extra turn is a draw step plus a land drop plus the attack
## the board would make again ([method AiPlayer._extra_turn_value]); a
## fixed-count wheel is worth the cards it MOVES, `their hand − ours` once
## the wheel itself has left our hand (CR 608.2m), and is refused when
## that is negative ([method AiPlayer._wheel_swing]); and a card in our
## own graveyard is offered to a "return a card" spell at what casting it
## on THIS board would be worth ([method AiPlayer._graveyard_worth]).
##
## THE LOOP IS THE THREE READINGS AND NOT A FOURTH RULE. With a returner
## in hand the extra turn is credited the card it does not spend, which is
## what puts Time Walk ahead of the Regrowth in the same main step — so
## the Walk is in the graveyard when the Regrowth is cast, and the
## Regrowth takes it back. `docs/arzakon.strategy` §3C's loop is that
## sequence with a Timetwister to find the pieces again, and every step of
## it is a shape ("extra turn", "return a card", "each player discards and
## draws"), never a card name.
##
## Wizard only, with [member counts_cards] and [member paces_draws], whose
## guards run FIRST and are untouched: a wheel that our library cannot pay
## for and an extra turn the library race cannot spare are still refused
## before any of this is asked.
var runs_loops := false


## THE CLOSER HELD UNTIL THE BOARD IS LOCKED — the finisher rule of
## docs/ROADMAP.md's "THE DECK, THIRD PASS" §6, built whole and shipping
## at its null on every preset (2026-09-10).
##
## NOT A DIFFICULTY KNOB and no rung moves it, exactly as
## [member develops_late] and [member crack_back_margin] are not: the
## field is here so the Deck Lab can put the question in ONE command
## (`--sweep holds_the_closer=on,off --null off`) instead of a patch to
## this file. What it gates is [method AiPlayer._holds_the_closer] — a
## creature kept in hand while a counter is held, our own table is the
## slower clock and their attackers still out-run the body, released when
## a static of ours grounds their attack or a feeder eats it.
##
## THE LAB SAID NO, and the number that refused it is not the pair the
## rule was written for: on The Deck's own Serra variant it is a wash
## inside its interval, and on the one STARTER that holds a counterspell
## beside its creatures it is a loss — Blue Skies gives up about a point
## and a quarter across its four matchups, because a flier deck's
## Mahamoti Djinn is its clock and not its finisher. A capability is as
## good or better one rung up; this one is not. The OTHER half of the
## same rule — the appetite already on the table
## ([method AiPlayer._fed_on_arrival]) — measured as a wash that removes a
## malfunction and ships inside [member checks_before_casting], where it
## belongs.
var holds_the_closer := false
## THE DECKING COUNT (2026-09-10, `docs/forge/casting.md` P3,
## `docs/arzakon.strategy` §4 item 4) — the race to the empty library read
## in TURNS instead of in CARDS, and the one clock in this engine that a
## board cannot revise.
##
## [member paces_draws] already reads the two libraries as a race
## ([method AiPlayer._library_slack]) and it counts CARDS, which is exactly
## right while each side loses one a turn: a draw step takes one card from
## each library in turn, so a lead in cards IS a lead in turns. A MILL
## breaks that equality — the rates stop being the same number — and every
## reading built on it is then wrong by the ratio.
##
## FOUR THINGS REPRODUCED AT HEAD, and the first is not a mispricing but a
## whole decision the pilot has never made:
##
##  * A MILLSTONE IS NEVER ACTIVATED. `{2}, {T}: target player mills two
##    cards` reaches [method AiPlayer._ability_option] and falls out of its
##    last `else` — pumps, regeneration, mana, untaps, unknowns — because
##    nothing there has an arm for an effect whose payload is a card off a
##    library. With the opponent's library at TWO, where the mill is the
##    game (they lose at their next draw, CR 704.5b), the option is still
##    `{}` and the Millstone stays untapped. Not one card has ever been
##    milled in this AI's life.
##  * OUR OWN MILLSTONE MAKES NO DIFFERENCE TO THE PACE. With our library
##    at 12 against their 30 and a Millstone of ours on the table, the race
##    is ours by two turns (theirs is 10 turns at three cards a turn, ours
##    is 12) — and [method AiPlayer._library_slack] answers `1 << 20`, "the
##    race is lost already, draw for value", because 12 − 30 is negative.
##  * THEIR MILLSTONE IS PRICED AT 2.60 WHILE IT KILLS US. With our library
##    at 6 the one Disenchant in hand took a Jayemdae Tome (4.20) and left
##    the Millstone milling. The same malfunction [member minds_the_vise]
##    found one row over, in the other currency.
##  * A TIMETWISTER IS CAST INTO A LIBRARY WE HAVE EMPTIED. Ours at 40,
##    theirs at 3 with twenty cards in their graveyard: 11.50, cast, and
##    their library comes back at 21. That is `docs/arzakon.strategy` §4
##    item 4 word for word.
##
## On, all four are answered from ONE reading and no card is named. The
## rate a library loses cards at ([method AiPlayer._mill_rate]: the draw
## step, plus every repeatable mill on the table aimed at that seat) turns
## the library into a number of TURNS ([method AiPlayer._deck_clock]); the
## pace counts those turns instead of cards; a mill is bought at
## [constant AiPlayer.LETHAL_WORTH] when it decks them and at what a card
## is worth otherwise; taking a mill of theirs off the table is worth the
## cards it hands us back ([method AiPlayer._mill_relief]); and a wheel
## that shuffles the GRAVEYARDS back ([member EffectIntent.wheel_recycles])
## is refused when it would hand back a race we hold.
##
## THE HORIZON, WHICH IS THE REAL QUESTION OF THIS ROW AND IS ANSWERED
## NARROWLY ON PURPOSE. Four rows of 2026-09-10 asked this knob for "how
## many turns has this game left" — the land sweep's rebuild, the wall that
## blocks forever, the Disk under our own Moat, the Vise's stream — and the
## answer is that only ONE clock in this engine can be counted forward
## honestly, and it is this one. A library is MONOTONE: it only ever
## shrinks, the draw step is a rule rather than a choice, and a mill on the
## table mills again next turn unless somebody removes it. Every other rate
## the engine can see is revisable within a turn — a combat clock changes
## when a creature is cast or dies (which is why [constant
## AiPlayer.RACE_HORIZON] saturates at four turns), a toll stops when its
## permanent leaves, and what a Moat still answers is a question about the
## cards left in a library, which this AI is not allowed to look at. So
## there is no general turn horizon here and this knob does not invent one.
## What it brings is the decking clock and nothing else, bounded by
## [constant AiPlayer.PACE_HORIZON] — the horizon the libraries already
## had, and the sentence it was written to say: a game that has not ended
## in twenty turns of draw steps is being decided by the libraries.
##
## Sorcerer and Wizard, beside [member counts_cards] and [member
## paces_draws], whose guards it corrects rather than replaces: with no
## mill on either battlefield [method AiPlayer._mill_rate] is 0, the pace's
## arithmetic is the integer expression it has always been, and every
## reading below is the number it was before this knob existed.
var counts_the_race := false


func _init(p_name := "Custom", p_mistakes := 0.0, p_aggression := 0.5,
		p_chump := 5, p_holds := true, p_counter_threshold := 5.0,
		p_sideboard_swaps := 0, p_search_nodes := 0,
		p_engines := false, p_sacrifices := false, p_timed := false,
		p_counts := false, p_levels := false, p_paces := false,
		p_duplicates := false, p_animates := false, p_times_sweeps := false,
		p_trusts_abyss := false, p_pumps_to_attack := false,
		p_spends_counters := false) -> void:
	profile_name = p_name
	mistake_chance = p_mistakes
	aggression = p_aggression
	chump_threshold = p_chump
	holds_instants = p_holds
	counter_threshold = p_counter_threshold
	sideboard_swaps = p_sideboard_swaps
	combat_search_nodes = p_search_nodes
	plays_engines = p_engines
	pays_sacrifices = p_sacrifices
	casts_timed_spells = p_timed
	counts_cards = p_counts
	levels_boards = p_levels
	paces_draws = p_paces
	holds_duplicates = p_duplicates
	animates_to_attack = p_animates
	times_sweeps = p_times_sweeps
	trusts_abyss = p_trusts_abyss
	pumps_to_attack = p_pumps_to_attack
	spends_counters = p_spends_counters


## Apply `knob=value` overrides — `pays_sacrifices=off`, `aggression=0.7`,
## `counter_threshold=4` — to this profile, returning the first name that
## is not a knob (or "" when every one applied). Booleans read on/off,
## true/false, 1/0; numbers read as the knob's own type. It is how the
## Deck Lab's `--profile-a wizard:pays_sacrifices=off` names a CANDIDATE
## against the shipped pilot without a scratch patch to this file, which
## is what every measurement in docs/ROADMAP.md needed and had to
## improvise.
func apply_overrides(spec: String) -> String:
	for part in spec.split(",", false):
		var eq := part.find("=")
		if eq < 0:
			return part
		var knob := part.substr(0, eq).strip_edges()
		var raw := part.substr(eq + 1).strip_edges().to_lower()
		if knob == "profile_name" or knob.is_empty() or get(knob) == null:
			return knob
		var current = get(knob)
		match typeof(current):
			TYPE_BOOL:
				set(knob, raw in ["on", "true", "1", "yes"])
			TYPE_INT:
				set(knob, int(raw.to_float()))
			TYPE_FLOAT:
				set(knob, raw.to_float())
			_:
				return knob
	return ""


# THE PRESETS. A knob added since 2026-09-10 is set on the built profile
# by NAME rather than threaded through [method _init]'s positional tail:
# the tail is twenty arguments of bare `true`, and two knobs landing in it
# from two branches at once is a silently scrambled preset rather than a
# merge conflict anyone can see. Named assignment reads the same and
# cannot be misread.


## Lowest difficulty: fumbles a third of its actions, swings recklessly, and
## never holds up instants — sorcery-speed Magic, which is the honest way to
## be weak without cheating the rules.
static func apprentice() -> AiProfile:
	return AiProfile.new("Apprentice", 0.35, 0.75, 3, false, 5.0, 0, 0, false)

## Second difficulty: reactive play switches on, but the high counter
## threshold means it only answers the biggest threats and lets the rest
## resolve.
static func magician() -> AiProfile:
	var profile := AiProfile.new("Magician", 0.20, 0.60, 4, true, 7.0, 2, 0, false)
	profile.ranks_counters = true
	return profile

## Third difficulty: rarely fumbles, plays a balanced game.
##
## A KNOB ADDED AFTER 2026-09-10 IS SET BY NAME HERE, never appended to
## [method _init]'s positional tail: a twenty-argument call two branches
## both add an argument to is a silently scrambled preset rather than a
## visible conflict, and the tail is long enough already.
static func sorcerer() -> AiProfile:
	var profile := AiProfile.new("Sorcerer", 0.08, 0.50, 5, true, 5.5, 3, 1500, true, true, true, true, true, true,
		true, true, true, true, true, true)
	profile.ranks_counters = true
	profile.holds_x_burn = 3
	profile.reads_gaze = true
	profile.reads_manlands = true
	profile.tutors_for_the_turn = true
	profile.reads_pumps = true
	profile.reads_lethal_x = true
	profile.counters_by_shape = true
	profile.reinforces_blocks = true
	profile.reads_race = true
	profile.minds_the_vise = true
	profile.counts_the_race = true
	profile.prices_offers = true
	return profile

## Top difficulty: no mistakes at all — it plays the same decision code as
## every other profile, just without ever degrading its own choice.
static func wizard() -> AiProfile:
	var profile := AiProfile.new("Wizard", 0.0, 0.50, 6, true, 5.0, 4, 3000, true, true, true, true, true, true,
		true, true, true, true, true, true)
	profile.ranks_counters = true
	profile.holds_x_burn = 5
	profile.reads_gaze = true
	profile.reads_manlands = true
	profile.tutors_for_the_turn = true
	profile.reads_pumps = true
	profile.reads_lethal_x = true
	profile.counters_by_shape = true
	profile.checks_before_casting = true
	profile.reinforces_blocks = true
	profile.reads_race = true
	profile.holds_tricks = true
	profile.minds_the_vise = true
	profile.runs_loops = true
	profile.counts_the_race = true
	profile.prices_offers = true
	return profile


func _to_string() -> String:
	return profile_name

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
	return profile


func _to_string() -> String:
	return profile_name

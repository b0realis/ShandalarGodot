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
## A CAPABILITY, like [member animates_to_attack] — not a second
## difficulty concept, and the same layer of play: mana spent before the
## declaration to make an attack that does not otherwise exist. Sorcerer
## and Wizard, for that reason; the Magician already breathes fire on an
## attacker that got through, because that half hangs off
## [member holds_instants]. Nothing here names a card: the shape is
## [member EffectIntent.pump_self] read off the ability's own effects,
## the price is the planner's, and an ability whose cost is a body or a
## counter stays invisible ([method AiPlayer._ability_available]).
var pumps_to_attack := false


func _init(p_name := "Custom", p_mistakes := 0.0, p_aggression := 0.5,
		p_chump := 5, p_holds := true, p_counter_threshold := 5.0,
		p_sideboard_swaps := 0, p_search_nodes := 0,
		p_engines := false, p_sacrifices := false, p_timed := false,
		p_counts := false, p_levels := false, p_paces := false,
		p_duplicates := false, p_animates := false, p_times_sweeps := false,
		p_trusts_abyss := false, p_pumps_to_attack := false) -> void:
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


## Lowest difficulty: fumbles a third of its actions, swings recklessly, and
## never holds up instants — sorcery-speed Magic, which is the honest way to
## be weak without cheating the rules.
static func apprentice() -> AiProfile:
	return AiProfile.new("Apprentice", 0.35, 0.75, 3, false, 5.0, 0, 0, false)

## Second difficulty: reactive play switches on, but the high counter
## threshold means it only answers the biggest threats and lets the rest
## resolve.
static func magician() -> AiProfile:
	return AiProfile.new("Magician", 0.20, 0.60, 4, true, 7.0, 2, 0, false)

## Third difficulty: rarely fumbles, plays a balanced game.
static func sorcerer() -> AiProfile:
	return AiProfile.new("Sorcerer", 0.08, 0.50, 5, true, 5.5, 3, 1500, true, true, true, true, true, true,
		true, true, true, true, true)

## Top difficulty: no mistakes at all — it plays the same decision code as
## every other profile, just without ever degrading its own choice.
static func wizard() -> AiProfile:
	return AiProfile.new("Wizard", 0.0, 0.50, 6, true, 5.0, 4, 3000, true, true, true, true, true, true,
		true, true, true, true, true)


func _to_string() -> String:
	return profile_name

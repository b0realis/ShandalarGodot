class_name EffectIntent
extends RefCounted
## What a spell's or an activated ability's effect list DOES, read once and
## summed into a handful of numbers the AI can reason about: "3 damage to
## the target and 2 to me", "draws a card", "taps something", "+3/+3".
##
## Ported from mage-go's `intrinsicAbilityQuality` and `bestXValue`
## (`mage-go/pkg/mage/interactive/ai/heuristic/heuristic.go:1074-1232`),
## which classify an ability by what its effects do rather than by which
## card it is on — the reason s30's AI activates a Rod of Ruin it has never
## seen a special case for. Here the classification is by EFFECT CLASS, so
## every card built from the shared effect vocabulary (docs/adding-cards.md)
## is understood for free, and the two tables of card-local effects below
## cover the shapes the shared vocabulary cannot express.
##
## Read-only: nothing here mutates the game, and nothing here holds a
## CardInstance beyond the call that built it.

## Fixed damage to the chosen target (0 = the effects deal none).
var damage: int = 0

## The damage is the spell's X (Fireball, Disintegrate, Rod-of-Ruin-with-X).
var damage_uses_x: bool = false

## Damage SPLIT among the targets (Fireball) rather than dealt to each.
var damage_divided: bool = false

## Damage the CASTER takes as a side effect (Orcish Artillery 3, Psionic
## Blast 2). The price mage-go's `lifeCost*15/life` term charges.
var self_damage: int = 0

## Targeted destroy / exile / "removal-shaped" card-local effect.
var removes: bool = false

## The removal says "can't be regenerated" (Terror) — a shield is no answer.
var removal_ignores_regeneration: bool = false

## Targeted bounce (Unsummon).
var bounces: bool = false

## Targeted tap (Icy Manipulator, Twiddle's main use).
var taps: bool = false

## Targeted untap.
var untaps: bool = false

## Cards drawn (0 = none); [member draws_use_x] when the count is X.
var draws: int = 0
var draws_use_x: bool = false

## Searches the library (a tutor, a land fetch): a card off the library
## the way a draw is, which is all THE PACE ([member AiProfile.paces_draws])
## needs to know; the value of the search is priced by card_value.
var searches: bool = false

## Extra turns the caster takes (Time Walk: one). Each is a draw step off
## our own library before theirs comes round again, which is what THE
## PACE ([member AiProfile.paces_draws]) reads it for (2026-09-08); the
## turn's worth beyond the draw is priced by card_value.
var extra_turns: int = 0

## THE WHEEL (2026-09-10) — a spell that empties EACH player's hand and
## refills it: the number of cards each player is left holding (Wheel of
## Fortune and Timetwister: seven), or [constant WHEEL_REDRAW] when the
## count is each player's own hand size (Winds of Change, a reroll that
## preserves it).
##
## 0 for everything else, and the two deliberate exclusions say what the
## field is: MIND BOMB ("each player discards up to three cards or takes
## the difference in damage") refills nobody, and EUREKA ("each player
## empties their hand of permanents onto the battlefield") is not a draw.
## An "each player discards" is not a wheel until it deals the cards back.
##
## WHY THE COUNT AND NOT A FLAG. The net cards a wheel moves is
## `(N − our hand) − (N − their hand)`, so N cancels and the swing is
## `their hand − our hand` — but only while N is a FIXED number. A reroll
## that gives each player back exactly what it took nets nothing whatever
## the hands hold, and a reader that answered 7 for one would be wrong
## about the other. The count itself is what the hand-size readings that
## come later want (`docs/forge/casting.md` P4: the refill into a Black
## Vise is seven cards of damage, whatever the hands hold now).
##
## Read from the effect's own [method EffectBase.describe] line for the
## reason [method _aimed_discard] is: there is no shared wheel effect in
## this vocabulary — all three are a `class X extends EffectBase` inside
## their own card file — so the reader has nothing to test `is` against,
## and the card's own line is the signal every effect already provides.
## [member unknown] deliberately STAYS set, exactly as it does for the
## aimed discard: every reading that word gates keeps the behaviour it
## had, and only the wheel's own readers consult this.
##
## Its first reader is [member AiProfile.counters_by_shape], which counters
## a wheel that hands the other seat a hand and takes ours away.
var wheels: int = 0

## [member wheels] when each player draws back exactly what it discarded.
const WHEEL_REDRAW := -1

## Targeted or self pump. [member pump_self] for the firebreathing shape;
## [member pump_uses_x] when the power bonus is the spell's X (Howl from
## Beyond) — [member pump_power] then holds only the printed part.
var pump_power: int = 0
var pump_toughness: int = 0
var pump_self: bool = false
var pumps: bool = false
var pump_uses_x: bool = false

## Every keyword the pumps grant (Teleport's UNBLOCKABLE, Jump's FLYING),
## summed the way the stat bonuses are. A pump that grants a keyword and
## no stats is invisible to every reading of [member pump_power] and
## [member pump_toughness]; this is where such a card says what it does.
var pump_keywords: Array[int] = []

## Regeneration shield (Drudge Skeletons, Death Ward).
var regenerates: bool = false

## Life gained by the controller.
var life_gain: int = 0

## Mana produced by a SPELL (Dark Ritual) — worth nothing on its own.
var adds_mana: bool = false

## MANA BOUGHT WITH LIFE (2026-09-10): the spell opens a mana source that
## is paid for in life rather than in taps — [member MtgPlayer.life_for_mana],
## which is Channel and nothing else in this pool. Worth nothing on its
## own, exactly as [member adds_mana] is worth nothing on its own, and
## worth the GAME in the one step where the life it buys makes an X burn
## lethal ([member AiProfile.reads_lethal_x]).
##
## See [constant LIFE_FOR_MANA] for why it is read by name.
var mana_for_life: bool = false

## Counters a spell.
var counters: bool = false

## A whole-combat Fog.
var fogs: bool = false

## A sweeper effect (Wrath of God, Earthquake, Nevinyrral's Disk), kept
## whole because its worth is a board calculation, not a number.
var sweeper: EffectBase = null

## "This permanent becomes an N/N creature" (Mishra's Factory, Jade
## Statue), kept whole for the same reason a sweeper is: its worth is a
## COMBAT calculation — what the body would do this turn — not a number
## that can be summed here.
var animates: AnimateSelfEffect = null

## Cards the TARGET player is made to discard (Disrupting Scepter's one,
## Rag Man's one at random). -1 means the count is the spell's X (Mind
## Twist, Nebuchadnezzar). See [method _aimed_discard] for why this is
## read the way it is.
var discards: int = 0

## Damage the effect deals to the TARGET'S CONTROLLER — the sting on the
## end of a punisher's removal ("Detonate deals X damage to that
## artifact's controller"), which is a bonus when the target is theirs and
## a price when the target is ours. -1 means the amount is the spell's X.
##
## Read from [constant CARD_LOCAL] only: every such clause in this pool
## lives in a card-local effect class. It is consulted by ONE caller,
## [method AiPlayer._cast_value], and since 2026-09-10 that caller reads
## BOTH halves of it under [member AiProfile.prices_liabilities] — the
## price when the target is ours, charged at the reaper's rate, and the
## bonus when the target is theirs, charged on the AI's own clock
## ([method AiPlayer._face_damage_value]) or worth the game outright when
## it is lethal. Until then only the own-side half was priced, which made
## an enemy Detonate's X a gain the planner got for free.
var damage_to_target_controller: int = 0

## Something the reader has no model for (a card-local effect outside the
## table). The AI treats an unknown TARGETED effect as removal-shaped —
## the common case in this pool — and an unknown untargeted one as a
## card worth its cost.
var unknown: bool = false

## The first targeting effect's spec (null when nothing targets).
var target_spec: TargetSpec = null

## A LEVELLER: every player down to the fewest lands, the fewest cards
## in hand and the fewest creatures (Balance). Its worth is a three-way
## count of both boards that nothing here can sum, so it is a flag and
## [method AiPlayer._level_value] does the counting; see [constant
## LEVELLERS] for why it is read by name.
var levels: bool = false

## A BLAST: the spell destroys the permanents it targets and then deals
## damage to EACH creature and EACH player equal to how many it buried
## (Volcanic Eruption). The targeting half points across the table; the
## blast lands on both sides of it, so what the spell is worth is a board
## calculation the fields above cannot sum — a flag, like [member levels],
## and [method AiPlayer._blast_price] does the counting. See [constant
## BLASTS] for why it is read by name.
var blasts: bool = false

## A TOKEN the effect puts onto the battlefield under our own control —
## the row of [constant TOKEN_MAKERS] that says what ONE activation
## GUARANTEES, `{}` for everything else. Kept as the body rather than as a
## number for the reason [member sweeper] and [member animates] are kept
## whole: what a new creature is worth is a board reading, and [method
## AiPlayer._token_value] does it on the evaluator's own scale.
##
## Read by ONE caller, [method AiPlayer._ability_option]'s token arm
## (gated by [member AiProfile.plays_engines]) — the effects it names are
## card-local, so [member unknown] stays set and every reading that word
## gates keeps the behaviour it had.
var makes_token: Dictionary = {}

## THE WINDOW SHAPES — what a spell whose rider keeps it out of its
## caster's own main phase DOES in the moment the rider names, for the
## card-local effects of that kind (see [constant WINDOW_SHAPES]). NONE
## for everything else, including every window card the AI has no board
## reading for. (`Shape` rather than `Window`: that name is a Node class.)
enum Shape {
	NONE,
	STOPS_ATTACKS,      ## Festival: no creature attacks this turn
	FORCES_ATTACKS,     ## Siren's Call: theirs attack this turn or die
	UNTAPS_LANDS,       ## Reset: every land we control untaps
	STEALS_ATTACKER,    ## Disharmony: their attacker leaves combat and is ours for the turn
	CONSCRIPTS_BLOCKER, ## Blaze of Glory: one defender blocks every attacker it can
	PULLS_BLOCKER,      ## False Orders: a defender leaves combat and re-blocks where we say
}
var window: int = Shape.NONE


# ---------------------------------------------------------------- the table --
# Card-local effects (`class X extends EffectBase` inside a card file) that
# the effect vocabulary cannot express and that this pool's shipped decks
# actually cast. Keyed by CARD NAME because the classes are card-local and
# have no global name to test against; each row states what the reader
# would have read had the card used the shared effects. Adding a card here
# is a one-line change; a card missing from it is simply treated as
# removal-shaped (targeted) or as a plain spell (untargeted), never wrong,
# only imprecise.
const CARD_LOCAL := {
	"Orcish Artillery": {"damage": 2, "self_damage": 3},
	"Psionic Blast": {"damage": 4, "self_damage": 2},
	"Fireball": {"damage_x": true, "divided": true},
	"Chain Lightning": {"damage": 3},
	"Swords to Plowshares": {"removes": true, "ignores_regeneration": true},
	"Drain Life": {"damage_x": true},
	"Disintegrate": {"damage_x": true, "ignores_regeneration": true},
	# "Destroy target artifact with mana value X. It can't be regenerated.
	# Detonate deals X damage to that artifact's controller." Removal, of
	# the no-regeneration kind; the X sizes the TARGET, not the damage
	# (the spec's source filter reads the cast's X, CR 601.2b), so this is
	# not a `damage_x` row. Without it the reader called Detonate `unknown`
	# and the picker's own-side fallback ([method AiPlayer._pick_for_spec],
	# 2026-09-04) — which cannot tell a source filter that says "you
	# control" from one that says "with mana value X" — shopped OUR
	# artifacts when theirs held nothing of the right cost: the owner's
	# opponent paid {1}{R} to Detonate its own untapped Mana Vault for one
	# damage to itself (2026-09-08). The damage to the target's controller
	# has no field here — for an enemy target it is a bonus, and a slot of
	# a harmful reading is no longer filled with a permanent of our own
	# ([member AiProfile.spares_own]).
	# `controller_damage: -1` is the X of "Detonate deals X damage to that
	# artifact's controller" (2026-09-09), and since 2026-09-10 both sides
	# of it are charged in [method AiPlayer._cast_value] under [member
	# AiProfile.prices_liabilities]: for one of OUR OWN — which only a
	# liability reading can name — it is the price of the relief, and for
	# one of THEIRS it is burn, lethal-worth when it is lethal.
	"Detonate": {"removes": true, "ignores_regeneration": true,
		"controller_damage": -1},
	# "You may tap OR untap target ..." — the mode is chosen on resolution,
	# so the reader records both and the AI's tap policy decides which
	# reading it is buying ([method AiPlayer._size_tap]). Without this row
	# Twiddle read as `unknown`, which the picker treats as removal-shaped
	# and aims at the enemy's most valuable permanent — tapped or not.
	"Twiddle": {"taps": true, "untaps": true},
}

# THE WINDOW TABLE (2026-09-06). The cards whose "Cast this spell only ..."
# rider leaves them NO legal moment in their caster's own main phase —
# the dead-card sweep's class 1 (docs/ROADMAP.md) — are card-local
# effects to a card, and the question the AI has to answer about them is
# not "what does it do to its target" but "what does it do to THE COMBAT
# it is cast into", which no flag above expresses. Each row names that
# shape; [method AiPlayer._window_worth] prices the shape from the board
# it is looking at and never the name.
#
# A SECOND TABLE rather than a "window" key in the one above, because a
# row in CARD_LOCAL makes the reader stop calling the effect `unknown`,
# and these effects ARE unknown to every reading that word gates — the
# harm reading, the target picker, the card's plain worth. Only the
# window caster reads this column, and it must be the only thing that
# changes when a card is added here.
#
# Camouflage is deliberately absent: what it does is a coin flip the
# defender half-controls (they choose the piles, the deal is random), and
# a one-ply board reading cannot price a coin flip honestly — the same
# rule that keeps Orcish Catapult in hand. Teleport is not a row
# either: it is a PumpEffect that grants UNBLOCKABLE and no stats, so the
# reader sees it structurally through [member pump_keywords].
const WINDOW_SHAPES := {
	"Festival": Shape.STOPS_ATTACKS,
	"Siren's Call": Shape.FORCES_ATTACKS,
	"Reset": Shape.UNTAPS_LANDS,
	"Disharmony": Shape.STEALS_ATTACKER,
	"Blaze of Glory": Shape.CONSCRIPTS_BLOCKER,
	"False Orders": Shape.PULLS_BLOCKER,
}

# THE LEVELLERS — the third table, one row, for the same reason the
# second exists: Balance is a card-local effect (`BalanceEffect`, three
# passes of "each player down to the fewest"), so the reader has nothing
# to test `is` against, and a row in CARD_LOCAL would stop it being
# `unknown` to every reading that word gates. Only [member levels] reads
# this column. The card IS the class here — it is the pool's only
# leveller — and what the AI does with the flag is a count of both
# boards ([method AiPlayer._level_value]), never a rule about the name.
const LEVELLERS := ["Balance"]

# THE CARD-LOCAL BREATHS — the fourth table, and the third one that is a
# table of its own rather than a row in [constant CARD_LOCAL], for the
# reason the second and third state: a row up there makes the reader stop
# calling the effect `unknown`, and these abilities ARE unknown to every
# reading that word gates (the harm reading, the target picker, the
# ability scorer). Only the pump paths read this column.
#
# THE THREE FIREBREATHERS THE READER COULD NOT SEE (2026-09-09). Dragon
# Whelp and Nalathni Dragon pump themselves through a `class X extends
# EffectBase` inside their own card file rather than through a
# [PumpEffect] — they have to, because the breath carries a FUSE the
# shared effect cannot express — so [member pump_self] was false for both
# and no pump path in [AiPlayer] had ever seen them: not the attack
# declaration, not the firebreathing on an unblocked attacker, not the
# pump that wins a blocked trade. A Dragon Whelp with six Mountains open,
# swinging into an empty board with its opponent at 5 life, dealt 2 and
# left six lands untapped.
#
# Each row states the bonus ONE activation grants and the fuse the card
# carries, exactly as the reader would have read it off a [PumpEffect]:
#
#   power, toughness — the bonus one activation grants, GUARANTEED. A
#     bonus the card chooses at resolution has a guaranteed part of zero
#     and therefore no row here (see Rainbow Knights below).
#   fuse            — the activation number that dooms the body ("if this
#     ability has been activated four or more times this turn, sacrifice
#     this creature at the beginning of the next end step"), 0 for none.
#   fuse_count, fuse_turn — the card's own memory keys for the count and
#     the turn it belongs to, so the pilot can ask how many breaths of
#     this turn are already spent. The count lives in
#     [member CardInstance.memory] because [member CardInstance.ability_uses]
#     is only kept for an ability with a [member ActivatedAbility.max_per_turn]
#     and these two have none — the fuse is not a cap, it is a price.
#
# RAINBOW KNIGHTS IS DELIBERATELY ABSENT, and it is the third card the
# 2026-09-09 pass was asked about. Its {W}{W} is "+0/+0, +1/+0 or +2/+0
# until end of turn chosen at random" — the bonus is rolled when the
# ability RESOLVES, so what the card guarantees for two white mana is
# nothing at all. A declaration sized on the average sends a 2/1 into a
# blocker that eats it one time in three, and a one-ply board reading
# cannot price a coin flip honestly: the same rule that keeps Camouflage
# out of [constant WINDOW_SHAPES] and Orcish Catapult in the AI's hand.
# Its OTHER ability ({1}: first strike until end of turn) is a real
# [PumpEffect] and is already read — and already refused by every pump
# path, because it grants no power (docs/ai-difficulty.md, the knob table).
const CARD_LOCAL_PUMPS := {
	"Dragon Whelp": {"power": 1, "toughness": 0, "fuse": 4,
		"fuse_count": "breaths", "fuse_turn": "breaths_turn"},
	"Nalathni Dragon": {"power": 1, "toughness": 0, "fuse": 4,
		"fuse_count": "breaths", "fuse_turn": "breaths_turn"},
}

# THE BLASTS — the fifth table (2026-09-09), and the fourth one that is a
# table of its own rather than a row in [constant CARD_LOCAL], for the
# reason the second, third and fourth state: a row up there makes the
# reader stop calling the effect `unknown`, and this effect IS unknown to
# every reading that word gates (the harm reading, the target picker).
# Only [member blasts] reads this column, so the null arm of the knob it
# feeds is what shipped, to the byte.
#
# THE CARD THE CENSUS COULD NOT FIND (2026-09-09). Volcanic Eruption's
# `EruptEffect` destroys X target Mountains and then deals that many
# damage to each creature and each player — a targeted removal spell with
# an untargeted sweeper welded to its back, which no field above can sum
# and no shared effect class expresses. The reader called the whole thing
# `unknown`, which makes it removal-shaped, so the planner priced the
# Mountains it took and charged NOTHING for the blast: nine Islands
# against six Mountains at five life, it cast for X=6 and killed ITSELF
# (probed 2026-09-09 — the opponent walked away at 12); with a Mahamoti
# Djinn and two Serra Angels of its own on the table it burned the Angels
# down to destroy four lands and a 1/1; and with two Mountains in front
# of it and nine Islands it still paid X=6 for the two.
#
# The card IS the class here — it is the pool's only spell of the shape —
# and what the AI does with the flag is a count of both boards and both
# life totals on the sweeper's own scale ([method AiPlayer._blast_price]),
# never a rule about the name.
const BLASTS := ["Volcanic Eruption"]

# THE LIFE-FOR-MANA SPELL — the seventh table (2026-09-10), one row, and
# the sixth that is a table of its own rather than a row in
# [constant CARD_LOCAL], for the reason every one before it states: a row
# up there makes the reader stop calling the effect `unknown`, and this
# effect IS unknown to every reading that word gates.
#
# THE CARD THE PILOT THREW AWAY (2026-09-10). Channel grants the PLAYER a
# mana source rather than a permanent an ability, so it is a `class X
# extends EffectBase` inside its own card file and there is no
# [AddManaEffect] to test `is` against: [member adds_mana] was false, the
# Dark Ritual gate never asked about it, and the card was cast as a plain
# three-point spell the first turn two Forests were on the table. Probed
# at HEAD: a Wizard with Channel and Fireball in hand and three lands out
# cast Channel into an empty board against an opponent at twenty, and paid
# not one point of life for mana in the whole turn — the graveyard, and
# the Fireball still in hand.
#
# The card IS the class here — it is the pool's only spell of the shape,
# and [member MtgPlayer.life_for_mana] is the flag it sets — and what the
# AI does with it is an arithmetic on two life totals and an X
# ([method AiPlayer._lethal_life_mana]), never a rule about the name.
const LIFE_FOR_MANA := ["Channel"]

# THE TOKEN MAKERS — the sixth table (2026-09-10), and the fifth one that
# is a table of its own rather than a row in [constant CARD_LOCAL], for
# the reason the second, third, fourth and fifth state: a row up there
# makes the reader stop calling the effect `unknown`, and these effects
# ARE unknown to every reading that word gates (the harm reading, the
# target picker). Only [member makes_token] reads this column, so the
# null arm of the knob it feeds is what shipped, to the byte.
#
# THE BODY THE SCORER COULD NOT SEE (2026-09-10). Five permanents in this
# pool turn mana into a CREATURE TOKEN through an activated ability, and
# every one of them makes it in a `class X extends EffectBase` inside its
# own card file — there is no shared token effect to test `is` against.
# So [method AiPlayer._ability_option] fell through to its final
# `return {}` for all five, and in the whole history of this AI not one
# Wasp, Minor Demon, Wolf, Snake or Spawn of Azar had ever been made:
# The Hive sat on ten open mana, and Necropolis of Azar kept every husk
# counter the day [member AiProfile.spends_counters] opened the cost
# (docs/ai-difficulty.md, §5).
#
# Each row states the body ONE activation GUARANTEES, exactly as the
# reader would have read it off the token's own [CardData]:
#
#   power, toughness — the printed size.
#   keywords        — the printed keywords, priced by
#     [constant Evaluator.KEYWORD_VALUE] like any other creature's.
#   landwalk        — true when the token has one, worth the same 0.5
#     [method Evaluator.permanent_value] gives a landwalker.
#
# A GUARANTEE and not an average, which is what keeps Necropolis of Azar
# honest: its Spawn is "a random power and toughness, each no less than 1
# and no greater than 3", rolled when the ability RESOLVES, so the row is
# the floor of that roll. It is the ruling [constant CARD_LOCAL_PUMPS]
# makes for Rainbow Knights, applied to a body instead of a bonus — with
# the sign the other way round, so the floor is conservative rather than
# safe: the pilot may buy a 3/3 for the price of a 1/1, never the reverse.
#
# TWO CARDS ARE DELIBERATELY ABSENT, both for the coin flip. BOTTLE OF
# SULEIMAN's {1} and a sacrifice buy a 5/5 flier if it wins and five
# damage to its own controller if it loses; PANDORA'S BOX's {3} rolls one
# creature card out of BOTH libraries and then flips for EACH player, so a
# winning activation can hand the opponent the copy and a losing one buys
# nothing. What one activation guarantees is nothing at all in both cases,
# and a one-ply board reading cannot price a coin flip honestly. That is
# the same rule that keeps Rainbow Knights out of the breath table,
# Camouflage out of [constant WINDOW_SHAPES] and Mana Crypt's flip unread
# by the liability reading.
#
# The abilities here have no X and no sizing question: a row is a body,
# not a count. A card that made the COUNT its X would need a sizing arm
# of its own, and this pool has none.
const TOKEN_MAKERS := {
	# "{5}, {T}: Create a 1/1 colorless Insect artifact creature token
	# with flying named Wasp." The 1994 mana sink, and the reason the
	# whole class was worth an arm: four of them sit in Nether Fiend.
	"The Hive": {"power": 1, "toughness": 1,
		"keywords": [Mtg.Keyword.FLYING]},
	# "{2}{B}{R}, {T}: Create a 1/1 black and red Demon creature token
	# named Minor Demon." One demon a turn, forever.
	"Boris Devilboon": {"power": 1, "toughness": 1},
	# "{2}{G}{G}: Create a 1/1 green Wolf creature token named Wolves of
	# the Hunt." The banding the token grants ITSELF is a static ability
	# and not a keyword, so the row does not claim it — the same
	# understatement [method Evaluator.permanent_value] already makes
	# about every triggered and static ability on a real creature.
	"Master of the Hunt": {"power": 1, "toughness": 1},
	# "{4}, {T}: Create a 1/1 colorless Snake artifact creature token"
	# with the poison trigger, which the row does not claim either, for
	# the reason above.
	"Serpent Generator": {"power": 1, "toughness": 1},
	# "{5}, Remove a husk counter: Put a Spawn of Azar token into play…
	# a black creature with a random power and toughness, each no less
	# than 1 and no greater than 3, that has swampwalk." The floor of the
	# roll, and the swampwalk it always has.
	"Necropolis of Azar": {"power": 1, "toughness": 1, "landwalk": true},
}


## The card-local breath [param card_name] pumps itself with, as a row of
## [constant CARD_LOCAL_PUMPS] — `{}` when the card has none.
##
## Read through this and not off the constant, so that the one caller
## ([method AiPlayer._card_local_breath], which gates it on
## [member AiProfile.pumps_to_attack]) is the only thing that has to know
## the table exists.
static func card_local_pump(card_name: String) -> Dictionary:
	return CARD_LOCAL_PUMPS.get(card_name, {})


## Read [param effects] (a spell's spell_effects, one mode's effects, or an
## ability's effects) into an intent. [param card_name] keys the
## card-local table.
static func read(effects: Array, card_name: String = "") -> EffectIntent:
	var intent := EffectIntent.new()
	var note: Dictionary = CARD_LOCAL.get(card_name, {})
	intent.window = int(WINDOW_SHAPES.get(card_name, Shape.NONE))
	intent.levels = LEVELLERS.has(card_name)
	intent.blasts = BLASTS.has(card_name)
	intent.mana_for_life = LIFE_FOR_MANA.has(card_name)
	for e in effects:
		if intent.target_spec == null and e.target_spec != null:
			intent.target_spec = e.target_spec
		if e is DamageEffect:
			if e.controller_mode:
				intent.self_damage += e.amount
			elif e.use_x:
				intent.damage_uses_x = true
			else:
				intent.damage += e.amount
		elif e is DestroyEffect or e is ExileEffect:
			intent.removes = true
			if e is DestroyEffect and not e.can_regenerate:
				intent.removal_ignores_regeneration = true
			if e is ExileEffect:
				intent.removal_ignores_regeneration = true
		elif e is ReturnToHandEffect:
			intent.bounces = true
		elif e is TapEffect:
			intent.taps = true
		elif e is UntapEffect:
			intent.untaps = true
		elif e is DrawEffect:
			if e.use_x:
				intent.draws_use_x = true
			else:
				intent.draws += e.count
		elif e is PumpEffect:
			intent.pumps = true
			intent.pump_power += e.power
			intent.pump_toughness += e.toughness
			if e.self_mode:
				intent.pump_self = true
			if e.use_x_power:
				intent.pump_uses_x = true
			for keyword in e.granted_keywords:
				if not intent.pump_keywords.has(keyword):
					intent.pump_keywords.append(keyword)
		elif e is RegenerateEffect:
			intent.regenerates = true
		elif e is GainLifeEffect:
			intent.life_gain += e.amount
		elif e is AddManaEffect:
			intent.adds_mana = true
		elif e is CounterEffect:
			intent.counters = true
		elif e is PreventCombatDamageEffect:
			intent.fogs = true
		elif e is DestroyAllEffect or e is DamageAllEffect:
			intent.sweeper = e
		elif e is AnimateSelfEffect:
			intent.animates = e
		elif e is SearchLibraryEffect:
			intent.searches = true   # priced by card_value; a card off the library
		elif e is ExtraTurnEffect:
			intent.extra_turns += 1   # priced by card_value; a draw step off the library
		elif e is MassPumpEffect \
				or e is ReturnFromGraveyardEffect or e is PreventDamageEffect \
				or e is PreventDamageShieldEffect or e is MillEffect:
			pass   # priced elsewhere (card_value); nothing here to sum
		elif note.is_empty():
			intent.unknown = true
			# ...but an AIMED DISCARD says so in its own description, and
			# an unknown effect that says so is still read for that one
			# fact. `unknown` deliberately STAYS set: the harm reading and
			# the target picker keep the behaviour they already had, and
			# only the ability scorer consults [member discards].
			var stripped := _aimed_discard(e)
			if stripped != 0:
				intent.discards = -1 if stripped < 0 or intent.discards < 0 \
					else intent.discards + stripped
			# ...and so does A WHEEL (2026-09-10), read off the same line
			# and for the same reason. `unknown` stays set here too.
			if intent.wheels == 0:
				intent.wheels = _wheel_draw(e)
	# THE TOKEN (2026-09-10): asked only of an effect list the reader could
	# not classify, so a card that grew a second, readable ability cannot
	# be handed the first one's body by name alone.
	if intent.unknown and TOKEN_MAKERS.has(card_name):
		intent.makes_token = TOKEN_MAKERS[card_name]
	# The table overrides what the reader could not see.
	if not note.is_empty():
		intent.damage += int(note.get("damage", 0))
		intent.self_damage += int(note.get("self_damage", 0))
		if bool(note.get("damage_x", false)):
			intent.damage_uses_x = true
		if bool(note.get("divided", false)):
			intent.damage_divided = true
		if bool(note.get("removes", false)):
			intent.removes = true
		if bool(note.get("ignores_regeneration", false)):
			intent.removal_ignores_regeneration = true
		if bool(note.get("taps", false)):
			intent.taps = true
		if bool(note.get("untaps", false)):
			intent.untaps = true
		intent.damage_to_target_controller += int(note.get("controller_damage", 0))
	return intent


## THE AIMED DISCARD, read from the effect's own one-line description.
##
## There is no shared `DiscardEffect` in this vocabulary — every discard in
## the pool is a `class X extends EffectBase` inside its own card file — so
## the reader has nothing to test `is` against, exactly the situation
## [constant CARD_LOCAL] exists for. What it has instead is a signal every
## effect already provides: [method EffectBase.describe] is part of the
## effect contract, the duel log and the UI both read it, and the seven
## aimed discards in this pool all state themselves the same way. Reading
## the card's own line is the precedent [method AiPlayer._is_counterspell]
## set, for the same reason and with the same limits.
##
## THE "TARGET PLAYER" PREFIX IS LOAD-BEARING, not decoration. It is what
## separates an aimed discard (Disrupting Scepter, Rag Man, Gwendlyn Di
## Corci, Wand of Ith, Nebuchadnezzar, Mind Twist, Amnesia) from a
## SYMMETRICAL one (Wheel of Fortune, Mind Bomb — "each player discards")
## and from one WE pay for (Contract from Below's "discards your hand",
## Recall's "discards X cards and recalls that many"). Getting that wrong
## would have the AI emptying its own hand every turn, so the test is
## deliberately narrow: an effect that does not announce a target player
## is simply not read, and stays the plain `unknown` it always was.
##
## Returns the number of cards, -1 when the count is the spell's X, or 0
## when this is not an aimed discard.
static func _aimed_discard(e: EffectBase) -> int:
	if e.target_spec == null or e.target_spec.kind != TargetSpec.Kind.PLAYER:
		return 0
	var line := e.describe().to_lower()
	if not (line.begins_with("target player") or line.begins_with("target opponent")):
		return 0
	if not line.contains("discard"):
		return 0
	return -1 if line.contains(" x ") else 1


## THE WHEEL, read from the effect's own one-line description — the same
## reading [method _aimed_discard] makes, of the same line, for the same
## reason (see [member wheels]).
##
## THE THREE CLAUSES ARE ALL LOAD-BEARING, and each one refuses a card in
## this pool that the loose version would have taken:
##
##  * IT TARGETS NOBODY. A wheel is symmetric by definition, so an effect
##    that names a target player is an aimed discard and not this — the
##    guard is also the cheap one, so a description is only asked for when
##    the effect could possibly be a wheel.
##  * EACH PLAYER. The prefix that separates Wheel of Fortune from
##    Contract from Below ("discards your hand") and from Recall.
##  * THE HAND LEAVES AND CARDS COME BACK. "Discards their hand" or
##    "shuffles hand ... into their library", AND a draw. Mind Bomb
##    discards and never refills; Eureka empties a hand onto the
##    battlefield and draws nothing. Neither is a wheel.
##
## Returns the number of cards each player ends up with,
## [constant WHEEL_REDRAW] when the line names no count (a reroll gives
## back what it took), or 0 when this is not a wheel at all.
static func _wheel_draw(e: EffectBase) -> int:
	if e.target_spec != null:
		return 0
	var line := e.describe().to_lower()
	if not line.begins_with("each player") or not line.contains("hand"):
		return 0
	if not (line.contains("discard") or line.contains("shuffle")):
		return 0
	var at := line.find("draw")
	if at < 0:
		return 0
	for word in line.substr(at).split(" ", false):
		var stripped := word.strip_edges()
		if stripped.is_valid_int():
			return maxi(int(stripped), 1)
		if WHEEL_COUNTS.has(stripped):
			return int(WHEEL_COUNTS[stripped])
	return WHEEL_REDRAW


# The counts a wheel's own line can print, as words. Godot has no
# spelled-number parser and the pool's wheels print "seven"; a digit is
# read directly, so a card that says "draws 7 cards" needs no row.
const WHEEL_COUNTS := {
	"one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
	"six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
}


## Does this intent hurt what it targets? Mirrors the classification
## [method AiPlayer._is_harmful] has always used, from the summed reading.
func is_harmful() -> bool:
	if damage > 0 or damage_uses_x or removes or bounces or taps:
		return true
	if draws > 0 or draws_use_x or pumps or life_gain > 0 or untaps or regenerates:
		return false
	return unknown   # removal-shaped by default


## Damage this intent would deal to one target at X = [param x_value]
## (0 when it deals none).
func damage_at(x_value: int) -> int:
	if damage_uses_x:
		return x_value + damage
	return damage


## Would the damage at X = [param x_value] finish [param victim] as it
## stands now (marked damage counted, live toughness read)? Protection and
## prevention are the target spec's business, not this reader's.
func kills(victim: CardInstance, x_value: int) -> bool:
	if victim == null or not victim.is_creature():
		return false
	var needed: int = victim.cur_toughness - victim.damage
	if damage_at(x_value) >= needed and needed > 0:
		return true
	if removes or bounces:
		return true
	return false


## A creature-answering shape — what "removal" means to the response
## logic: kills a creature outright, or removes it from the board.
func answers_creatures() -> bool:
	return removes or bounces or damage > 0 or damage_uses_x


## Is this effect's WHOLE job to tap (or untap) what it hits — Twiddle,
## Word of Binding, an Icy Manipulator's ability?
##
## Such an effect has no value of its own. Two identical casts differ by an
## order of magnitude depending on WHOSE permanent it hits and WHAT STATE
## that permanent is in: tapping an untapped blocker before we swing wins a
## race, tapping a permanent that is already tapped does nothing at all,
## and untapping the enemy's creature is a gift. Everything else the AI
## targets can be priced by the victim's worth alone; this cannot, so the
## picker routes it through the tap policy instead
## ([method AiPlayer._tap_denies_something], [method AiPlayer._size_tap]).
func is_tap_utility() -> bool:
	if not taps or target_spec == null:
		return false
	return damage == 0 and not damage_uses_x and self_damage == 0 \
		and not removes and not bounces and draws == 0 and not draws_use_x \
		and not pumps and not regenerates and life_gain == 0 \
		and not adds_mana and not counters and not fogs and sweeper == null


# ------------------------------------------------------------ aura aim --
#
# WHICH SIDE OF THE TABLE AN AURA BELONGS ON.
#
# An Aura is the one card shape whose target side cannot be read off its
# effects, because an Aura HAS no spell effects: it is cast at a spec, it
# enters attached, and everything it does lives in Callables — a
# StaticAbility's `apply`, a TriggeredAbility's handler — that this reader
# cannot look inside. Until 2026-09-04 the AI answered the question with a
# four-name list inlined in `AiPlayer._is_harmful` ("Weakness", "Paralyze",
# "Warp Artifact", "Wanderlust"); every one of the OTHER 73 auras in the
# pool therefore counted as helpful and was aimed at the AI's own board.
# That is why an AI enchanted its own Island with Psychic Venom and then
# took 2 damage every time it tapped for mana.
#
# So the aim is stated here, as data, in one place, with the same contract
# CARD_LOCAL has: structural signals first (a card that already SAYS it
# steals, reanimates or grants protection needs no row), then the explicit
# hostile set. `tests/ai/test_ai_targeting_2026_09_04.gd` walks the whole
# registry and fails on any aura it does not recognise, so a new aura
# cannot slip in unclassified the way these 73 did.

## Which side of the table an aura's host should be on.
enum Aim {
	FRIENDLY,   ## enchant one of OURS (a pump, a ward, an evasion grant)
	HOSTILE,    ## enchant one of THEIRS (a curse, a tax, a steal)
}

## Auras whose host's controller is the VICTIM. Everything not named here
## and not settled structurally is a friendly aura — the safe default for
## the shape that dominates the pool (pumps, keyword grants, wards), and
## the one the coverage test keeps honest.
##
## Three of these deserve their reason on the record, because they read the
## other way at a glance:
##  * "Creature Bond" is a Fling on our own creature and a delayed Lava Axe
##    on theirs. A one-ply AI cannot plan the sacrifice half, so it takes
##    the half that needs no plan.
##  * "Gaseous Form" prevents combat damage BOTH ways. On our creature that
##    is a wall that cannot hit back; on their best creature it is that
##    creature removed from combat entirely, which is strictly the better
##    of the two.
##  * "Immolation" (+2/-2) looks like a red pump and is a red removal spell.
##    Aimed at our own board it can KILL what it enchants outright (a 2/2
##    becomes a 4/0 and the toughness SBA sweeps it, CR 704.5f); aimed at
##    theirs the worst case is a bigger, more fragile enemy creature. The
##    downside is not symmetric, so it points across the table.
const AURA_HOSTILE := {
	"Artifact Possession": true,   # 2 damage to the artifact's controller
	"Backfire": true,              # their creature's damage rebounds on them
	"Blight": true,                # destroys the land it enchants
	"Brainwash": true,             # can't attack unless its controller pays {3}
	"Creature Bond": true,         # damage to the dead creature's controller
	"Curse Artifact": true,        # 2 a turn unless they sacrifice it
	"Cursed Land": true,           # 1 damage each of their upkeeps
	"Demonic Torment": true,       # can't attack, deals no combat damage
	"Earthbind": true,             # 2 damage and no more flying
	"Erosion": true,               # destroys the land unless they pay
	"Evil Presence": true,         # colour screw
	"Feedback": true,              # 1 damage each of their upkeeps
	"Gaseous Form": true,          # see the note above
	"Immolation": true,            # see the note above
	"Imprison": true,              # taxes their taps and their attacks
	"Kudzu": true,                 # destroys the land when it is tapped
	"Paralyze": true,              # taps it and holds it down
	"Phantasmal Terrain": true,    # colour screw
	"Power Leak": true,            # 2 a turn unless they pay
	"Psychic Venom": true,         # 2 damage every time the land taps
	"Relic Bind": true,            # its own spec says "an opponent controls"
	"Spirit Shackle": true,        # -0/-2 every time it taps
	"Takklemaggot": true,          # -0/-1 a turn, then moves on
	"Tangle Kelp": true,           # holds an attacker down
	"Venarian Gold": true,         # taps it and holds it down for X turns
	"Wanderlust": true,            # 1 damage each of their upkeeps
	"Warp Artifact": true,         # 1 damage each of their upkeeps
	"Weakness": true,              # -2/-1
}


## Which side of the table [param data]'s host should be on. Not a
## question about legality — the spec still has the last word — only about
## which battlefield the picker should shop on first.
static func aura_aim(data: CardData) -> int:
	if data == null or not data.is_aura():
		return Aim.FRIENDLY
	# Structural signals: a card that already states this about itself
	# never needs a row in the table.
	if data.aura_steals:
		return Aim.HOSTILE          # Control Magic, Steal Artifact
	if data.aura_reanimates:
		return Aim.FRIENDLY         # Animate Dead — the host is in a graveyard
	if data.aura_grants_protection != 0:
		return Aim.FRIENDLY         # the ward cycle
	return Aim.HOSTILE if AURA_HOSTILE.has(data.card_name) else Aim.FRIENDLY


## Is [param data] an aura this reader has an opinion about, rather than
## one that merely fell through to the friendly default? The coverage test
## uses this; nothing in the AI's hot path does.
static func aura_is_classified(data: CardData) -> bool:
	if data == null or not data.is_aura():
		return false
	return data.aura_steals or data.aura_reanimates \
		or data.aura_grants_protection != 0 or AURA_HOSTILE.has(data.card_name)


## WHAT A FRIENDLY AURA GIVES ITS HOST, read off the card's own words —
## the keywords it grants, and for each whether it is any use to a
## creature that will never attack. The owner, from a playtest
## (2026-09-08): *"ai oponent had Wall of swords (wall cannot attack) -
## and the AI put 'eternal warrior' aura - vigilance on the wall - this
## is complete nonsense! … That particular aura should be put on
## valuable creature that can then serve as attacker and blocker"*. The
## picker shopped its own board by [method Evaluator.permanent_value]
## alone, and a 3/5 flying Wall is the most valuable creature on many
## boards. An aura's effect is a Callable this code cannot look inside,
## so, as with [constant AURA_HOSTILE], what it gives is read as DATA —
## here from the oracle text every card carries, since the pool's
## grants are all spelt one way ("has vigilance", "has islandwalk",
## "can't be blocked…"). A pump ("gets +2/+2") is a gift to any
## creature and is not a grant. [s30] — the original's AI chose hosts
## by a valuation its sources do not show.
##
## Each entry: `keyword` (an [enum Mtg.Keyword], or -1), `landwalk`
## (the land type in the engine's lower case, or ""), and `attack_only`
## — vigilance, fear, trample, haste, landwalk and unblockability do
## nothing for a creature that cannot attack; flying, first strike and
## reach serve a blocker too.
const AURA_GRANTS := {
	"has vigilance": {"keyword": Mtg.Keyword.VIGILANCE, "attack_only": true},
	"has flying": {"keyword": Mtg.Keyword.FLYING, "attack_only": false},
	"has first strike": {"keyword": Mtg.Keyword.FIRST_STRIKE, "attack_only": false},
	"has reach": {"keyword": Mtg.Keyword.REACH, "attack_only": false},
	"has fear": {"keyword": Mtg.Keyword.FEAR, "attack_only": true},
	"has trample": {"keyword": Mtg.Keyword.TRAMPLE, "attack_only": true},
	"as though it had haste": {"keyword": Mtg.Keyword.HASTE, "attack_only": true},
	"can't be blocked": {"keyword": Mtg.Keyword.UNBLOCKABLE, "attack_only": true},
	# A shield is anyone's gift — Artifact Ward's second line, which
	# keeps it sensible on a Wall (the owner: "artifact ward is somehow
	# sensible also on a wall"), whatever its first line says.
	"prevent all damage that would be dealt to enchanted creature":
		{"keyword": -1, "attack_only": false},
}
const LANDWALKS := ["plains", "island", "swamp", "mountain", "forest"]

static var _aura_gifts_cache: Dictionary = {}


## The grants of [param data] — `[{keyword, landwalk, attack_only}, …]`,
## empty for an aura that grants nothing this reader knows (a pump, a
## ward, a punisher), and cached by name: the text is read once.
static func aura_gifts(data: CardData) -> Array:
	if data == null or not data.is_aura():
		return []
	if _aura_gifts_cache.has(data.card_name):
		return _aura_gifts_cache[data.card_name]
	var out: Array = []
	var text := data.oracle_text.to_lower()
	for phrase in AURA_GRANTS:
		if text.contains(phrase):
			var grant: Dictionary = AURA_GRANTS[phrase]
			out.append({"keyword": grant["keyword"], "landwalk": "",
				"attack_only": grant["attack_only"]})
	for land in LANDWALKS:
		if text.contains("has " + land + "walk"):
			out.append({"keyword": -1, "landwalk": land, "attack_only": true})
	_aura_gifts_cache[data.card_name] = out
	return out


## Would [param host] get anything from [param data]? False when every
## grant is one the host already has or one it can never use — an
## attacker's gift to a creature with defender, or held under a "can't
## attack". True for an aura whose gifts are not read here (a pump), and
## for a host that is no creature: the host's value decides those.
static func aura_fits(data: CardData, host: CardInstance) -> bool:
	var gifts := aura_gifts(data)
	if gifts.is_empty() or host == null or not host.is_creature():
		return true
	var grounded := host.has_keyword(Mtg.Keyword.DEFENDER) or host.cur_cant_attack
	for gift in gifts:
		if bool(gift["attack_only"]) and grounded:
			continue
		var keyword := int(gift["keyword"])
		if keyword >= 0 and host.has_keyword(keyword):
			continue
		if String(gift["landwalk"]) != "" and host.cur_landwalk.has(String(gift["landwalk"])):
			continue
		return true
	return false


# ------------------------------------------------------- the liability --
#
# THE TOLL AND THE RECKONING (2026-09-09, [member AiProfile.prices_liabilities]).
# Everything above reads what a SPELL or an ABILITY does. These two read
# what a PERMANENT ALREADY ON THE TABLE does to the seat that controls it
# — the other half of the same question, and the half the evaluator had no
# words for: [method Evaluator.permanent_value] floors at zero, so a
# permanent worth LESS than nothing to its controller could not be said.
#
# Read off the printed text of the permanent's own triggered abilities, for
# the same reason [method aura_gifts] reads an aura's oracle line: what a
# card-local trigger DOES lives in a Callable this code cannot look inside,
# so the card's own words are the only channel there is. The precedent is
# [constant AiPlayer.TRIBUTE_WORDS], which reads the pool's prompts the
# same way. Nothing here is keyed by a card's name.

## The beats of a turn a toll can be charged at — the steps that come
## round whether we like them or not. A trigger that fires on something
## the seat CHOOSES (an attack, a land drop, a tap for mana) is not a toll
## it is paying, it is a price it agreed to.
const TOLL_BEATS: Array[int] = [
	Mtg.EventType.UPKEEP_START, Mtg.EventType.DRAW_STEP, Mtg.EventType.END_STEP_START,
]

## The words that say the damage lands on the permanent's OWN controller.
## "…deals 1 damage to THAT PLAYER" (Copper Tablet, Manabarbs, Karma, The
## Rack) is deliberately absent: those tolls are symmetric or aimed, and a
## reading that saw only our half of them would price a Copper Tablet as a
## liability while it ticks the opponent down at exactly the same rate.
##
## RULED AND NOT BUILT, 2026-09-10, and the census is why. The six cards
## the pool puts on this shape were read one by one, and FIVE of them are
## refused for a reason that has nothing to do with symmetry:
##
##  * MANABARBS fires on `Mtg.EventType.TAPPED_FOR_MANA`, which is not a
##    [constant TOLL_BEATS] event at all — tapping a land is a price the
##    seat AGREED to, not a beat that comes round whether it likes it or
##    not, and that rule predates this question.
##  * KARMA ("damage equal to the number of Swamps they control"), THE
##    RACK and STORM WORLD ("X damage … where X is 3 minus the number of
##    cards in their hand") and POWER SURGE ("X … the number of untapped
##    lands") print a COUNT this reader would have to do itself, which is
##    exactly what [constant TOLL_UNKNOWABLE]'s ruling already refuses. A
##    search for "deals <a number> damage to that player" finds one in
##    none of the four.
##
## What is left is ONE CARD, Copper Tablet, and pricing it needs to know
## whose race the shared clock is winning — which of the two seats it
## kills first, and whether the game ends from something else before it
## kills either. The AI has the first half (two life totals and a rate
## each) and nothing whatever of the second: no reader in this engine
## estimates the turns a game has left ([method
## AiPlayer._face_damage_value] scales one hit by the share of a life
## total it takes, [method Evaluator.position_score] is a snapshot, and
## [constant AiPlayer.PACE_HORIZON] is the LIBRARY's clock under a knob of
## its own). So the question is `counts_the_race`'s (docs/AI-next-wave.md,
## wave 4) and stays there; a symmetric toll keeps its printed worth.
const TOLL_WORDS: Array[String] = ["damage to you", "damage to its controller"]

## Words that make the amount unknowable at the moment we would have to
## act on it. A roll is not read at all — the 2026-09-09 ruling on
## [constant CARD_LOCAL_PUMPS] (Rainbow Knights) applies with its sign
## flipped: what a card GUARANTEES is the only number a decision can be
## made on, and a Mana Crypt guarantees nothing. "damage to you equal to"
## (Voodoo Doll's pin counters, Primordial Ooze's X) is a count this
## reader would have to do itself, so it is left unread and the permanent
## keeps its printed worth.
const TOLL_UNKNOWABLE: Array[String] = ["flip a coin", "at random", "damage to you equal to"]

static var _toll_cache: Dictionary = {}


## What one printed trigger line takes from its own controller, per beat:
## `{"damage": n, "escape": "<the mana price the line names>"}`.
##
## `damage` is the number in "deals N damage to you", 0 for a line that
## names none, that rolls for it, or that would have to be counted.
## `escape` is the mana the same line offers to avoid it — "unless you pay
## {G}{G}{G}{G}", "you may pay {4}" — as printed, "" for none. A price
## that is not mana (a card discarded, a land sacrificed, an Island) is
## not an escape this reader can price and is left as "".
##
## Cached by the line itself: the pool's trigger texts are a fixed set.
static func toll_of_line(text: String) -> Dictionary:
	if _toll_cache.has(text):
		return _toll_cache[text]
	var lower := text.to_lower()
	var out := {"damage": 0, "escape": _mana_price_in(lower)}
	for word in TOLL_UNKNOWABLE:
		if lower.contains(word):
			_toll_cache[text] = out
			return out
	# "deals N damage to you", and the N has to be RIGHT THERE: Primordial
	# Ooze's "it deals X damage to you" is a count this reader will not do,
	# and a looser search read the 1 out of the "+1/+1 counter" three
	# clauses earlier.
	for word in TOLL_WORDS:
		var regex := RegEx.new()
		regex.compile("deals (\\d+) " + word)
		var m := regex.search(lower)
		if m != null:
			out["damage"] = maxi(int(m.get_string(1)), 0)
			break
	_toll_cache[text] = out
	return out


## THE HAND TOLL (2026-09-10, [member AiProfile.minds_the_vise];
## `docs/forge/casting.md` P4, `docs/arzakon.strategy` §4 item 2) — a
## printed trigger line whose damage is a COUNT OF THE CARDS IN A HAND,
## read as the two numbers a decision needs: `{"slope": ±1, "threshold": n}`,
## or `{}` when the line is not one of these.
##
## The damage one beat deals is `max(slope * (hand − threshold), 0)`, so
## the pair says the whole card: Black Vise ("X is the number of cards in
## their hand minus 4") is `{slope: +1, threshold: 4}` and squeezes a FULL
## hand; The Rack ("X is 3 minus the number of cards in their hand") is
## `{slope: −1, threshold: 3}` and stretches an EMPTY one. Storm World's
## "X is 4 minus the number of cards in their hand" is the Rack's slope at
## the Vise's threshold, and it beats at EACH player's upkeep. Those three
## are the whole of it in this pool.
##
## WHY THE SLOPE AND NOT A FLAG, and this is the one reading
## `docs/forge/casting.md` P4 has backwards. Its last sentence — *"The
## Rack shares (a)-(c) with the threshold at three"* — is one subtraction
## out: three minus the hand GROWS as the hand empties, so a pilot that
## answered a Rack the way it answers a Vise would empty its hand into the
## card and take the full three every upkeep instead of nothing. One knob
## cannot hold both cards unless it reads which way the line points, so it
## reads it.
##
## WHY THE COUNT IS DONE HERE WHILE [constant TOLL_UNKNOWABLE]'S RULING
## STANDS. That ruling (2026-09-10) refused The Rack and Storm World for
## [method AiPlayer._liability_price] because they "print a COUNT this
## reader would have to do itself" — and it was right, because that
## reading subtracts a STREAM from [method Evaluator.position_score], a
## snapshot with no horizon in it. This reader does no such thing: the
## count it needs is a hand size, a number in front of the seat at the
## moment it acts, and every caller prices exactly ONE BEAT and never a
## stream. The horizon question the ruling left open is still open and
## still `counts_the_race`'s (docs/AI-next-wave.md, wave 4).
##
## Read from the trigger's own printed line, which is the reading [method
## toll_of_line], [method _aimed_discard] and [method _wheel_draw] already
## make of the same kind of text, and cached by that line the same way —
## the pool's trigger texts are a fixed set.
static func hand_toll_of_line(text: String) -> Dictionary:
	if _hand_toll_cache.has(text):
		return _hand_toll_cache[text]
	var out: Dictionary = {}
	var lower := text.to_lower()
	# The damage has to land on a PLAYER and the line has to say which hand
	# it is counting. The only other card in this pool whose trigger names
	# a hand at all — Nicol Bolas's "that player discards their hand" —
	# says neither.
	if lower.contains("damage to that player") and lower.contains("cards in their hand"):
		var squeeze := RegEx.new()
		squeeze.compile("number of cards in their hand minus ([0-9]+)")
		var m := squeeze.search(lower)
		if m != null:
			out = {"slope": 1, "threshold": int(m.get_string(1))}
		else:
			var stretch := RegEx.new()
			stretch.compile("([0-9]+) minus the number of cards in their hand")
			m = stretch.search(lower)
			if m != null:
				out = {"slope": -1, "threshold": int(m.get_string(1))}
	_hand_toll_cache[text] = out
	return out


## What one hand toll takes at a hand of [param hand_size] — the BEAT, and
## never a stream (see [method hand_toll_of_line]). 0 for a line that is
## not one of these, and never below 0: a Vise under four cards and a Rack
## over three both deal nothing at all.
static func hand_toll_damage(toll: Dictionary, hand_size: int) -> int:
	if toll.is_empty():
		return 0
	return maxi(int(toll["slope"]) * (hand_size - int(toll["threshold"])), 0)


static var _hand_toll_cache: Dictionary = {}


## The mana price a printed line offers to avoid what it says — the run of
## `{…}` symbols right after "pay". "" when the line names no such price,
## or names one that is not mana.
static func _mana_price_in(lower: String) -> String:
	var at := lower.find("pay {")
	if at < 0:
		return ""
	var out := ""
	var i := at + 4
	while i < lower.length() and lower[i] == "{":
		var close := lower.find("}", i)
		if close < 0:
			break
		out += lower.substr(i, close - i + 1).to_upper()
		i = close + 1
	# An {X} price is the card counting something of its own (Primordial
	# Ooze's counters); this reader cannot say what it will be, so it says
	# nothing.
	return "" if out.contains("{X}") else out


## Cached by card NAME (never by CardData: CONTRIBUTING.md's static-var
## rule) — [method AiPlayer._own_value] asks the reckoning of every
## candidate of every card ask, and the answer cannot change for a
## printed card.
static var _reckoning_cache: Dictionary = {}


## THE RECKONING: does [param data] say that losing this permanent loses
## the GAME? Lich's last line, and the one reading that has to outrank
## every other — a permanent whose departure ends the game is not cheap
## to give up, it is the most expensive thing on the table, and the
## evaluator priced it at a four-drop enchantment's 3.2, below a Grizzly
## Bears, until this landed. Read as a shape and not as a card: any
## trigger that fires when the permanent LEAVES (or DIES) and whose
## printed line says the controller loses the game.
static func loses_the_game_on_leaving(data: CardData) -> bool:
	if data == null:
		return false
	if _reckoning_cache.has(data.card_name):
		return _reckoning_cache[data.card_name]
	var found := _read_reckoning(data)
	_reckoning_cache[data.card_name] = found
	return found


static func _read_reckoning(data: CardData) -> bool:
	for trig in data.triggered_abilities:
		if trig.event_type != Mtg.EventType.LEAVES_BATTLEFIELD \
				and trig.event_type != Mtg.EventType.DIES:
			continue
		if trig.text.to_lower().contains("you lose the game"):
			return true
	return false


## THE GAZE (2026-09-10, [member AiProfile.reads_gaze]), cached by the
## trigger's own printed line the way [member _toll_cache] caches a toll's:
## the pool's trigger texts are a fixed set.
static var _gaze_cache: Dictionary = {}


## Does [param trig] DESTROY the creature its permanent blocks — or is
## blocked by — whatever the combat maths say? Cockatrice and Thicket
## Basilisk are the pool's two, and neither is named here: the reading is
## a [constant Mtg.EventType.BLOCKED] trigger whose printed line destroys
## "that creature" at end of combat.
##
## THE TIMING IS READ AND NOT ASSUMED, which is the half a shape test is
## easy to get wrong. A gaze that resolves AT END OF COMBAT lets the
## victim strike first — the Basilisk still takes the six a Craw Wurm
## deals it — while one that destroyed the creature on the spot would
## take the damage off the exchange as well. This pool prints only the
## first, so only the first is read: a line that destroys what it blocks
## at some other moment keeps the pilot exactly where it was, which
## understates the danger rather than inventing a rule for a card that is
## not here. [method AiPlayer._damage_from] is therefore untouched.
static func is_gaze(trig: TriggeredAbility) -> bool:
	if trig == null or trig.event_type != Mtg.EventType.BLOCKED:
		return false
	if _gaze_cache.has(trig.text):
		return _gaze_cache[trig.text]
	var lower := trig.text.to_lower()
	var found := lower.contains("destroy that creature") \
		and lower.contains("end of combat")
	_gaze_cache[trig.text] = found
	return found


## THE EXECUTIONER'S SHAPE (2026-09-10, [member AiProfile.reads_gaze]):
## does [param ability] destroy a creature that has to be TAPPED for it to
## be aimed at all? Forge's `canBeKilledByRoyalAssassin`
## (`ComputerUtilCard.java:911-938`) is the same test with the same
## absence of a card name.
##
## Read as one [DestroyEffect] behind a creature spec whose printed line
## names the tapped state — the card's own English, the reading
## [method loses_the_game_on_leaving] and [method toll_of_line] already
## make. The dynamic half is the caller's ([method
## AiPlayer._taps_into_execution]): a spec that is legal against the body
## STANDING STILL is a threat the attack did not create, and the tap is
## then not what buys them the kill. That is what tells the pool's two
## cards apart — Royal Assassin's spec carries the filter that refuses an
## untapped creature, and Tetsuo Umezawa's ("target tapped or blocking
## creature") carries none at all, so it may already aim at the body and
## is no reason to keep it home.
static func destroys_the_tapped(ability: ActivatedAbility) -> bool:
	if ability == null or ability.effects.size() != 1:
		return false
	if not (ability.effects[0] is DestroyEffect):
		return false
	var spec: TargetSpec = ability.effects[0].target_spec
	if spec == null or spec.kind != TargetSpec.Kind.CREATURE:
		return false
	return (ability.text + " " + spec.description).to_lower().contains("tapped")

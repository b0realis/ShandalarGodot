class_name Mtg
extends RefCounted
## Central namespace for the rules engine's shared enums and constants.
##
## Every other engine file refers to these through the [code]Mtg.[/code] prefix
## (e.g. [code]Mtg.Zone.HAND[/code], [code]Mtg.Step.UPKEEP[/code]). Keeping all
## cross-cutting vocabulary in one file means a card author or engine developer
## only ever has to learn one set of names.
##
## Design notes:
## - Colors and card types are BITMASKS, because Magic objects can be several
##   at once (a gold card is W|U; an artifact creature is ARTIFACT|CREATURE).
## - Steps are a flat enum covering the whole turn; [constant STEP_ORDER] is
##   the canonical progression the turn engine walks through.
## - This class is never instantiated; it only carries statics.


## The five mana colors plus colorless, as bit flags (named ManaColor because
## Godot reserves the plain name "Color" for its built-in type) so a card's color
## identity is a single int. C is "colorless" (used by mana like Sol Ring's).
enum ManaColor { W = 1, U = 2, B = 4, R = 8, G = 16, C = 32 }

## Human-readable color names, keyed by Color flag. Used for logs and UI.
const COLOR_NAMES := {
	ManaColor.W: "White", ManaColor.U: "Blue", ManaColor.B: "Black",
	ManaColor.R: "Red", ManaColor.G: "Green", ManaColor.C: "Colorless",
}

## The five BASIC LAND TYPES and the mana each one taps for. Text-changing
## effects (Magical Hack) and land-retuning statics (Evil Presence, Blood
## Moon) both read it, so "what does a Swamp produce" has one answer.
const BASIC_LAND_COLORS := {
	"plains": ManaColor.W, "island": ManaColor.U, "swamp": ManaColor.B,
	"mountain": ManaColor.R, "forest": ManaColor.G,
}

## The five colors in canonical WUBRG order (no colorless) — iteration helper.
const WUBRG: Array[int] = [ManaColor.W, ManaColor.U, ManaColor.B, ManaColor.R, ManaColor.G]

## Card types as bit flags (a card can be more than one, e.g. artifact creature).
enum CardType {
	LAND = 1, CREATURE = 2, ARTIFACT = 4,
	ENCHANTMENT = 8, INSTANT = 16, SORCERY = 32,
}

## Supertypes as bit flags. BASIC matters for the "any number in deck" rule
## and for not being targeted by some effects; LEGENDARY for the legend
## rule; WORLD for the world rule (CR 704.5k — when two or more world
## permanents are on the battlefield, all but the NEWEST are put into
## their owners' graveyards). Legends is where world enchantments live.
enum Supertype { BASIC = 1, LEGENDARY = 2, WORLD = 4 }

## The zones a card can occupy. ANTE is Shandalar-specific (the 1997 game
## plays for ante); it is defined now so zone plumbing never needs a rework.
enum Zone { LIBRARY, HAND, BATTLEFIELD, GRAVEYARD, STACK, EXILE, ANTE }

## Every step of a Magic turn, in one flat enum. Phases are implicit:
## Beginning = UNTAP..DRAW, Combat = COMBAT_BEGIN..COMBAT_END,
## Ending = END..CLEANUP.
## FIRST_STRIKE_DAMAGE only happens when someone in combat has first strike
## (CR 510.5); MtgGame skips it otherwise, exactly as the CR describes.
enum Step {
	UNTAP, UPKEEP, DRAW,
	MAIN1,
	COMBAT_BEGIN, DECLARE_ATTACKERS, DECLARE_BLOCKERS,
	FIRST_STRIKE_DAMAGE, COMBAT_DAMAGE, COMBAT_END,
	MAIN2,
	END, CLEANUP,
}

## Canonical step progression for a turn. The turn engine in MtgGame walks
## this array; CLEANUP wraps to the next player's UNTAP.
const STEP_ORDER: Array[int] = [
	Step.UNTAP, Step.UPKEEP, Step.DRAW,
	Step.MAIN1,
	Step.COMBAT_BEGIN, Step.DECLARE_ATTACKERS, Step.DECLARE_BLOCKERS,
	Step.FIRST_STRIKE_DAMAGE, Step.COMBAT_DAMAGE, Step.COMBAT_END,
	Step.MAIN2,
	Step.END, Step.CLEANUP,
]

## Steps in which players receive priority. UNTAP and (normally) CLEANUP do
## not grant priority per CR 500.3 / 514.1.
const PRIORITY_STEPS: Array[int] = [
	Step.UPKEEP, Step.DRAW, Step.MAIN1,
	Step.COMBAT_BEGIN, Step.DECLARE_ATTACKERS, Step.DECLARE_BLOCKERS,
	Step.FIRST_STRIKE_DAMAGE, Step.COMBAT_DAMAGE, Step.COMBAT_END,
	Step.MAIN2, Step.END,
]

## Evergreen keyword abilities implemented by the engine.
## Adding a keyword: extend this enum, then teach the relevant subsystem
## about it (combat.gd for combat keywords, mtg_game.gd otherwise) and
## document it in docs/ROADMAP.md.
## - FIRST_STRIKE: deals combat damage in the first-strike wave (CR 702.7).
## - MUST_ATTACK: "attacks each combat if able" (Juggernaut) — enforced by
##   MtgGame.declare_attackers.
## Protection and landwalk are NOT keywords here: they are parameterized
## (by color / by land type), so they live as CardData/CardInstance fields
## (protection_from, landwalk) instead of enum values.
## - BANDING: may attack in a band (CR 702.22, simplified — see combat.gd).
## - UNBLOCKABLE: can't be blocked at all — usually GRANTED until end of
##   turn (Dwarven Warriors) rather than printed.
## - FEAR: can't be blocked except by artifact creatures and/or black
##   creatures (CR 702.36) — granted by the Fear aura in this pool.
enum Keyword { FLYING, REACH, VIGILANCE, HASTE, TRAMPLE, DEFENDER, FIRST_STRIKE, MUST_ATTACK, BANDING, UNBLOCKABLE, FEAR }

## Events the engine dispatches. TriggeredAbility instances subscribe to
## these; the UI layer can also listen (via MtgGame's signals) to animate.
enum EventType {
	ENTERS_BATTLEFIELD,   ## data: {instance, controller}
	LEAVES_BATTLEFIELD,   ## data: {instance, from_controller, memory} —
	                      ## `memory` is a SNAPSHOT of the departing
	                      ## permanent's card-local choices, taken before
	                      ## battlefield state was wiped (CR 400.7)
	DIES,                 ## data: {instance, controller, damaged_by, memory}
	SPELL_CAST,           ## data: {instance, controller}
	CARD_DRAWN,           ## data: {player, instance} — `instance` is
	                      ## the card that was drawn (the duel screen's
	                      ## Showcase displays it, Duel.hlp "Showcase")
	DAMAGE_DEALT,         ## data: {source, amount, to_player? / to_instance?,
	                      ## packet} — `packet` is the [DamagePacket] that
	                      ## landed, which knows how much was PREVENTED as
	                      ## well as how much was dealt (§6.8).
	UPKEEP_START,         ## data: {player}  (the active player's upkeep)
	END_STEP_START,       ## data: {player}
	DECLARED_ATTACKERS,   ## data: {attackers: Array[CardInstance]}
	LAND_PLAYED,          ## data: {instance, controller}
	TAPPED_FOR_MANA,      ## data: {instance, controller, color} — mana
	                      ## triggers only (resolved off-stack, CR 605.1b)
	BECAME_TAPPED,        ## data: {instance, controller} — ANY tap: for
	                      ## mana, by cost, by effect (Icy), by attacking,
	                      ## by regenerating. NOT fired for entering tapped
	                      ## (that isn't "becoming tapped"). City of Brass,
	                      ## Psychic Venom.
	BECAME_UNTAPPED,      ## data: {instance, controller} — ANY untap: the
	                      ## untap step, an Untap effect, a Candelabra.
	                      ## Tawnos's Coffin releases its prisoner on it.
	DRAW_STEP,            ## data: {player} — after the normal draw
	                      ## (Howling Mine's "additional card" hook)
	BLOCKED,              ## data: {attacker, blocker} — one event per
	                      ## declared block pair (Cockatrice both ways)
	END_OF_COMBAT,        ## data: {player} — the end-of-combat step has
	                      ## begun and doomed creatures have died, but
	                      ## attacking/blocking status still stands
	                      ## (Clockwork Beast winds down, The Wretched)
	BLOCKERS_DECLARED,    ## data: {} — after ALL blocks are declared;
	                      ## "attacks and isn't blocked" reads combat state
	                      ## (Murk Dwellers)
	COMBAT_START,         ## data: {player} — the beginning-of-combat step
	                      ## of `player`'s turn has begun, before attackers
	                      ## are declared (Battering Ram's banding, Johan's
	                      ## offer). Named COMBAT_START rather than
	                      ## COMBAT_BEGIN so it cannot be misread as the
	                      ## Mtg.Step of the same name.
	ABILITY_ACTIVATED,    ## data: {instance, controller, player, ability,
	                      ## index, taps} — `player` ACTIVATED an ability of
	                      ## `instance` (CR 602); `controller` is the
	                      ## permanent's controller, as on every other event
	                      ## here, and the two differ only where a card
	                      ## hands its ability to the table (Land's Edge).
	                      ## `taps` is true when {T} was part of the
	                      ## activation cost, which is what the printed
	                      ## "without {T} in its activation cost" clauses
	                      ## read (Artifact Possession, Powerleech, Haunting
	                      ## Wind). Dispatched when the ability goes on the
	                      ## stack, so the trigger sits ABOVE it and
	                      ## resolves first (CR 603.3b).
	                      ## `ability` is an ActivatedAbility, or a
	                      ## ManaAbility for the off-stack kind (CR 605.1a
	                      ## — a mana ability is still an activated one).
	                      ## MANA abilities announce this only when
	                      ## something is listening (MtgGame.tap_for_mana
	                      ## gates on [method MtgGame.has_trigger_listener]):
	                      ## that path runs for every land every turn and
	                      ## the event object is otherwise built and thrown
	                      ## away thousands of times a duel. The only
	                      ## observable difference is that MtgGame's
	                      ## event_occurred signal does not carry unheard
	                      ## mana activations.
}

## What kind of object a StackItem is.
enum StackKind { SPELL, ABILITY, TRIGGER }


## Pretty name for a step — used in the game log and by UIs.
static func step_name(step: int) -> String:
	var names := {
		Step.UNTAP: "Untap", Step.UPKEEP: "Upkeep", Step.DRAW: "Draw",
		Step.MAIN1: "First Main",
		Step.COMBAT_BEGIN: "Beginning of Combat",
		Step.DECLARE_ATTACKERS: "Declare Attackers",
		Step.DECLARE_BLOCKERS: "Declare Blockers",
		# The 1997 Combat Bar's own two names for the damage pair
		# (`@CUECARD_PHASEBAR`, Program/UIStrings.txt:706): "Resolve 1st
		# strike damage" and "Resolve normal damage".
		Step.FIRST_STRIKE_DAMAGE: "First-Strike Damage",
		Step.COMBAT_DAMAGE: "Combat Damage", Step.COMBAT_END: "End of Combat",
		Step.MAIN2: "Second Main",
		Step.END: "End Step", Step.CLEANUP: "Cleanup",
	}
	return names.get(step, "Unknown")


## True when [param step] belongs to the combat phase.
static func is_combat_step(step: int) -> bool:
	return step >= Step.COMBAT_BEGIN and step <= Step.COMBAT_END


## True when [param step] is a main phase (the only time sorcery-speed
## spells and lands may be played, and only with an empty stack).
static func is_main_step(step: int) -> bool:
	return step == Step.MAIN1 or step == Step.MAIN2


## The five PHASES a turn is made of. Our Step enum is flat and phases are
## implicit (see its comment); this names them, because the 1997 ruleset
## does several things per PHASE where modern rules do them per STEP —
## emptying the mana pool and checking for a dead player, both of which
## RulesOptions can switch to the 1997 shape.
enum Phase { BEGINNING, PRECOMBAT_MAIN, COMBAT, POSTCOMBAT_MAIN, ENDING }


## Which phase [param step] belongs to.
static func phase_of(step: int) -> int:
	if step <= Step.DRAW:
		return Phase.BEGINNING
	if step == Step.MAIN1:
		return Phase.PRECOMBAT_MAIN
	if is_combat_step(step):
		return Phase.COMBAT
	if step == Step.MAIN2:
		return Phase.POSTCOMBAT_MAIN
	return Phase.ENDING

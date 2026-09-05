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


func _init(p_name := "Custom", p_mistakes := 0.0, p_aggression := 0.5,
		p_chump := 5, p_holds := true, p_counter_threshold := 5.0,
		p_sideboard_swaps := 0) -> void:
	profile_name = p_name
	mistake_chance = p_mistakes
	aggression = p_aggression
	chump_threshold = p_chump
	holds_instants = p_holds
	counter_threshold = p_counter_threshold
	sideboard_swaps = p_sideboard_swaps


## Lowest difficulty: fumbles a third of its actions, swings recklessly, and
## never holds up instants — sorcery-speed Magic, which is the honest way to
## be weak without cheating the rules.
static func apprentice() -> AiProfile:
	return AiProfile.new("Apprentice", 0.35, 0.75, 3, false, 5.0, 0)

## Second difficulty: reactive play switches on, but the high counter
## threshold means it only answers the biggest threats and lets the rest
## resolve.
static func magician() -> AiProfile:
	return AiProfile.new("Magician", 0.20, 0.60, 4, true, 7.0, 2)

## Third difficulty: rarely fumbles, plays a balanced game.
static func sorcerer() -> AiProfile:
	return AiProfile.new("Sorcerer", 0.08, 0.50, 5, true, 5.5, 3)

## Top difficulty: no mistakes at all — it plays the same decision code as
## every other profile, just without ever degrading its own choice.
static func wizard() -> AiProfile:
	return AiProfile.new("Wizard", 0.0, 0.50, 6, true, 5.0, 4)


func _to_string() -> String:
	return profile_name

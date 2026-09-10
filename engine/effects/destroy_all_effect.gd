class_name DestroyAllEffect
extends EffectBase
## Mass removal: "Destroy all [filter]." — Wrath of God's effect.
##
## Untargeted (no target_spec): mass effects don't target, which is exactly
## why Wrath kills protection-from-white creatures — protection's DEBT
## bundle never comes into play. The filter Callable
## [code]func(inst: CardInstance) -> bool[/code] selects victims;
## [member description] states the scope in card English.

## Selects which battlefield permanents die. Unset = all creatures.
var filter: Callable = Callable()

## Card-English scope ("all creatures"), for logs.
var description: String = "all creatures"

## False for "they can't be regenerated" sweepers (Wrath of God, Shatterstorm)
## — MtgGame.destroy then ignores every regeneration shield (CR 701.15d).
var can_regenerate: bool = true


func _init(p_description: String = "all creatures",
		p_filter: Callable = Callable(), p_can_regenerate := true) -> void:
	description = p_description
	filter = p_filter
	can_regenerate = p_can_regenerate


## Moves every matching permanent to its owner's graveyard through
## MtgGame.destroy, which fires the DIES event, honours regeneration shields
## unless [member can_regenerate] is false, and sweeps orphaned auras.
##
## THE WHOLE SWEEP IS ONE RESOLUTION (CR 704.3, fixed 2026-09-10). State-based
## actions are checked when a player WOULD receive priority, never in the
## middle of one resolution, so the loop below is bracketed by
## [method MtgGame.begin_simultaneous] / [method MtgGame.end_simultaneous].
##
## WHY IT MATTERED, and it is an OUTCOME rather than an ordering:
## [method MtgGame.destroy] does not check state-based actions itself, but
## two death REPLACEMENTS re-route a victim into a helper that does —
## `CardData.dies_returns_to_hand` into [method MtgGame.return_to_hand]
## (Firestorm Phoenix) and `CardInstance.exile_instead_of_dying` into
## [method MtgGame.exile_permanent] (Disintegrate, Runesword, Whippoorwill).
## Sweep a Nevinyrral's Disk over a Castle, a Phoenix and a Weakened
## Drudge Skeletons and the unbracketed loop buried the Castle, bounced the
## Phoenix, and the bounce's state-based check found the Skeleton at zero
## toughness — CR 704.5f, which is NOT destruction, so its regeneration
## shield could not replace it and was never even offered. Destroyed by the
## Disk on the settled board it regenerates and lives.
## tests/cards/test_sweeper_bracket_2026_09_10.gd is that board.
func resolve(game: MtgGame, _source: CardInstance, _controller: int, _target: TargetRef,
		_x_value: int = 0) -> void:
	# Snapshot first: destroying mutates the battlefield lists.
	var victims: Array[CardInstance] = []
	for inst in game.all_battlefield():
		if filter.is_valid():
			if filter.call(inst):
				victims.append(inst)
		elif inst.is_creature():
			victims.append(inst)
	# NOTHING MAY RETURN BETWEEN THESE TWO CALLS: a deferral left open
	# freezes state-based actions for the rest of the game.
	game.begin_simultaneous()
	for inst in victims:
		game.destroy(inst, can_regenerate)
	game.end_simultaneous()


## One-line log/UI text.
func describe() -> String:
	var text := "destroys " + description
	if not can_regenerate:
		text += " (no regeneration)"
	return text

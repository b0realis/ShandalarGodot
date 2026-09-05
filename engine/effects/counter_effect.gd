class_name CounterEffect
extends EffectBase
## "Counter target spell." — Counterspell.
##
## Targets a card in Mtg.Zone.STACK (TargetSpec.Kind.SPELL). Resolution
## calls MtgGame.counter_spell, which removes the spell's StackItem and puts
## the card into its owner's graveyard (CR 701.5a). If the target spell has
## already resolved (or was itself countered), the target is illegal at
## resolution and this spell fizzles — the engine's standard CR 608.2b path,
## nothing special needed here.


func _init(desc: String = "", filter: Callable = Callable()) -> void:
	target_spec = TargetSpec.spell(desc, filter)


## Removes the target's StackItem and moves the card to its owner's
## graveyard, both through MtgGame.counter_spell. The null guard is for a
## spell that is already gone (Fork's copy ceasing to exist, CR 707.10a):
## nothing to counter, and countering nothing is legal.
func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst != null:
		game.counter_spell(inst)


## One-line log/UI text.
func describe() -> String:
	return "counters %s" % target_spec.description

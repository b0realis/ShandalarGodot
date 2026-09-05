extends CardScript
## Diamond Valley — Land — (arn, rare)
## Oracle: {T}, Sacrifice a creature: You gain life equal to the
##         sacrificed creature's toughness.
##
## Implementation: a tap-plus-sacrifice ability whose payload reads the
## LIVE toughness of the body eaten — so a pumped or enchanted creature
## pays more. The gain happens on resolution, after the sacrifice (which
## is a cost), so the effect reads the snapshot MtgGame.activate_ability
## parked on THIS ACTIVATION's stack item as the cost was paid
## (`StackItem.cost_paid`, read through `MtgGame.cost_paid`): last known
## information, CR 608.2h. That also covers TOKENS, which never reach a
## graveyard to be read back from. Per ACTIVATION rather than per
## permanent, because the ability costs no mana and two of them can be
## waiting on the stack at once.


func build() -> CardData:
	return CardData.new("Diamond Valley", "", Mtg.CardType.LAND) \
		.activated(ActivatedAbility.new(
			"", true, [ValleyEffect.new()],
			"{T}, Sacrifice a creature: You gain life equal to the sacrificed "
			+ "creature's toughness.") \
			.with_sacrifice_of("creature", _is_creature)) \
		.oracle("{T}, Sacrifice a creature: You gain life equal to the sacrificed "
			+ "creature's toughness.")


static func _is_creature(inst: CardInstance) -> bool:
	return inst.is_creature()


class ValleyEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		# The body is already gone (costs are paid first); the engine left
		# its live toughness on THIS ACTIVATION's stack item when it paid
		# the sacrifice, which is why two Valley activations waiting at
		# once each gain their own body's toughness (StackItem.cost_paid).
		var toughness := int(game.cost_paid("_sacrificed_toughness", -1))
		if toughness >= 0:
			game.adjust_life(controller, toughness)

	func describe() -> String:
		return "gain life equal to the sacrificed creature's toughness"

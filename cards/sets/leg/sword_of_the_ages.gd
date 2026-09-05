extends CardScript
## Sword of the Ages — {6} — Artifact — (leg, rare)
## Oracle: This artifact enters tapped.
##         {T}, Sacrifice this artifact and any number of creatures you
##         control: This artifact deals X damage to any target, where X is
##         the total power of the creatures sacrificed this way, then exile
##         this artifact and those creature cards.
##
## Implementation: the sacrifices are the COST (CR 601.2h), paid as the
## ability is activated — the Sword itself (`with_sacrifice_cost`) and "any
## number of creatures you control" (`with_sacrifice_of(...).any_number()`),
## which the engine asks for one body at a time, each ask optional, until
## the controller says "done" (a human seat is held on every ask; the
## default and AI seats keep sacrificing while a body is left, since holding
## creatures back is never what the Sword is for). Every dies-trigger fires
## (an Onulet still pays out). The total power the cost ate is snapshotted
## while the bodies still stand (CR 608.2h) on the activation's own stack
## item (`StackItem.cost_paid`, key `_sacrificed_total_power`), so a second
## activation in response cannot read this one's tally.
##
## On resolution the damage is dealt, and THEN the cards the sacrifices left
## in the graveyard are exiled (MtgGame.exile_from_graveyard — a no-op for a
## token, which ceased to exist on the way, CR 111.7, and for a card that
## has since left the graveyard, CR 400.7).


func build() -> CardData:
	return CardData.new("Sword of the Ages", "{6}", Mtg.CardType.ARTIFACT) \
		.with_enters_tapped() \
		.activated(ActivatedAbility.new("", true, [SwordEffect.new()],
			"{T}, Sacrifice this artifact and any number of creatures you control: it deals damage equal to their total power to any target, then exile them.") \
			.with_sacrifice_cost() \
			.with_sacrifice_of("creature", func(perm: CardInstance) -> bool:
				return perm.is_creature()) \
			.any_number()) \
		.oracle("This artifact enters tapped.\n{T}, Sacrifice this artifact and any number of creatures you control: This artifact deals X damage to any target, where X is the total power of the creatures sacrificed this way, then exile this artifact and those creature cards.")


class SwordEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.any_target()

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var total := int(game.cost_paid("_sacrificed_total_power", 0))
		var army: Array = game.cost_paid("_sacrificed_instances", [])
		if total > 0:
			game.deal_damage(source, target, total)
		# "...then exile this artifact and those creature cards": the cards
		# the cost left in the graveyard.
		for inst in army:
			game.exile_from_graveyard(inst)
		game.exile_from_graveyard(source)

	func describe() -> String:
		return "fires the total power of the creatures sacrificed at any target"

extends CardScript
## Barl's Cage — {4} — Artifact — (drk, rare)
## Oracle: {3}: Target creature doesn't untap during its controller's
##         next untap step.
##
## Implementation: a card-local effect raising the target's one-shot
## skip_next_untap flag (consumed by that untap step). Repeatable — three
## mana a turn keeps anything locked forever.


func build() -> CardData:
	return CardData.new("Barl's Cage", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{3}", false,
			[CageEffect.new()],
			"{3}: Target creature doesn't untap during its controller's next untap step.")) \
		.oracle("{3}: Target creature doesn't untap during its controller's next untap step.")


class CageEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
			inst.skip_next_untap = true
			game.log_line("%s won't untap during its controller's next untap step" %
				inst.data.card_name)

	func describe() -> String:
		return "target creature skips its next untap"

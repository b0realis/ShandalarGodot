extends CardScript
## Divine Offering — {1}{W} — Instant — (leg, common)
## Oracle: Destroy target artifact. You gain life equal to its mana value.
##
## Implementation: a card-local effect — the mana value is read BEFORE the
## destruction (the card knows it either way, but order documents intent),
## then the CASTER gains that much life. Compare Crumble, where the
## artifact's controller is consoled instead.


func build() -> CardData:
	return CardData.new("Divine Offering", "{1}{W}", Mtg.CardType.INSTANT) \
		.spell(DivineOfferingEffect.new()) \
		.oracle("Destroy target artifact. You gain life equal to its mana value.")


class DivineOfferingEffect extends EffectBase:
	static func _is_artifact(inst: CardInstance) -> bool:
		return inst.is_type(Mtg.CardType.ARTIFACT)

	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target artifact", _is_artifact)

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		var mv: int = inst.data.cost.mana_value()
		game.destroy(inst)
		game.adjust_life(controller, mv)

	func describe() -> String:
		return "destroys target artifact; you gain its mana value in life"

extends CardScript
## Great Defender — {W} — Instant — (leg, uncommon)
## Oracle: Target creature gets +0/+X until end of turn, where X is its
##         mana value.
##
## Implementation: a card-local pump reading the TARGET's printed mana
## value at resolution. On a Serra Angel it is +0/+5 for one white mana —
## the most efficient combat trick in the set, and useless on a Kobold.


func build() -> CardData:
	return CardData.new("Great Defender", "{W}", Mtg.CardType.INSTANT) \
		.spell(DefendEffect.new()) \
		.oracle("Target creature gets +0/+X until end of turn, where X is its mana value.")


class DefendEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_pump(inst.id, 0, inst.data.cost.mana_value())
		game.recalculate()

	func describe() -> String:
		return "target creature gets +0/+X, X being its mana value"

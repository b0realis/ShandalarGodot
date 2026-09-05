extends CardScript
## Living Armor — {4} — Artifact — (drk, uncommon)
## Oracle: {T}, Sacrifice this artifact: Put X +0/+1 counters on target
##         creature, where X is that creature's mana value.
##
## Implementation: a one-shot artifact whose payload reads the TARGET's
## printed mana value and adds that many "+0/+1" counters — the
## continuous pipeline parses arbitrary P/T counter names, so no special
## casing is needed. Best on the most expensive thing you control.


func build() -> CardData:
	return CardData.new("Living Armor", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"", true, [ArmorEffect.new()],
			"{T}, Sacrifice Living Armor: Put X +0/+1 counters on target creature, "
			+ "where X is that creature's mana value.") \
			.with_sacrifice_cost()) \
		.oracle("{T}, Sacrifice this artifact: Put X +0/+1 counters on target "
			+ "creature, where X is that creature's mana value.")


class ArmorEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		var n := inst.data.cost.mana_value()
		if n > 0:
			game.add_counters(inst, "+0/+1", n)

	func describe() -> String:
		return "puts X +0/+1 counters on target creature, X being its mana value"

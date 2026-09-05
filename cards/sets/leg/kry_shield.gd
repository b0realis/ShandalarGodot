extends CardScript
## Kry Shield — {2} — Artifact — (leg, uncommon)
## Oracle: {2}, {T}: Prevent all damage that would be dealt this turn by
##         target creature you control. That creature gets +0/+X until end
##         of turn, where X is its mana value.
##
## Implementation: Subdue's shape on an artifact, but stronger and
## narrower — the prevention covers ALL damage the creature would deal
## (not just combat damage, so a Prodigal Sorcerer's ping is stopped too),
## and the target must be one you control.


func build() -> CardData:
	var spec := TargetSpec.creature("target creature you control")
	spec.with_source_filter(_yours)
	return CardData.new("Kry Shield", "{2}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", true, [ShieldEffect.new(spec)],
			"{2}, {T}: Prevent all damage that would be dealt this turn by target "
			+ "creature you control. That creature gets +0/+X until end of turn, "
			+ "where X is its mana value.")) \
		.oracle("{2}, {T}: Prevent all damage that would be dealt this turn by target "
			+ "creature you control. That creature gets +0/+X until end of turn, where "
			+ "X is its mana value.")


static func _yours(_game: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == source.controller_id


class ShieldEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_combat_prevention(inst.id, true, false, false, true)
		game.continuous.add_until_eot_pump(inst.id, 0, inst.data.cost.mana_value())
		game.recalculate()

	func describe() -> String:
		return "prevents target creature's damage and gives it +0/+X"

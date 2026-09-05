extends CardScript
## Subdue — {G} — Instant — (leg, common)
## Oracle: Prevent all combat damage that would be dealt by target
##         creature this turn. That creature gets +0/+X until end of turn,
##         where X is its mana value.
##
## Implementation: ONE card-local effect doing both halves, because the
## printed card has a single target that both sentences share (the engine
## gives one target slot per targeting effect, so two effects would ask
## for two creatures). Green's Fog for one creature: it stops attacking
## AND becomes very hard to kill in the process.


func build() -> CardData:
	return CardData.new("Subdue", "{G}", Mtg.CardType.INSTANT) \
		.spell(SubdueEffect.new()) \
		.oracle("Prevent all combat damage that would be dealt by target creature "
			+ "this turn. That creature gets +0/+X until end of turn, where X is its "
			+ "mana value.")


class SubdueEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_combat_prevention(inst.id, true, false)
		game.continuous.add_until_eot_pump(inst.id, 0, inst.data.cost.mana_value())
		game.recalculate()
		game.log_line("%s subdues %s (+0/+%d, no combat damage)" % [
			source.data.card_name, inst.data.card_name, inst.data.cost.mana_value()])

	func describe() -> String:
		return "prevents target creature's combat damage and gives it +0/+X"

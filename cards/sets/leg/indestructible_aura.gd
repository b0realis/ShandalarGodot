extends CardScript
## Indestructible Aura — {W} — Instant — (leg, common)
## Oracle: Prevent all damage that would be dealt to target creature this
##         turn.
##
## Implementation: a card-local effect filling the target's this-turn
## prevention pool to an amount nothing in the pool can exceed. The pool
## is cleared at cleanup like every other prevention, so it really is
## "this turn". Despite the name it stops DAMAGE, not destruction — a
## Terror still kills the creature.


func build() -> CardData:
	return CardData.new("Indestructible Aura", "{W}", Mtg.CardType.INSTANT) \
		.spell(ShieldEffect.new()) \
		.oracle("Prevent all damage that would be dealt to target creature this turn.")


class ShieldEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		inst.prevention = 9999
		game.log_line("%s will take no damage this turn" % inst.data.card_name)

	func describe() -> String:
		return "prevents all damage to target creature this turn"

extends CardScript
## Blood Lust — {1}{R} — Instant — (4ed, common)
## Oracle: If target creature has toughness 5 or greater, it gets +4/-4
##         until end of turn. Otherwise, it gets +4/-X until end of turn,
##         where X is its toughness minus 1.
##
## Implementation: a card-local effect — the toughness reduction is
## computed at RESOLUTION from the creature's current toughness (never
## below 1; the card is a combat trick, not removal), then registered as
## a normal until-EOT pump. Red's classic "all offense" trick.


func build() -> CardData:
	return CardData.new("Blood Lust", "{1}{R}", Mtg.CardType.INSTANT) \
		.spell(BloodLustEffect.new()) \
		.oracle("If target creature has toughness 5 or greater, it gets +4/-4 until end of turn. Otherwise, it gets +4/-X until end of turn, where X is its toughness minus 1.")


class BloodLustEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		var minus: int = mini(4, inst.cur_toughness - 1)
		game.continuous.add_until_eot_pump(inst.id, 4, -minus)
		game.log_line("%s gives %s +4/-%d until end of turn" % [
			source.data.card_name, inst.data.card_name, minus])
		game.recalculate()

	func describe() -> String:
		return "gets +4/-4 (toughness stops at 1) until end of turn"

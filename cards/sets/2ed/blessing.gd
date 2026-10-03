extends CardScript
## Blessing — {W}{W} — Enchantment — Aura — (2ed, rare)
## Oracle: Enchant creature
##         {W}: Enchanted creature gets +1/+1 until end of turn.
##
## Implementation: the aura-with-activated pattern (see holy_armor.gd) —
## the ability lives on the AURA (its controller pays and pumps), exactly
## as printed; mage-go grants it to the creature instead, which we
## deliberately do not copy (wrong activator on stolen/enemy hosts).
## The effect declares its shape to the AI (`pump_host`, 2026-09-30, see
## firebreathing.gd).


func build() -> CardData:
	return CardData.new("Blessing", "{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.activated(ActivatedAbility.new(
			"{W}", false,
			[PumpHostEffect.new().with_ai_role(&"pump_host", {"power": 1, "toughness": 1})],
			"{W}: Enchanted creature gets +1/+1 until end of turn.")) \
		.oracle("Enchant creature\n{W}: Enchanted creature gets +1/+1 until end of turn.")


class PumpHostEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.attached_to == -1:
			return
		var host := game.find_instance(source.attached_to)
		if not game.is_present(host):   # gone, or phased out (CR 702.26e)
			return
		game.continuous.add_until_eot_pump(host.id, 1, 1, [])
		game.log_line("%s gives %s +1/+1 until end of turn" % [
			source.data.card_name, host.data.card_name])
		game.recalculate()

	func describe() -> String:
		return "enchanted creature gets +1/+1 until end of turn"

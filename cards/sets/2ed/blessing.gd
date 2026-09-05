extends CardScript
## Blessing — {W}{W} — Enchantment — Aura — (2ed, rare)
## Oracle: Enchant creature
##         {W}: Enchanted creature gets +1/+1 until end of turn.
##
## Implementation: the aura-with-activated pattern (see holy_armor.gd) —
## the ability lives on the AURA (its controller pays and pumps), exactly
## as printed; mage-go grants it to the creature instead, which we
## deliberately do not copy (wrong activator on stolen/enemy hosts).


func build() -> CardData:
	return CardData.new("Blessing", "{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.activated(ActivatedAbility.new(
			"{W}", false,
			[PumpHostEffect.new()],
			"{W}: Enchanted creature gets +1/+1 until end of turn.")) \
		.oracle("Enchant creature\n{W}: Enchanted creature gets +1/+1 until end of turn.")


class PumpHostEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.attached_to == -1:
			return
		var host := game.find_instance(source.attached_to)
		if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_pump(host.id, 1, 1, [])
		game.log_line("%s gives %s +1/+1 until end of turn" % [
			source.data.card_name, host.data.card_name])
		game.recalculate()

	func describe() -> String:
		return "enchanted creature gets +1/+1 until end of turn"

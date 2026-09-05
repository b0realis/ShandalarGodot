extends CardScript
## Firebreathing — {R} — Enchantment — Aura (2ed, common)
## Oracle: Enchant creature. {R}: Enchanted creature gets +1/+0 until end
##         of turn.
##
## Implementation: an aura whose ACTIVATED ability pumps its HOST — the
## activated ability lives on the aura (its controller pays and activates,
## per the rules), and the card-local effect routes the pump through the
## live attachment. The aura-with-activated pattern; cf. wild_growth.gd
## (aura-with-mana-trigger) and warp_artifact.gd (aura-with-trigger).


func build() -> CardData:
	return CardData.new("Firebreathing", "{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.activated(ActivatedAbility.new(
			"{R}", false,
			[PumpHostEffect.new()],
			"{R}: Enchanted creature gets +1/+0 until end of turn.")) \
		.oracle("Enchant creature.\n{R}: Enchanted creature gets +1/+0 until end of turn.")


class PumpHostEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.attached_to == -1:
			return
		var host := game.find_instance(source.attached_to)
		if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_pump(host.id, 1, 0, [])
		game.log_line("%s gives %s +1/+0 until end of turn" % [
			source.data.card_name, host.data.card_name])
		game.recalculate()

	func describe() -> String:
		return "enchanted creature gets +1/+0 until end of turn"

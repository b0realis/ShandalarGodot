extends CardScript
## Holy Armor — {W} — Enchantment — Aura (2ed, common)
## Oracle: Enchant creature. Enchanted creature gets +0/+2.
##         {W}: Enchanted creature gets +0/+1 until end of turn.
##
## Implementation: static +0/+2 plus the Firebreathing pump-the-host
## pattern in white toughness flavor (see firebreathing.gd for the
## aura-with-activated notes).


func build() -> CardData:
	return CardData.new("Holy Armor", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature gets +0/+2.")) \
		.activated(ActivatedAbility.new(
			"{W}", false,
			[PumpHostEffect.new()],
			"{W}: Enchanted creature gets +0/+1 until end of turn.")) \
		.oracle("Enchant creature. Enchanted creature gets +0/+2.\n{W}: Enchanted creature gets +0/+1 until end of turn.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_toughness += 2


class PumpHostEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.attached_to == -1:
			return
		var host := game.find_instance(source.attached_to)
		if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_pump(host.id, 0, 1, [])
		game.log_line("%s gives %s +0/+1 until end of turn" % [
			source.data.card_name, host.data.card_name])
		game.recalculate()

	func describe() -> String:
		return "enchanted creature gets +0/+1 until end of turn"

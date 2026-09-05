extends CardScript
## Instill Energy — {G} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant creature
##         Enchanted creature can attack as though it had haste.
##         {0}: Untap enchanted creature. Activate only during your turn
##         and only once each turn.
##
## Implementation: a static setting CardInstance.cur_attacks_as_if_hasty —
## NOT the HASTE keyword, which would also unlock {T} costs (CR 302.6) and
## let a freshly cast Llanowar Elves tap for mana, something the printed
## card does not do. Plus a free untap ability on the AURA, restricted
## with your_turn_only() and per_turn(1). Attack, then untap to block —
## the original pseudo-vigilance.


func build() -> CardData:
	return CardData.new("Instill Energy", "{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply, "Enchanted creature can attack as though it had haste.")) \
		.activated(ActivatedAbility.new(
			"", false, [UntapHostEffect.new()],
			"{0}: Untap enchanted creature. Activate only during your turn and only "
			+ "once each turn.") \
			.your_turn_only().per_turn(1)) \
		.oracle("Enchant creature\nEnchanted creature can attack as though it had "
			+ "haste.\n{0}: Untap enchanted creature. Activate only during your turn "
			+ "and only once each turn.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_attacks_as_if_hasty = true


class UntapHostEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var host := game.find_instance(source.attached_to)
		if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
			game.untap_permanent(host)

	func describe() -> String:
		return "untaps enchanted creature"

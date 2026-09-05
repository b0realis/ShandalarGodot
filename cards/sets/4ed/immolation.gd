extends CardScript
## Immolation — {R} — Enchantment — Aura — (4ed, common)
## Oracle: Enchant creature
##         Enchanted creature gets +2/-2.
##
## Implementation: static +2/-2 — red's dual-use aura: pump your fatty's
## power or drop a 2-toughness blocker to 0 (the toughness SBA finishes
## it, taking the aura along).


func build() -> CardData:
	return CardData.new("Immolation", "{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature gets +2/-2.")) \
		.oracle("Enchant creature\nEnchanted creature gets +2/-2.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_power += 2
		host.cur_toughness -= 2

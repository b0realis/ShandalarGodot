extends CardScript
## Giant Strength — {R}{R} — Enchantment — Aura — (4ed, common)
## Oracle: Enchant creature
##         Enchanted creature gets +2/+2.
##
## Implementation: the static pump-aura pattern (holy_strength.gd), red
## flavor.


func build() -> CardData:
	return CardData.new("Giant Strength", "{R}{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature gets +2/+2.")) \
		.oracle("Enchant creature\nEnchanted creature gets +2/+2.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_power += 2
		host.cur_toughness += 2

extends CardScript
## Divine Transformation — {2}{W}{W} — Enchantment — Aura — (4ed, uncommon)
## Oracle: Enchant creature
##         Enchanted creature gets +3/+3.
##
## Implementation: the static pump-aura pattern (holy_strength.gd) at
## white's top rate.


func build() -> CardData:
	return CardData.new("Divine Transformation", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature gets +3/+3.")) \
		.oracle("Enchant creature\nEnchanted creature gets +3/+3.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_power += 3
		host.cur_toughness += 3

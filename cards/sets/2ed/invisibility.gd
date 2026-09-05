extends CardScript
## Invisibility — {U}{U} — Enchantment — Aura — (2ed, common)
## Oracle: Enchant creature
##         Enchanted creature can't be blocked except by Walls.
##
## Implementation: the block-RESTRICTION aura — the static appends a
## {desc, filter} entry to the host's cur_block_restrictions, and block
## legality demands every restriction accept the blocker. Walls (which
## never attack) become the only speed bump.


func build() -> CardData:
	return CardData.new("Invisibility", "{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply, "Enchanted creature can't be blocked except by Walls.")) \
		.oracle("Enchant creature\nEnchanted creature can't be blocked except by Walls.")


static func _only_walls(blocker: CardInstance) -> bool:
	return blocker.has_subtype("wall")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_block_restrictions.append(
			{"desc": "Walls", "filter": _only_walls})

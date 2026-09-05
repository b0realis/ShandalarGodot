extends CardScript
## Fishliver Oil — {1}{U} — Enchantment — Aura — (arn, common)
## Oracle: Enchant creature
##         Enchanted creature has islandwalk.
##
## Implementation: a static appending "island" to the host's LIVE landwalk
## list — CombatState reads cur_landwalk, so the host becomes unblockable
## whenever the defender has any Island (including a Tropical Island).


func build() -> CardData:
	return CardData.new("Fishliver Oil", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply, "Enchanted creature has islandwalk.")) \
		.oracle("Enchant creature\nEnchanted creature has islandwalk.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD \
			and not host.cur_landwalk.has("island"):
		host.cur_landwalk.append("island")

extends CardScript
## Burrowing — {R} — Enchantment — Aura (2ed, uncommon)
## Oracle: Enchant creature. Enchanted creature has mountainwalk.
##
## Implementation: a landwalk-GRANTING aura — the static appends to the
## host's LIVE cur_landwalk, which block legality reads (so the walk works
## the moment it attaches, and vs dual lands by subtype).


func build() -> CardData:
	return CardData.new("Burrowing", "{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature has mountainwalk.")) \
		.oracle("Enchant creature. Enchanted creature has mountainwalk.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	if not host.cur_landwalk.has("mountain"):
		host.cur_landwalk.append("mountain")

extends CardScript
## Aspect of Wolf — {1}{G} — Enchantment — Aura — (2ed, rare)
## Oracle: Enchant creature
##         Enchanted creature gets +X/+Y, where X is half the number of
##         Forests you control, rounded down, and Y is half the number of
##         Forests you control, rounded up.
##
## Implementation: a static counting the AURA CONTROLLER's Forests (the
## printed "you") on every recalculation and applying the two halves of
## the split. Four Forests is +2/+2; five is +2/+3.


func build() -> CardData:
	return CardData.new("Aspect of Wolf", "{1}{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply,
			"Enchanted creature gets +X/+Y, where X is half the number of Forests you "
			+ "control rounded down and Y is half rounded up.")) \
		.oracle("Enchant creature\nEnchanted creature gets +X/+Y, where X is half the "
			+ "number of Forests you control, rounded down, and Y is half the number "
			+ "of Forests you control, rounded up.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	var forests := 0
	for inst in game.all_battlefield():
		if inst.controller_id == source.controller_id and inst.is_land() \
				and inst.has_subtype("forest"):
			forests += 1
	host.cur_power += forests / 2
	host.cur_toughness += (forests + 1) / 2

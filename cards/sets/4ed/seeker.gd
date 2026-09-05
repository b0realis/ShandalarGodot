extends CardScript
## Seeker — {2}{W}{W} — Enchantment — Aura — (4ed, common)
## Oracle: Enchant creature
##         Enchanted creature can't be blocked except by artifact
##         creatures and/or white creatures.
##
## Implementation: a block-restriction aura (invisibility.gd pattern) —
## only artifact and/or white creatures may stand in the host's way.


func build() -> CardData:
	return CardData.new("Seeker", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply, "Enchanted creature can't be blocked except by artifact creatures and/or white creatures.")) \
		.oracle("Enchant creature\nEnchanted creature can't be blocked except by artifact creatures and/or white creatures.")


static func _artifact_or_white(blocker: CardInstance) -> bool:
	return blocker.is_type(Mtg.CardType.ARTIFACT) \
		or (blocker.cur_colors & Mtg.ManaColor.W) != 0


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_block_restrictions.append(
			{"desc": "artifact creatures and/or white creatures",
			 "filter": _artifact_or_white})

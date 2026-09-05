extends CardScript
## Fear — {B}{B} — Enchantment — Aura — (2ed, common)
## Oracle: Enchant creature (Target a creature as you cast this. This card
##         enters attached to that creature.)
##         Enchanted creature has fear. (It can't be blocked except by
##         artifact creatures and/or black creatures.)
##
## Implementation: keyword-granting aura (flight.gd pattern) — FEAR's
## block restriction lives in CombatState.block_illegality (CR 702.36).


func build() -> CardData:
	return CardData.new("Fear", "{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature has fear.")) \
		.oracle("Enchant creature\nEnchanted creature has fear. (It can't be blocked except by artifact creatures and/or black creatures.)")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD \
			and not host.cur_keywords.has(Mtg.Keyword.FEAR):
		host.cur_keywords.append(Mtg.Keyword.FEAR)

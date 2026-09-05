extends CardScript
## Evil Presence — {B} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant land
##         Enchanted land is a Swamp.
##
## Implementation: a static calling CardInstance.become_basic_land_type —
## the host's LIVE subtypes become exactly ["swamp"] and its LIVE mana
## abilities become "{T}: Add {B}". Because the engine reads
## cur_mana_abilities, the land really does tap for black now; and
## because it stops being a Forest, Aspect of Wolf and friends stop
## counting it. One black mana of colour screw.


func build() -> CardData:
	return CardData.new("Evil Presence", "{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land)) \
		.static_ability(StaticAbility.new(_apply, "Enchanted land is a Swamp.") \
			.changing_land_types()) \
		.oracle("Enchant land\nEnchanted land is a Swamp.")


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.become_basic_land_type("swamp", Mtg.ManaColor.B)

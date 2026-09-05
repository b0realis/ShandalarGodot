extends CardScript
## Psychic Venom — {1}{U} — Enchantment — Aura — (2ed, common)
## Oracle: Enchant land
##         Whenever enchanted land becomes tapped, Psychic Venom deals 2
##         damage to that land's controller.
##
## Implementation: an aura on a land whose trigger watches BECAME_TAPPED
## and matches when the tapping instance is its HOST — any tap stings:
## for mana, or an Icy Manipulator's effect. Blue's early-game land tax.


func build() -> CardData:
	var land_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
		func(inst: CardInstance) -> bool: return inst.is_land())
	return CardData.new("Psychic Venom", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(land_spec) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED,
			_sting,
			"Whenever enchanted land becomes tapped, Psychic Venom deals 2 damage to that land's controller.",
			_host_tapped)) \
		.oracle("Enchant land\nWhenever enchanted land becomes tapped, Psychic Venom deals 2 damage to that land's controller.")


static func _host_tapped(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var tapped: CardInstance = event.data["instance"]
	return source.attached_to == tapped.id


static func _sting(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var tapped: CardInstance = event.data["instance"]
	game.deal_damage(source, TargetRef.player(tapped.controller_id), 2)

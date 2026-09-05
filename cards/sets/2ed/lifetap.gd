extends CardScript
## Lifetap — {U}{U} — Enchantment — (2ed, uncommon)
## Oracle: Whenever a Forest an opponent controls becomes tapped, you gain
##         1 life.
##
## Implementation: a BECAME_TAPPED trigger (any tap: for mana, Icy, or
## attacking with an animated Forest) filtered to Forest-subtype lands the
## opponent controls — Underground... no, TROPICAL Island counts, exactly
## as the subtype rules say. Blue's anti-green sideboard classic.


func build() -> CardData:
	return CardData.new("Lifetap", "{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED, _gain,
			"Whenever a Forest an opponent controls becomes tapped, you gain 1 life.",
			_enemy_forest_tapped)) \
		.oracle("Whenever a Forest an opponent controls becomes tapped, you gain 1 life.")


static func _enemy_forest_tapped(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var inst: CardInstance = event.data["instance"]
	return inst.is_land() and inst.has_subtype("forest") \
		and inst.controller_id != source.controller_id


static func _gain(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.adjust_life(source.controller_id, 1)

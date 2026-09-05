extends CardScript
## Lifeblood — {2}{W}{W} — Enchantment — (leg, rare)
## Oracle: Whenever a Mountain an opponent controls becomes tapped, you
##         gain 1 life.
##
## Implementation: a BECAME_TAPPED trigger (the universal tap event the
## audit added for City of Brass) gated on the tapped permanent being a
## Mountain an opponent controls — so it pays whether they tapped for
## mana, paid a tap cost, or were tapped by an Icy Manipulator. A pure
## sideboard hoser from the era when hosers were maindecked.


func build() -> CardData:
	return CardData.new("Lifeblood", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED, _gain,
			"Whenever a Mountain an opponent controls becomes tapped, you gain 1 life.",
			_their_mountain)) \
		.oracle("Whenever a Mountain an opponent controls becomes tapped, you gain 1 life.")


static func _their_mountain(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var inst: CardInstance = event.data["instance"]
	return inst != null and inst.controller_id != source.controller_id \
		and inst.is_land() and inst.has_subtype("mountain")


static func _gain(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.adjust_life(source.controller_id, 1)

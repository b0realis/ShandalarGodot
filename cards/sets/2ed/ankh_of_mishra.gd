extends CardScript
## Ankh of Mishra — {2} — Artifact (Alpha, rare)
## Oracle: Whenever a land enters the battlefield, Ankh of Mishra deals 2
##         damage to that land's controller.
##
## Implementation: the reference example of a TRIGGERED ability. It listens
## for ENTERS_BATTLEFIELD events gated on the entrant being a LAND — so it
## stings lands however they arrive: played normally OR fetched onto the
## battlefield (Untamed Wilds). Reads "that land's controller" straight
## from the event context — no targeting involved. Punishes BOTH players,
## including its own controller, exactly as printed.


func build() -> CardData:
	return CardData.new("Ankh of Mishra", "{2}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD,
			_on_land_entered,
			"Whenever a land enters the battlefield, Ankh of Mishra deals 2 damage to that land's controller.",
			_a_land_entered)) \
		.oracle("Whenever a land enters the battlefield, Ankh of Mishra deals 2 damage to that land's controller.")


static func _a_land_entered(_game: MtgGame, _source: CardInstance, event: GameEvent) -> bool:
	var entrant: CardInstance = event.data["instance"]
	return entrant.is_land()


static func _on_land_entered(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var land_controller: int = event.data["controller"]
	game.deal_damage(source, TargetRef.player(land_controller), 2)

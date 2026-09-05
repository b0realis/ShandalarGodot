extends CardScript
## Dingus Egg — {4} — Artifact — (2ed, rare)
## Oracle: Whenever a land is put into a graveyard from the battlefield,
##         this artifact deals 2 damage to that land's controller.
##
## Implementation: a DIES trigger filtered to lands — destruction
## (Sinkhole, Armageddon) and sacrifice (Strip Mine) both route through
## the graveyard and both fire it; a bounced land doesn't. Punishes BOTH
## players' land losses, including the Egg controller's own.


func build() -> CardData:
	return CardData.new("Dingus Egg", "{4}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _crack,
			"Whenever a land is put into a graveyard from the battlefield, this artifact deals 2 damage to that land's controller.",
			_a_land_died)) \
		.oracle("Whenever a land is put into a graveyard from the battlefield, this artifact deals 2 damage to that land's controller.")


static func _a_land_died(_game: MtgGame, _source: CardInstance, event: GameEvent) -> bool:
	var inst: CardInstance = event.data["instance"]
	return inst.data.is_land()


static func _crack(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(event.data["controller"]), 2)

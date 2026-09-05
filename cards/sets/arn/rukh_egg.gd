extends CardScript
## Rukh Egg — {3}{R} — Creature — Bird Egg — 0/3 — (arn, common)
## Oracle: When this creature dies, create a 4/4 red Bird creature token
##         with flying at the beginning of the next end step.
##
## Implementation: a DIES trigger that QUEUES the bird with
## MtgGame.schedule_end_step_token instead of making it now — the engine
## creates it when the next end step begins, which is exactly the printed
## delay (and survives the Egg itself being long gone). The Egg is a 0/3
## wall the opponent cannot profitably kill.


func build() -> CardData:
	return CardData.new("Rukh Egg", "{3}{R}", Mtg.CardType.CREATURE) \
		.pt(0, 3) \
		.with_subtypes(["bird", "egg"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _crack,
			"When Rukh Egg dies, create a 4/4 red Bird creature token with flying at "
			+ "the beginning of the next end step.",
			_is_self)) \
		.oracle("When this creature dies, create a 4/4 red Bird creature token with "
			+ "flying at the beginning of the next end step.")


static func rukh_data() -> CardData:
	return CardData.new("Rukh", "", Mtg.CardType.CREATURE) \
		.with_colors(Mtg.ManaColor.R) \
		.pt(4, 4) \
		.with_subtypes(["bird"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.oracle("Flying")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _crack(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.schedule_end_step_token(int(event.data.get("controller", source.owner_id)),
		rukh_data())

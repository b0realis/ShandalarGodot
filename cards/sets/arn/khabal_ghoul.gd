extends CardScript
## Khabál Ghoul — {2}{B} — Creature — Zombie — 1/1 — (arn, uncommon)
## Oracle: At the beginning of each end step, put a +1/+1 counter on this
##         creature for each creature that died this turn.
##
## Implementation: an END_STEP_START trigger (EACH end step, both turns)
## reading the engine's creatures_died_this_turn counter and banking that
## many permanent +1/+1 counters. Board wipes make it enormous.


func build() -> CardData:
	return CardData.new("Khabál Ghoul", "{2}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["zombie"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START, _feast,
			"At the beginning of each end step, put a +1/+1 counter on this creature for each creature that died this turn.")) \
		.oracle("At the beginning of each end step, put a +1/+1 counter on this creature for each creature that died this turn.")


static func _feast(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD and game.creatures_died_this_turn > 0:
		game.add_counters(source, "+1/+1", game.creatures_died_this_turn)

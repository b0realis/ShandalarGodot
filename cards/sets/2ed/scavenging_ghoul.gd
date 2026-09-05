extends CardScript
## Scavenging Ghoul — {3}{B} — Creature — Zombie — 2/2 — (2ed, uncommon)
## Oracle: At the beginning of each end step, put a corpse counter on this
##         creature for each creature that died this turn.
##         Remove a corpse counter from this creature: Regenerate this
##         creature.
##
## Implementation: an END_STEP_START trigger reading
## MtgGame.creatures_died_this_turn (the engine's per-turn body count,
## cleared at cleanup) plus a regeneration ability whose COST is removing
## a corpse counter (ActivatedAbility.with_counter_cost — paid on
## activation, CR 601.2h, so one counter can never buy two shields).
## "corpse" is not a P/T counter name, so the characteristics pipeline
## ignores it — exactly right.


func build() -> CardData:
	return CardData.new("Scavenging Ghoul", "{3}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["zombie"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START, _feast,
			"At the beginning of each end step, put a corpse counter on Scavenging "
			+ "Ghoul for each creature that died this turn.")) \
		.activated(ActivatedAbility.new(
			"", false, [RegenerateEffect.new()],
			"Remove a corpse counter from Scavenging Ghoul: Regenerate it.") \
			.with_counter_cost("corpse", 1)) \
		.oracle("At the beginning of each end step, put a corpse counter on this "
			+ "creature for each creature that died this turn.\nRemove a corpse "
			+ "counter from this creature: Regenerate this creature.")


static func _feast(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD and game.creatures_died_this_turn > 0:
		game.add_counters(source, "corpse", game.creatures_died_this_turn)

extends CardScript
## Osai Vultures — {1}{W} — Creature — Bird — 1/1 — (4ed, uncommon)
## Oracle: Flying
##         At the beginning of each end step, if a creature died this turn,
##         put a carrion counter on this creature.
##         Remove two carrion counters from this creature: This creature
##         gets +1/+1 until end of turn.
##
## Implementation: an END_STEP_START trigger with an intervening "if" on
## MtgGame.creatures_died_this_turn (re-checked at resolution, CR 603.4)
## plus a pump whose COST is removing two carrion counters
## (ActivatedAbility.with_counter_cost — paid on activation, CR 601.2h).
## Exactly ONE counter per turn, no matter how many creatures died.


func build() -> CardData:
	return CardData.new("Osai Vultures", "{1}{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["bird"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START, _feed,
			"At the beginning of each end step, if a creature died this turn, put a "
			+ "carrion counter on Osai Vultures.",
			_something_died)) \
		.activated(ActivatedAbility.new(
			"", false, [PumpEffect.new(1, 1).self_buff()],
			"Remove two carrion counters from Osai Vultures: It gets +1/+1 until end of turn.") \
			.with_counter_cost("carrion", 2)) \
		.oracle("Flying\nAt the beginning of each end step, if a creature died this "
			+ "turn, put a carrion counter on this creature.\nRemove two carrion "
			+ "counters from this creature: This creature gets +1/+1 until end of turn.")


static func _something_died(game: MtgGame, _source: CardInstance,
		_event: GameEvent) -> bool:
	return game.creatures_died_this_turn > 0


static func _feed(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD and game.creatures_died_this_turn > 0:
		game.add_counters(source, "carrion", 1)

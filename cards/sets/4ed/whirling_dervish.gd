extends CardScript
## Whirling Dervish — {G}{G} — Creature — Human Monk — 1/1 — (4ed, uncommon)
## Oracle: Protection from black
##         At the beginning of each end step, if this creature dealt
##         damage to an opponent this turn, put a +1/+1 counter on it.
##
## Implementation: printed protection from black (so black removal can't
## even target it) plus an END_STEP_START trigger with an intervening
## "if" — re-checked at resolution (CR 603.4) against the per-turn
## damaged-players list MtgGame.deal_damage maintains. Green's classic
## anti-black beater: unanswerable by mono-black and growing every turn.


func build() -> CardData:
	return CardData.new("Whirling Dervish", "{G}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "monk"]) \
		.with_protection_from(Mtg.ManaColor.B) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START, _grow,
			"At the beginning of each end step, if Whirling Dervish dealt damage to "
			+ "an opponent this turn, put a +1/+1 counter on it.",
			_connected)) \
		.oracle("Protection from black\nAt the beginning of each end step, if this "
			+ "creature dealt damage to an opponent this turn, put a +1/+1 counter on it.")


static func _hit_an_opponent(source: CardInstance) -> bool:
	for pid in source.damaged_players_this_turn:
		if pid != source.controller_id:
			return true
	return false


static func _connected(_game: MtgGame, source: CardInstance, _event: GameEvent) -> bool:
	return _hit_an_opponent(source)


static func _grow(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD and _hit_an_opponent(source):
		game.add_counters(source, "+1/+1", 1)

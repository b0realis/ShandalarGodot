extends CardScript
## Giant Turtle — {1}{G}{G} — Creature — Turtle — 2/4 — (leg, common)
## Oracle: This creature can't attack if it attacked during your last turn.
##
## Implementation: a DECLARED_ATTACKERS trigger raising the engine's
## cant_attack_next_turn flag (Wall of Dust's mechanism) whenever the
## Turtle is among the attackers — the untap step then shifts it into
## cant_attack_this_turn and clears it a turn later. A 2/4 that attacks
## every other turn.


func build() -> CardData:
	return CardData.new("Giant Turtle", "{1}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_subtypes(["turtle"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DECLARED_ATTACKERS, _rest,
			"Giant Turtle can't attack if it attacked during your last turn.",
			_it_attacked)) \
		.oracle("This creature can't attack if it attacked during your last turn.")


static func _it_attacked(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	for inst in event.data.get("attackers", []):
		if inst == source:
			return true
	return false


static func _rest(_game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	source.cant_attack_next_turn = true

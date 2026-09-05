extends CardScript
## Mijae Djinn — {R}{R}{R} — Creature — Djinn — 6/3 — (arn, rare)
## Oracle: Whenever this creature attacks, flip a coin. If you lose the
##         flip, remove this creature from combat and tap it.
##
## Implementation: a DECLARED_ATTACKERS trigger that flips a coin and, on
## a loss, calls MtgGame.remove_from_combat and taps the Djinn. Six power
## for three mana, half the time.


func build() -> CardData:
	return CardData.new("Mijae Djinn", "{R}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(6, 3) \
		.with_subtypes(["djinn"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DECLARED_ATTACKERS, _gamble,
			"Whenever Mijae Djinn attacks, flip a coin. If you lose the flip, remove "
			+ "it from combat and tap it.",
			_it_attacked)) \
		.oracle("Whenever this creature attacks, flip a coin. If you lose the flip, "
			+ "remove this creature from combat and tap it.")


static func _it_attacked(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	for inst in event.data.get("attackers", []):
		if inst == source:
			return true
	return false


static func _gamble(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	if game.flip_coin(source.controller_id):
		return
	game.remove_from_combat(source)
	game.tap_permanent(source)

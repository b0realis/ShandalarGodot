extends CardScript
## Ball Lightning — {R}{R}{R} — Creature — Elemental — 6/1 — (4ed, rare)
## Oracle: Trample
##         Haste
##         At the beginning of the end step, sacrifice this creature.
##
## Implementation: printed trample and haste plus an END_STEP_START
## trigger that sacrifices it — EACH end step, not just yours, so a Ball
## Lightning that somehow survives an opponent's turn still goes away.
## Six trampling damage the turn it lands; nothing else.


func build() -> CardData:
	return CardData.new("Ball Lightning", "{R}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(6, 1) \
		.with_subtypes(["elemental"]) \
		.with_keywords([Mtg.Keyword.TRAMPLE, Mtg.Keyword.HASTE]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START, _fizzle,
			"At the beginning of the end step, sacrifice Ball Lightning.")) \
		.oracle("Trample\nHaste\nAt the beginning of the end step, sacrifice this creature.")


static func _fizzle(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.sacrifice_permanent(source)

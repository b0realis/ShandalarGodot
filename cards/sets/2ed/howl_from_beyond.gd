extends CardScript
## Howl from Beyond — {X}{B} — Instant (2ed, common)
## Oracle: Target creature gets +X/+0 until end of turn.
##
## Implementation: PumpEffect's X mode — the finisher pump (an unblocked
## creature plus a big X ends games; the AI's firebreathing logic already
## understands the shape).


func build() -> CardData:
	return CardData.new("Howl from Beyond", "{X}{B}", Mtg.CardType.INSTANT) \
		.spell(PumpEffect.new(0, 0).x_power()) \
		.oracle("Target creature gets +X/+0 until end of turn.")

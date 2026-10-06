extends CardScript
## Necrologia — {3}{B}{B} — Instant (uncommon, exo).
## Oracle: Cast this spell only during your end step.
##         As an additional cost to cast this spell, pay X life.
##         Draw X cards.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Necrologia", "{3}{B}{B}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during your end step.\nAs an additional cost to cast this spell, pay X life.\nDraw X cards.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

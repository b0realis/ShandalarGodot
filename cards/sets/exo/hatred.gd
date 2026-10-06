extends CardScript
## Hatred — {3}{B}{B} — Instant (rare, exo).
## Oracle: As an additional cost to cast this spell, pay X life.
##         Target creature gets +X/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hatred", "{3}{B}{B}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, pay X life.\nTarget creature gets +X/+0 until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

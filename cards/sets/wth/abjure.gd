extends CardScript
## Abjure — {U} — Instant (common, wth).
## Oracle: As an additional cost to cast this spell, sacrifice a blue permanent.
##         Counter target spell.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Abjure", "{U}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, sacrifice a blue permanent.\nCounter target spell.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

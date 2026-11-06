extends CardScript
## Headlong Rush — {1}{R} — Instant (common, usg).
## Oracle: Attacking creatures gain first strike until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Headlong Rush", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("Attacking creatures gain first strike until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

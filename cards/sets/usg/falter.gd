extends CardScript
## Falter — {1}{R} — Instant (common, usg).
## Oracle: Creatures without flying can't block this turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Falter", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("Creatures without flying can't block this turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

extends CardScript
## Fling — {1}{R} — Instant (common, sth).
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
##         Fling deals damage equal to the sacrificed creature's power to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fling", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, sacrifice a creature.\nFling deals damage equal to the sacrificed creature's power to any target.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

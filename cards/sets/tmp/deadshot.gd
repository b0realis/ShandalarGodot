extends CardScript
## Deadshot — {3}{R} — Sorcery (rare, tmp).
## Oracle: Tap target creature. It deals damage equal to its power to another target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Deadshot", "{3}{R}", Mtg.CardType.SORCERY)
	c.oracle("Tap target creature. It deals damage equal to its power to another target creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

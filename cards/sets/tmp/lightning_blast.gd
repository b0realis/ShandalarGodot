extends CardScript
## Lightning Blast — {3}{R} — Instant (common, tmp).
## Oracle: Lightning Blast deals 4 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lightning Blast", "{3}{R}", Mtg.CardType.INSTANT)
	c.oracle("Lightning Blast deals 4 damage to any target.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

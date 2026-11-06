extends CardScript
## Subversion — {3}{B}{B} — Enchantment (rare, ulg).
## Oracle: At the beginning of your upkeep, each opponent loses 1 life. You gain life equal to the life lost this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Subversion", "{3}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, each opponent loses 1 life. You gain life equal to the life lost this way.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

extends CardScript
## Kindle — {1}{R} — Instant (common, tmp).
## Oracle: Kindle deals X damage to any target, where X is 2 plus the number of cards named Kindle in all graveyards.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kindle", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("Kindle deals X damage to any target, where X is 2 plus the number of cards named Kindle in all graveyards.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

extends CardScript
## Mana Leak — {1}{U} — Instant (common, sth).
## Oracle: Counter target spell unless its controller pays {3}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mana Leak", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target spell unless its controller pays {3}.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

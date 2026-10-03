extends CardScript
## Impulse — {1}{U} — Instant (common, vis).
## Oracle: Look at the top four cards of your library. Put one of them into your hand and the rest on the bottom of your library in any order.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Impulse", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Look at the top four cards of your library. Put one of them into your hand and the rest on the bottom of your library in any order.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

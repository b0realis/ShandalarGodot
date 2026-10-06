extends CardScript
## Ransack — {3}{U} — Sorcery (uncommon, sth).
## Oracle: Look at the top five cards of target player's library. Put any number of them on the bottom of that library in any order and the rest on top of the library in any order.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ransack", "{3}{U}", Mtg.CardType.SORCERY)
	c.oracle("Look at the top five cards of target player's library. Put any number of them on the bottom of that library in any order and the rest on top of the library in any order.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

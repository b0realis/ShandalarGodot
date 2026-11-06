extends CardScript
## Defense of the Heart — {3}{G} — Enchantment (rare, ulg).
## Oracle: At the beginning of your upkeep, if an opponent controls three or more creatures, sacrifice this enchantment, search your library for up to two creature cards, put those cards onto the battlefield, then shuffle.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Defense of the Heart", "{3}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, if an opponent controls three or more creatures, sacrifice this enchantment, search your library for up to two creature cards, put those cards onto the battlefield, then shuffle.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

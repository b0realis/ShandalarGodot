extends CardScript
## Mental Discipline — {1}{U}{U} — Enchantment (common, uds).
## Oracle: {1}{U}, Discard a card: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mental Discipline", "{1}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{1}{U}, Discard a card: Draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

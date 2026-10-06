extends CardScript
## Manabond — {G} — Enchantment (rare, exo).
## Oracle: At the beginning of your end step, you may reveal your hand and put all land cards from it onto the battlefield. If you do, discard your hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Manabond", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your end step, you may reveal your hand and put all land cards from it onto the battlefield. If you do, discard your hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

extends CardScript
## Mortuary — {3}{B} — Enchantment (rare, sth).
## Oracle: Whenever a creature is put into your graveyard from the battlefield, put that card on top of your library.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mortuary", "{3}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature is put into your graveyard from the battlefield, put that card on top of your library.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

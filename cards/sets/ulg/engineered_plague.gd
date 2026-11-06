extends CardScript
## Engineered Plague — {2}{B} — Enchantment (uncommon, ulg).
## Oracle: As this enchantment enters, choose a creature type.
##         All creatures of the chosen type get -1/-1.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Engineered Plague", "{2}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("As this enchantment enters, choose a creature type.\nAll creatures of the chosen type get -1/-1.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

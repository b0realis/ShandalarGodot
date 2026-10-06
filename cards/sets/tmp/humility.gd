extends CardScript
## Humility — {2}{W}{W} — Enchantment (rare, tmp).
## Oracle: All creatures lose all abilities and have base power and toughness 1/1.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Humility", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("All creatures lose all abilities and have base power and toughness 1/1.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

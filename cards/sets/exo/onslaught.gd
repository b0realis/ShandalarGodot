extends CardScript
## Onslaught — {R} — Enchantment (common, exo).
## Oracle: Whenever you cast a creature spell, tap target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Onslaught", "{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever you cast a creature spell, tap target creature.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

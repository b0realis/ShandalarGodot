extends CardScript
## Pandemonium — {3}{R} — Enchantment (rare, exo).
## Oracle: Whenever a creature enters, that creature's controller may have it deal damage equal to its power to any target of their choice.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pandemonium", "{3}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature enters, that creature's controller may have it deal damage equal to its power to any target of their choice.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

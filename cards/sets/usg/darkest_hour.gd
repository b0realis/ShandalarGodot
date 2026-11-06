extends CardScript
## Darkest Hour — {B} — Enchantment (rare, usg).
## Oracle: All creatures are black.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Darkest Hour", "{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("All creatures are black.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

extends CardScript
## High Ground — {W} — Enchantment (uncommon, exo).
## Oracle: Each creature you control can block an additional creature each combat.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("High Ground", "{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Each creature you control can block an additional creature each combat.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

extends CardScript
## Familiar Ground — {2}{G} — Enchantment (uncommon, wth).
## Oracle: Each creature you control can't be blocked by more than one creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Familiar Ground", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Each creature you control can't be blocked by more than one creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

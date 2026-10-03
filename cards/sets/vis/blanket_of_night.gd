extends CardScript
## Blanket of Night — {1}{B}{B} — Enchantment (uncommon, vis).
## Oracle: Each land is a Swamp in addition to its other land types.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blanket of Night", "{1}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Each land is a Swamp in addition to its other land types.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

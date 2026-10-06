extends CardScript
## Broken Fall — {2}{G} — Enchantment (common, tmp).
## Oracle: Return this enchantment to its owner's hand: Regenerate target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Broken Fall", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Return this enchantment to its owner's hand: Regenerate target creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

extends CardScript
## Dense Foliage — {2}{G} — Enchantment (rare, wth).
## Oracle: Creatures can't be the targets of spells.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dense Foliage", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures can't be the targets of spells.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

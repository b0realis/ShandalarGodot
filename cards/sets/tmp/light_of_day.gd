extends CardScript
## Light of Day — {3}{W} — Enchantment (uncommon, tmp).
## Oracle: Black creatures can't attack or block.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Light of Day", "{3}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Black creatures can't attack or block.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

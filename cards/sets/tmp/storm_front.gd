extends CardScript
## Storm Front — {G} — Enchantment (uncommon, tmp).
## Oracle: {G}{G}: Tap target creature with flying.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Storm Front", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{G}{G}: Tap target creature with flying.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

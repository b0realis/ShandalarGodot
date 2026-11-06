extends CardScript
## Douse — {2}{U} — Enchantment (uncommon, usg).
## Oracle: {1}{U}: Counter target red spell.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Douse", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{1}{U}: Counter target red spell.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

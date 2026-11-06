extends CardScript
## Lurking Evil — {B}{B}{B} — Enchantment (rare, usg).
## Oracle: Pay half your life, rounded up: This enchantment becomes a 4/4 Phyrexian Horror creature with flying.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lurking Evil", "{B}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Pay half your life, rounded up: This enchantment becomes a 4/4 Phyrexian Horror creature with flying.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

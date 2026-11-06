extends CardScript
## Angelic Chorus — {3}{W}{W} — Enchantment (rare, usg).
## Oracle: Whenever a creature you control enters, you gain life equal to its toughness.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Angelic Chorus", "{3}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature you control enters, you gain life equal to its toughness.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

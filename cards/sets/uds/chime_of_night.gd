extends CardScript
## Chime of Night — {1}{B} — Enchantment — Aura (common, uds).
## Oracle: Enchant creature
##         When this Aura is put into a graveyard from the battlefield, destroy target nonblack creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Chime of Night", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen this Aura is put into a graveyard from the battlefield, destroy target nonblack creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

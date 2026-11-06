extends CardScript
## Pattern of Rebirth — {3}{G} — Enchantment — Aura (rare, uds).
## Oracle: Enchant creature
##         When enchanted creature dies, that creature's controller may search their library for a creature card, put that card onto the battlefield, then shuffle.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pattern of Rebirth", "{3}{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen enchanted creature dies, that creature's controller may search their library for a creature card, put that card onto the battlefield, then shuffle.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

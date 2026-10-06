extends CardScript
## Contempt — {1}{U} — Enchantment — Aura (common, sth).
## Oracle: Enchant creature
##         When enchanted creature attacks, return it and this Aura to their owners' hands at end of combat.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Contempt", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen enchanted creature attacks, return it and this Aura to their owners' hands at end of combat.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

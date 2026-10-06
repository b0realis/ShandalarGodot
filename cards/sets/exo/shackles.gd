extends CardScript
## Shackles — {2}{W} — Enchantment — Aura (common, exo).
## Oracle: Enchant creature
##         Enchanted creature doesn't untap during its controller's untap step.
##         {W}: Return this Aura to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shackles", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature doesn't untap during its controller's untap step.\n{W}: Return this Aura to its owner's hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

extends CardScript
## Bequeathal — {G} — Enchantment — Aura (common, exo).
## Oracle: Enchant creature
##         When enchanted creature dies, you draw two cards.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bequeathal", "{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen enchanted creature dies, you draw two cards.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

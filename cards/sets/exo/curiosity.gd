extends CardScript
## Curiosity — {U} — Enchantment — Aura (uncommon, exo).
## Oracle: Enchant creature
##         Whenever enchanted creature deals damage to an opponent, you may draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Curiosity", "{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhenever enchanted creature deals damage to an opponent, you may draw a card.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

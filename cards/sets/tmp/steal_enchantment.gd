extends CardScript
## Steal Enchantment — {U}{U} — Enchantment — Aura (uncommon, tmp).
## Oracle: Enchant enchantment
##         You control enchanted enchantment.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Steal Enchantment", "{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant enchantment\nYou control enchanted enchantment.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

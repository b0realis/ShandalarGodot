extends CardScript
## Hero's Resolve — {1}{W} — Enchantment — Aura (common, tmp).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+5.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hero's Resolve", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+5.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

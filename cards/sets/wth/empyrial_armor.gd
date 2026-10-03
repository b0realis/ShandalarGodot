extends CardScript
## Empyrial Armor — {1}{W}{W} — Enchantment — Aura (common, wth).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+1 for each card in your hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Empyrial Armor", "{1}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+1 for each card in your hand.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

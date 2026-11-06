extends CardScript
## Private Research — {U} — Enchantment — Aura (uncommon, uds).
## Oracle: Enchant creature
##         At the beginning of your upkeep, you may put a page counter on this Aura.
##         When enchanted creature dies, draw a card for each page counter on this Aura.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Private Research", "{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nAt the beginning of your upkeep, you may put a page counter on this Aura.\nWhen enchanted creature dies, draw a card for each page counter on this Aura.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

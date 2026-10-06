extends CardScript
## Overgrowth — {2}{G} — Enchantment — Aura (common, sth).
## Oracle: Enchant land
##         Whenever enchanted land is tapped for mana, its controller adds an additional {G}{G}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Overgrowth", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant land\nWhenever enchanted land is tapped for mana, its controller adds an additional {G}{G}.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

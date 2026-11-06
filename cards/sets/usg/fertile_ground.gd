extends CardScript
## Fertile Ground — {1}{G} — Enchantment — Aura (common, usg).
## Oracle: Enchant land
##         Whenever enchanted land is tapped for mana, its controller adds an additional one mana of any color.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fertile Ground", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant land\nWhenever enchanted land is tapped for mana, its controller adds an additional one mana of any color.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

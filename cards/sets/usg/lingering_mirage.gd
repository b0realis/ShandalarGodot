extends CardScript
## Lingering Mirage — {1}{U} — Enchantment — Aura (uncommon, usg).
## Oracle: Enchant land
##         Enchanted land is an Island.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lingering Mirage", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant land\nEnchanted land is an Island.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

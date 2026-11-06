extends CardScript
## Confiscate — {4}{U}{U} — Enchantment — Aura (uncommon, usg).
## Oracle: Enchant permanent
##         You control enchanted permanent.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Confiscate", "{4}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant permanent\nYou control enchanted permanent.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

extends CardScript
## Zephid's Embrace — {2}{U}{U} — Enchantment — Aura (uncommon, usg).
## Oracle: Enchant creature
##         Enchanted creature gets +2/+2 and has flying and shroud. (It can't be the target of spells or abilities.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Zephid's Embrace", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +2/+2 and has flying and shroud. (It can't be the target of spells or abilities.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

extends CardScript
## Vampiric Embrace — {2}{B}{B} — Enchantment — Aura (uncommon, usg).
## Oracle: Enchant creature
##         Enchanted creature gets +2/+2 and has flying.
##         Whenever a creature dealt damage by enchanted creature this turn dies, put a +1/+1 counter on that creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vampiric Embrace", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +2/+2 and has flying.\nWhenever a creature dealt damage by enchanted creature this turn dies, put a +1/+1 counter on that creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

extends CardScript
## Consuming Ferocity — {1}{R} — Enchantment — Aura (uncommon, mir).
## Oracle: Enchant non-Wall creature
##         Enchanted creature gets +1/+0.
##         At the beginning of your upkeep, put a +1/+0 counter on enchanted creature. If that creature has three or more +1/+0 counters on it, it deals damage equal to its power to its controller, then destroy that creature and it can't be regenerated.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Consuming Ferocity", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant non-Wall creature\nEnchanted creature gets +1/+0.\nAt the beginning of your upkeep, put a +1/+0 counter on enchanted creature. If that creature has three or more +1/+0 counters on it, it deals damage equal to its power to its controller, then destroy that creature and it can't be regenerated.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

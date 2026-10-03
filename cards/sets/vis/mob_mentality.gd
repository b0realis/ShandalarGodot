extends CardScript
## Mob Mentality — {R} — Enchantment — Aura (uncommon, vis).
## Oracle: Enchant creature
##         Enchanted creature has trample.
##         Whenever all non-Wall creatures you control attack, enchanted creature gets +X/+0 until end of turn, where X is the number of attacking creatures.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mob Mentality", "{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has trample.\nWhenever all non-Wall creatures you control attack, enchanted creature gets +X/+0 until end of turn, where X is the number of attacking creatures.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

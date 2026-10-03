extends CardScript
## Betrothed of Fire — {1}{R} — Enchantment — Aura (common, wth).
## Oracle: Enchant creature
##         Sacrifice an untapped creature: Enchanted creature gets +2/+0 until end of turn.
##         Sacrifice enchanted creature: Creatures you control get +2/+0 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Betrothed of Fire", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nSacrifice an untapped creature: Enchanted creature gets +2/+0 until end of turn.\nSacrifice enchanted creature: Creatures you control get +2/+0 until end of turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

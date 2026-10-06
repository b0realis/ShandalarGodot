extends CardScript
## Tooth and Claw — {3}{R} — Enchantment (rare, tmp).
## Oracle: Sacrifice two creatures: Create a 3/1 red Beast creature token named Carnivore.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tooth and Claw", "{3}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Sacrifice two creatures: Create a 3/1 red Beast creature token named Carnivore.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

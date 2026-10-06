extends CardScript
## Heat of Battle — {1}{R} — Enchantment (uncommon, sth).
## Oracle: Whenever a creature blocks, this enchantment deals 1 damage to that creature's controller.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Heat of Battle", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature blocks, this enchantment deals 1 damage to that creature's controller.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

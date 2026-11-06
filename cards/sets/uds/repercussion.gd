extends CardScript
## Repercussion — {1}{R}{R} — Enchantment (rare, uds).
## Oracle: Whenever a creature is dealt damage, this enchantment deals that much damage to that creature's controller.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Repercussion", "{1}{R}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature is dealt damage, this enchantment deals that much damage to that creature's controller.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

extends CardScript
## Lightning Cloud — {3}{R} — Enchantment (rare, vis).
## Oracle: Whenever a player casts a red spell, you may pay {R}. If you do, this enchantment deals 1 damage to any target.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lightning Cloud", "{3}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a player casts a red spell, you may pay {R}. If you do, this enchantment deals 1 damage to any target.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

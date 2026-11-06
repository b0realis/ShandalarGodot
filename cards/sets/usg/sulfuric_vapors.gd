extends CardScript
## Sulfuric Vapors — {3}{R} — Enchantment (rare, usg).
## Oracle: If a red spell would deal damage to a permanent or player, it deals that much damage plus 1 to that permanent or player instead.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sulfuric Vapors", "{3}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("If a red spell would deal damage to a permanent or player, it deals that much damage plus 1 to that permanent or player instead.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

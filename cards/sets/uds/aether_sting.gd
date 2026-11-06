extends CardScript
## Aether Sting — {3}{R} — Enchantment (uncommon, uds).
## Oracle: Whenever an opponent casts a creature spell, this enchantment deals 1 damage to that player.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Aether Sting", "{3}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever an opponent casts a creature spell, this enchantment deals 1 damage to that player.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

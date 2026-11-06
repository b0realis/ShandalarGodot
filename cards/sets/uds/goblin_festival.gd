extends CardScript
## Goblin Festival — {1}{R} — Enchantment (rare, uds).
## Oracle: {2}: This enchantment deals 1 damage to any target. Flip a coin. If you lose the flip, choose one of your opponents. That player gains control of this enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Festival", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{2}: This enchantment deals 1 damage to any target. Flip a coin. If you lose the flip, choose one of your opponents. That player gains control of this enchantment.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

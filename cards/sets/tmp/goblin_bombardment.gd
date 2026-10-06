extends CardScript
## Goblin Bombardment — {1}{R} — Enchantment (uncommon, tmp).
## Oracle: Sacrifice a creature: This enchantment deals 1 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Bombardment", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Sacrifice a creature: This enchantment deals 1 damage to any target.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

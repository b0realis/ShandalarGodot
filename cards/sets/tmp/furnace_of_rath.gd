extends CardScript
## Furnace of Rath — {1}{R}{R}{R} — Enchantment (rare, tmp).
## Oracle: If a source would deal damage to a permanent or player, it deals double that damage to that permanent or player instead.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Furnace of Rath", "{1}{R}{R}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("If a source would deal damage to a permanent or player, it deals double that damage to that permanent or player instead.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

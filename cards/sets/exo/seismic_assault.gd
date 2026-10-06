extends CardScript
## Seismic Assault — {R}{R}{R} — Enchantment (rare, exo).
## Oracle: Discard a land card: This enchantment deals 2 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Seismic Assault", "{R}{R}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Discard a land card: This enchantment deals 2 damage to any target.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

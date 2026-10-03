extends CardScript
## Aether Flash — {2}{R}{R} — Enchantment (uncommon, wth).
## Oracle: Whenever a creature enters, this enchantment deals 2 damage to it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Aether Flash", "{2}{R}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature enters, this enchantment deals 2 damage to it.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

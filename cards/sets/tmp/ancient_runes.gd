extends CardScript
## Ancient Runes — {2}{R} — Enchantment (uncommon, tmp).
## Oracle: At the beginning of each player's upkeep, this enchantment deals damage to that player equal to the number of artifacts they control.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ancient Runes", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each player's upkeep, this enchantment deals damage to that player equal to the number of artifacts they control.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

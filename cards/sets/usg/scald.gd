extends CardScript
## Scald — {1}{R} — Enchantment (uncommon, usg).
## Oracle: Whenever a player taps an Island for mana, this enchantment deals 1 damage to that player.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scald", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a player taps an Island for mana, this enchantment deals 1 damage to that player.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

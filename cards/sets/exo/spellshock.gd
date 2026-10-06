extends CardScript
## Spellshock — {2}{R} — Enchantment (uncommon, exo).
## Oracle: Whenever a player casts a spell, this enchantment deals 2 damage to that player.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spellshock", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a player casts a spell, this enchantment deals 2 damage to that player.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

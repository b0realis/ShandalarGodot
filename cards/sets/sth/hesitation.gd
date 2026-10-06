extends CardScript
## Hesitation — {1}{U} — Enchantment (uncommon, sth).
## Oracle: When a player casts a spell, sacrifice this enchantment and counter that spell.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hesitation", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When a player casts a spell, sacrifice this enchantment and counter that spell.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

extends CardScript
## Veiled Sentry — {U} — Enchantment (uncommon, usg).
## Oracle: When an opponent casts a spell, if this permanent is an enchantment, it becomes an Illusion creature with power and toughness each equal to that spell's mana value.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Veiled Sentry", "{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts a spell, if this permanent is an enchantment, it becomes an Illusion creature with power and toughness each equal to that spell's mana value.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

extends CardScript
## Veiled Apparition — {1}{U} — Enchantment (uncommon, usg).
## Oracle: When an opponent casts a spell, if this permanent is an enchantment, it becomes a 3/3 Illusion creature with flying and "At the beginning of your upkeep, sacrifice this creature unless you pay {1}{U}."
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Veiled Apparition", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts a spell, if this permanent is an enchantment, it becomes a 3/3 Illusion creature with flying and \"At the beginning of your upkeep, sacrifice this creature unless you pay {1}{U}.\"")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

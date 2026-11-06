extends CardScript
## Veiled Crocodile — {2}{U} — Enchantment (rare, usg).
## Oracle: When a player has no cards in hand, if this permanent is an enchantment, it becomes a 4/4 Crocodile creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Veiled Crocodile", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When a player has no cards in hand, if this permanent is an enchantment, it becomes a 4/4 Crocodile creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

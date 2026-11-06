extends CardScript
## Exploration — {G} — Enchantment (rare, usg).
## Oracle: You may play an additional land on each of your turns.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Exploration", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("You may play an additional land on each of your turns.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

extends CardScript
## Pendrell Mists — {3}{U} — Enchantment (rare, wth).
## Oracle: All creatures have "At the beginning of your upkeep, sacrifice this creature unless you pay {1}."
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pendrell Mists", "{3}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("All creatures have \"At the beginning of your upkeep, sacrifice this creature unless you pay {1}.\"")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

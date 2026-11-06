extends CardScript
## Second Chance — {2}{U} — Enchantment (rare, ulg).
## Oracle: At the beginning of your upkeep, if you have 5 or less life, sacrifice this enchantment and take an extra turn after this one.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Second Chance", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, if you have 5 or less life, sacrifice this enchantment and take an extra turn after this one.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

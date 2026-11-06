extends CardScript
## Aura Flux — {2}{U} — Enchantment (common, ulg).
## Oracle: Other enchantments have "At the beginning of your upkeep, sacrifice this enchantment unless you pay {2}."
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Aura Flux", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Other enchantments have \"At the beginning of your upkeep, sacrifice this enchantment unless you pay {2}.\"")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

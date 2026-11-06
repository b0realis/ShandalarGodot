extends CardScript
## Levitation — {2}{U}{U} — Enchantment (uncommon, ulg).
## Oracle: Creatures you control have flying.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Levitation", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures you control have flying.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

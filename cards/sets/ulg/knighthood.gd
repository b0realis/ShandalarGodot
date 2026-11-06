extends CardScript
## Knighthood — {2}{W} — Enchantment (uncommon, ulg).
## Oracle: Creatures you control have first strike.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Knighthood", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures you control have first strike.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

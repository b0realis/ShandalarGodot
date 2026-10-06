extends CardScript
## Pegasus Refuge — {3}{W} — Enchantment (rare, tmp).
## Oracle: {2}, Discard a card: Create a 1/1 white Pegasus creature token with flying.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pegasus Refuge", "{3}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{2}, Discard a card: Create a 1/1 white Pegasus creature token with flying.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

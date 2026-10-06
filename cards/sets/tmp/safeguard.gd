extends CardScript
## Safeguard — {3}{W}{W} — Enchantment (rare, tmp).
## Oracle: {2}{W}: Prevent all combat damage that would be dealt by target creature this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Safeguard", "{3}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{2}{W}: Prevent all combat damage that would be dealt by target creature this turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

extends CardScript
## Tranquil Grove — {1}{G} — Enchantment (rare, wth).
## Oracle: {1}{G}{G}: Destroy all other enchantments.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tranquil Grove", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{1}{G}{G}: Destroy all other enchantments.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

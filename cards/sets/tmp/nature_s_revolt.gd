extends CardScript
## Nature's Revolt — {3}{G}{G} — Enchantment (rare, tmp).
## Oracle: All lands are 2/2 creatures that are still lands.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Nature's Revolt", "{3}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("All lands are 2/2 creatures that are still lands.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

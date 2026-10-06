extends CardScript
## Mirri's Guile — {G} — Enchantment (rare, tmp).
## Oracle: At the beginning of your upkeep, you may look at the top three cards of your library, then put them back in any order.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mirri's Guile", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may look at the top three cards of your library, then put them back in any order.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

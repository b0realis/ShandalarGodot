extends CardScript
## Survival of the Fittest — {1}{G} — Enchantment (rare, exo).
## Oracle: {G}, Discard a creature card: Search your library for a creature card, reveal that card, put it into your hand, then shuffle.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Survival of the Fittest", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{G}, Discard a creature card: Search your library for a creature card, reveal that card, put it into your hand, then shuffle.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

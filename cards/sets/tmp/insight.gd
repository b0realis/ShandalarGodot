extends CardScript
## Insight — {2}{U} — Enchantment (uncommon, tmp).
## Oracle: Whenever an opponent casts a green spell, you draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Insight", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever an opponent casts a green spell, you draw a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

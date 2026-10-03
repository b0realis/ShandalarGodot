extends CardScript
## Unfulfilled Desires — {1}{U}{B} — Enchantment (rare, mir).
## Oracle: {1}, Pay 1 life: Draw a card, then discard a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Unfulfilled Desires", "{1}{U}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{1}, Pay 1 life: Draw a card, then discard a card.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

extends CardScript
## Pursuit of Knowledge — {3}{W} — Enchantment (rare, sth).
## Oracle: If you would draw a card, you may put a study counter on this enchantment instead.
##         Remove three study counters from this enchantment, Sacrifice this enchantment: Draw seven cards.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pursuit of Knowledge", "{3}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("If you would draw a card, you may put a study counter on this enchantment instead.\nRemove three study counters from this enchantment, Sacrifice this enchantment: Draw seven cards.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

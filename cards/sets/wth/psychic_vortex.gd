extends CardScript
## Psychic Vortex — {2}{U}{U} — Enchantment (rare, wth).
## Oracle: Cumulative upkeep—Draw a card. (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
##         At the beginning of your end step, sacrifice a land and discard your hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Psychic Vortex", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Cumulative upkeep—Draw a card. (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)\nAt the beginning of your end step, sacrifice a land and discard your hand.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

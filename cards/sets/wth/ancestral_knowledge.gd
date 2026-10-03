extends CardScript
## Ancestral Knowledge — {1}{U} — Enchantment (rare, wth).
## Oracle: Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
##         When this enchantment enters, look at the top ten cards of your library, then exile any number of them and put the rest back on top of your library in any order.
##         When this enchantment leaves the battlefield, shuffle your library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ancestral Knowledge", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)\nWhen this enchantment enters, look at the top ten cards of your library, then exile any number of them and put the rest back on top of your library in any order.\nWhen this enchantment leaves the battlefield, shuffle your library.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

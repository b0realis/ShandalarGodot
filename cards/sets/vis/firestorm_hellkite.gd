extends CardScript
## Firestorm Hellkite — {4}{U}{R} — Creature — Dragon (rare, vis).
## Oracle: Flying, trample
##         Cumulative upkeep {U}{R} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Firestorm Hellkite", "{4}{U}{R}", Mtg.CardType.CREATURE)
	c.pt(6, 6)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.TRAMPLE])
	c.oracle("Flying, trample\nCumulative upkeep {U}{R} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

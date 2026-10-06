extends CardScript
## Fylamarid — {1}{U}{U} — Creature — Squid Beast (uncommon, tmp).
## Oracle: Flying
##         This creature can't be blocked by blue creatures.
##         {U}: Target creature becomes blue until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fylamarid", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["squid","beast"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nThis creature can't be blocked by blue creatures.\n{U}: Target creature becomes blue until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

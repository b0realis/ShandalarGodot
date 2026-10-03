extends CardScript
## Canopy Dragon — {4}{G}{G} — Creature — Dragon (rare, mir).
## Oracle: Trample
##         {1}{G}: This creature gains flying and loses trample until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Canopy Dragon", "{4}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\n{1}{G}: This creature gains flying and loses trample until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

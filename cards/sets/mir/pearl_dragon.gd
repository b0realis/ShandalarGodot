extends CardScript
## Pearl Dragon — {4}{W}{W} — Creature — Dragon (rare, mir).
## Oracle: Flying
##         {1}{W}: This creature gets +0/+1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pearl Dragon", "{4}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{1}{W}: This creature gets +0/+1 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

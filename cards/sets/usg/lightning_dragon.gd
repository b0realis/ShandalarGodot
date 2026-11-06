extends CardScript
## Lightning Dragon — {2}{R}{R} — Creature — Dragon (rare, usg).
## Oracle: Flying
##         Echo {2}{R}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         {R}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lightning Dragon", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nEcho {2}{R}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\n{R}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

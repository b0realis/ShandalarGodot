extends CardScript
## Spitting Drake — {3}{R} — Creature — Drake (uncommon, vis).
## Oracle: Flying
##         {R}: This creature gets +1/+0 until end of turn. Activate only once each turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spitting Drake", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{R}: This creature gets +1/+0 until end of turn. Activate only once each turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

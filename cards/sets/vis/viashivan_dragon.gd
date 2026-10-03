extends CardScript
## Viashivan Dragon — {2}{R}{R}{G}{G} — Creature — Dragon (rare, vis).
## Oracle: Flying
##         {R}: This creature gets +1/+0 until end of turn.
##         {G}: This creature gets +0/+1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Viashivan Dragon", "{2}{R}{R}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{R}: This creature gets +1/+0 until end of turn.\n{G}: This creature gets +0/+1 until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

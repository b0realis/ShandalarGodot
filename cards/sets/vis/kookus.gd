extends CardScript
## Kookus — {3}{R}{R} — Creature — Djinn (rare, vis).
## Oracle: Trample
##         At the beginning of your upkeep, if you don't control a creature named Keeper of Kookus, this creature deals 3 damage to you and attacks this turn if able.
##         {R}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kookus", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 5)
	c.with_subtypes(["djinn"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nAt the beginning of your upkeep, if you don't control a creature named Keeper of Kookus, this creature deals 3 damage to you and attacks this turn if able.\n{R}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

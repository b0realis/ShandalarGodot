extends CardScript
## Raging Gorilla — {2}{R} — Creature — Ape (common, vis).
## Oracle: Whenever this creature blocks or becomes blocked, it gets +2/-2 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Raging Gorilla", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["ape"])
	c.oracle("Whenever this creature blocks or becomes blocked, it gets +2/-2 until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

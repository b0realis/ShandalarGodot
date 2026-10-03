extends CardScript
## Emberwilde Djinn — {2}{R}{R} — Creature — Djinn (rare, mir).
## Oracle: Flying
##         At the beginning of each player's upkeep, that player may pay {R}{R} or 2 life. If the player does, they gain control of this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Emberwilde Djinn", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["djinn"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nAt the beginning of each player's upkeep, that player may pay {R}{R} or 2 life. If the player does, they gain control of this creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

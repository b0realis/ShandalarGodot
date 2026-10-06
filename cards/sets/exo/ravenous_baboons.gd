extends CardScript
## Ravenous Baboons — {3}{R} — Creature — Monkey (rare, exo).
## Oracle: When this creature enters, destroy target nonbasic land.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ravenous Baboons", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["monkey"])
	c.oracle("When this creature enters, destroy target nonbasic land.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

extends CardScript
## Rank and File — {2}{B}{B} — Creature — Zombie (uncommon, ulg).
## Oracle: When this creature enters, green creatures get -1/-1 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rank and File", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["zombie"])
	c.oracle("When this creature enters, green creatures get -1/-1 until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

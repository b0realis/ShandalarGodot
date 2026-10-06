extends CardScript
## Mind Maggots — {3}{B} — Creature — Insect (uncommon, exo).
## Oracle: When this creature enters, discard any number of creature cards. For each card discarded this way, put two +1/+1 counters on this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mind Maggots", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["insect"])
	c.oracle("When this creature enters, discard any number of creature cards. For each card discarded this way, put two +1/+1 counters on this creature.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

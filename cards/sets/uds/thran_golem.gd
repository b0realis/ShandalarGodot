extends CardScript
## Thran Golem — {5} — Artifact Creature — Golem (rare, uds).
## Oracle: As long as this creature is enchanted, it gets +2/+2 and has flying, first strike, and trample.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thran Golem", "{5}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 3)
	c.with_subtypes(["golem"])
	c.oracle("As long as this creature is enchanted, it gets +2/+2 and has flying, first strike, and trample.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

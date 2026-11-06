extends CardScript
## Metalworker — {3} — Artifact Creature — Construct (rare, uds).
## Oracle: {T}: Reveal any number of artifact cards in your hand. Add {C}{C} for each card revealed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Metalworker", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(1, 2)
	c.with_subtypes(["construct"])
	c.oracle("{T}: Reveal any number of artifact cards in your hand. Add {C}{C} for each card revealed this way.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

extends CardScript
## Brass Secretary — {3} — Artifact Creature — Construct (uncommon, uds).
## Oracle: {2}, Sacrifice this creature: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Brass Secretary", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 1)
	c.with_subtypes(["construct"])
	c.oracle("{2}, Sacrifice this creature: Draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

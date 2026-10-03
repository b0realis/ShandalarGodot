extends CardScript
## Steel Golem — {3} — Artifact Creature — Golem (uncommon, wth).
## Oracle: You can't cast creature spells.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Steel Golem", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 4)
	c.with_subtypes(["golem"])
	c.oracle("You can't cast creature spells.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

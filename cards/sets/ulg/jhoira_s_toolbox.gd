extends CardScript
## Jhoira's Toolbox — {2} — Artifact Creature — Insect (uncommon, ulg).
## Oracle: {2}: Regenerate target artifact creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jhoira's Toolbox", "{2}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.oracle("{2}: Regenerate target artifact creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

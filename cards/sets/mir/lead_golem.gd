extends CardScript
## Lead Golem — {5} — Artifact Creature — Golem (uncommon, mir).
## Oracle: Whenever this creature attacks, it doesn't untap during its controller's next untap step.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lead Golem", "{5}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 5)
	c.with_subtypes(["golem"])
	c.oracle("Whenever this creature attacks, it doesn't untap during its controller's next untap step.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

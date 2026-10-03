extends CardScript
## Igneous Golem — {5} — Artifact Creature — Golem (uncommon, mir).
## Oracle: {2}: This creature gains trample until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Igneous Golem", "{5}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 4)
	c.with_subtypes(["golem"])
	c.oracle("{2}: This creature gains trample until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

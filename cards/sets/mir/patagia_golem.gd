extends CardScript
## Patagia Golem — {4} — Artifact Creature — Golem (uncommon, mir).
## Oracle: {3}: This creature gains flying until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Patagia Golem", "{4}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 3)
	c.with_subtypes(["golem"])
	c.oracle("{3}: This creature gains flying until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

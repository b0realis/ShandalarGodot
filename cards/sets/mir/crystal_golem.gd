extends CardScript
## Crystal Golem — {4} — Artifact Creature — Golem (uncommon, mir).
## Oracle: At the beginning of your end step, this creature phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crystal Golem", "{4}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 3)
	c.with_subtypes(["golem"])
	c.oracle("At the beginning of your end step, this creature phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

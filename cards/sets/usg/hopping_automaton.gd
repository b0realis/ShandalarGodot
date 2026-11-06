extends CardScript
## Hopping Automaton — {3} — Artifact Creature — Construct (uncommon, usg).
## Oracle: {0}: This creature gets -1/-1 and gains flying until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hopping Automaton", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 2)
	c.with_subtypes(["construct"])
	c.oracle("{0}: This creature gets -1/-1 and gains flying until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

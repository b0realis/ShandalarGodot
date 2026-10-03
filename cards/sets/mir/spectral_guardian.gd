extends CardScript
## Spectral Guardian — {2}{W}{W} — Creature — Spirit (rare, mir).
## Oracle: As long as this creature is untapped, noncreature artifacts have shroud. (They can't be the targets of spells or abilities.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spectral Guardian", "{2}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["spirit"])
	c.oracle("As long as this creature is untapped, noncreature artifacts have shroud. (They can't be the targets of spells or abilities.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

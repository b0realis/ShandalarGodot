extends CardScript
## Giant Mantis — {3}{G} — Creature — Insect (common, mir).
## Oracle: Reach (This creature can block creatures with flying.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Giant Mantis", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["insect"])
	c.with_keywords([Mtg.Keyword.REACH])
	c.oracle("Reach (This creature can block creatures with flying.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

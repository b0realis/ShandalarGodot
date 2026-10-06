extends CardScript
## Phyrexian Hulk — {6} — Artifact Creature — Phyrexian Golem (uncommon, tmp).
## Oracle: (No rules text.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Hulk", "{6}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(5, 4)
	c.with_subtypes(["phyrexian","golem"])
	c.oracle("")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

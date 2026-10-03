extends CardScript
## Phyrexian Walker — {0} — Artifact Creature — Phyrexian Construct (common, vis).
## Oracle: (No rules text.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Walker", "{0}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(0, 3)
	c.with_subtypes(["phyrexian","construct"])
	c.oracle("")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

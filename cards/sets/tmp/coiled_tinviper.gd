extends CardScript
## Coiled Tinviper — {3} — Artifact Creature — Snake (common, tmp).
## Oracle: First strike
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Coiled Tinviper", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 1)
	c.with_subtypes(["snake"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

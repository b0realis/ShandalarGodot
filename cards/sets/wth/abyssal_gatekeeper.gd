extends CardScript
## Abyssal Gatekeeper — {1}{B} — Creature — Horror (common, wth).
## Oracle: When this creature dies, each player sacrifices a creature of their choice.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Abyssal Gatekeeper", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["horror"])
	c.oracle("When this creature dies, each player sacrifices a creature of their choice.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

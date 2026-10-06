extends CardScript
## Heartwood Dryad — {1}{G} — Creature — Dryad (common, tmp).
## Oracle: This creature can block creatures with shadow as though it had shadow.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Heartwood Dryad", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["dryad"])
	c.oracle("This creature can block creatures with shadow as though it had shadow.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

extends CardScript
## Clot Sliver — {1}{B} — Creature — Sliver (common, tmp).
## Oracle: All Slivers have "{2}: Regenerate this permanent."
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Clot Sliver", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["sliver"])
	c.oracle("All Slivers have \"{2}: Regenerate this permanent.\"")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

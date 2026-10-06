extends CardScript
## Screeching Harpy — {2}{B}{B} — Creature — Harpy Beast (uncommon, tmp).
## Oracle: Flying
##         {1}{B}: Regenerate this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Screeching Harpy", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["harpy","beast"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{1}{B}: Regenerate this creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

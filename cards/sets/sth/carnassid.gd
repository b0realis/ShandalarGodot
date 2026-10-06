extends CardScript
## Carnassid — {4}{G}{G} — Creature — Beast (rare, sth).
## Oracle: Trample
##         {1}{G}: Regenerate this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Carnassid", "{4}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["beast"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\n{1}{G}: Regenerate this creature.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

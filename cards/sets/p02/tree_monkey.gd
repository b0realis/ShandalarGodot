extends CardScript
## Tree Monkey — {G} — Creature — Monkey — 1/1 (Portal Second Age, 1998).
## Oracle: Reach (This creature can block creatures with flying.)

func build() -> CardData:
	var c := CardData.new("Tree Monkey", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["monkey"])
	c.with_keywords([Mtg.Keyword.REACH])
	c.oracle("Reach (This creature can block creatures with flying.)")
	return c

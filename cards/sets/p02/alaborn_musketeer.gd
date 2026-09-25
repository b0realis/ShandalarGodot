extends CardScript
## Alaborn Musketeer — {1}{W} — Creature — Human Soldier — 2/1 (Portal Second Age, 1998).
## Oracle: Reach (This creature can block creatures with flying.)

func build() -> CardData:
	var c := CardData.new("Alaborn Musketeer", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["human","soldier"])
	c.with_keywords([Mtg.Keyword.REACH])
	c.oracle("Reach (This creature can block creatures with flying.)")
	return c

extends CardScript
## Norwood Archers — {3}{G} — Creature — Elf Archer — 3/3 (Portal Second Age, 1998).
## Oracle: Reach (This creature can block creatures with flying.)

func build() -> CardData:
	var c := CardData.new("Norwood Archers", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["elf","archer"])
	c.with_keywords([Mtg.Keyword.REACH])
	c.oracle("Reach (This creature can block creatures with flying.)")
	return c

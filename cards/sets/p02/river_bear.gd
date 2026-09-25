extends CardScript
## River Bear — {3}{G} — Creature — Bear — 3/3 (Portal Second Age, 1998).
## Oracle: Islandwalk (This creature can't be blocked as long as defending player controls an Island.)

func build() -> CardData:
	var c := CardData.new("River Bear", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["bear"])
	c.with_landwalk(["island"])
	c.oracle("Islandwalk (This creature can't be blocked as long as defending player controls an Island.)")
	return c

extends CardScript
## Bull Hippo — {3}{G} — Creature — Hippo (Portal, 1997).
## Oracle: Islandwalk (This creature can't be blocked as long as defending player controls an Island.)

func build() -> CardData:
	var c := CardData.new("Bull Hippo", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["hippo"])
	c.with_landwalk(["island"])
	c.oracle("Islandwalk (This creature can't be blocked as long as defending player controls an Island.)")
	return c

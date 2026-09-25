extends CardScript
## Wild Ox — {3}{G} — Creature — Ox — 3/3 (Portal Second Age, 1998).
## Oracle: Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)

func build() -> CardData:
	var c := CardData.new("Wild Ox", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["ox"])
	c.with_landwalk(["swamp"])
	c.oracle("Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)")
	return c

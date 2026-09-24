extends CardScript
## Anaconda — {3}{G} — Creature — Snake (Portal, 1997).
## Oracle: Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)

func build() -> CardData:
	var c := CardData.new("Anaconda", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["snake"])
	c.with_landwalk(["swamp"])
	c.oracle("Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)")
	return c

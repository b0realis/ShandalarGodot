extends CardScript
## Bog Raiders — {2}{B} — Creature — Zombie (Portal, 1997).
## Oracle: Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)

func build() -> CardData:
	var c := CardData.new("Bog Raiders", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["zombie"])
	c.with_landwalk(["swamp"])
	c.oracle("Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)")
	return c

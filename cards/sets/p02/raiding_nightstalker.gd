extends CardScript
## Raiding Nightstalker — {2}{B} — Creature — Nightstalker — 2/2 (Portal Second Age, 1998).
## Oracle: Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)

func build() -> CardData:
	var c := CardData.new("Raiding Nightstalker", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["nightstalker"])
	c.with_landwalk(["swamp"])
	c.oracle("Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)")
	return c

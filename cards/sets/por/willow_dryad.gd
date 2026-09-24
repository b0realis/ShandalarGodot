extends CardScript
## Willow Dryad — {G} — Creature — Dryad (Portal, 1997).
## Oracle: Forestwalk (This creature can't be blocked as long as defending player controls a Forest.)

func build() -> CardData:
	var c := CardData.new("Willow Dryad", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["dryad"])
	c.with_landwalk(["forest"])
	c.oracle("Forestwalk (This creature can't be blocked as long as defending player controls a Forest.)")
	return c

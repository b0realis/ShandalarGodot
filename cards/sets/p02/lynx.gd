extends CardScript
## Lynx — {1}{G} — Creature — Cat — 2/1 (Portal Second Age, 1998).
## Oracle: Forestwalk (This creature can't be blocked as long as defending player controls a Forest.)

func build() -> CardData:
	var c := CardData.new("Lynx", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["cat"])
	c.with_landwalk(["forest"])
	c.oracle("Forestwalk (This creature can't be blocked as long as defending player controls a Forest.)")
	return c

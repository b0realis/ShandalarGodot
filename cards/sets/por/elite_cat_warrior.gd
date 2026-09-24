extends CardScript
## Elite Cat Warrior — {2}{G} — Creature — Cat Warrior (Portal, 1997).
## Oracle: Forestwalk (This creature can't be blocked as long as defending player controls a Forest.)

func build() -> CardData:
	var c := CardData.new("Elite Cat Warrior", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["cat", "warrior"])
	c.with_landwalk(["forest"])
	c.oracle("Forestwalk (This creature can't be blocked as long as defending player controls a Forest.)")
	return c

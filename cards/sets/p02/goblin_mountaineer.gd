extends CardScript
## Goblin Mountaineer — {R} — Creature — Goblin Scout — 1/1 (Portal Second Age, 1998).
## Oracle: Mountainwalk (This creature can't be blocked as long as defending player controls a Mountain.)

func build() -> CardData:
	var c := CardData.new("Goblin Mountaineer", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin","scout"])
	c.with_landwalk(["mountain"])
	c.oracle("Mountainwalk (This creature can't be blocked as long as defending player controls a Mountain.)")
	return c

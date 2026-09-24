extends CardScript
## Jungle Lion — {G} — Creature — Cat (Portal, 1997).
## Oracle: This creature can't block.

func build() -> CardData:
	var c := CardData.new("Jungle Lion", "{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["cat"])
	c.oracle("This creature can't block.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

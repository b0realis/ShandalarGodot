extends CardScript
## Craven Knight — {1}{B} — Creature — Human Knight (Portal, 1997).
## Oracle: This creature can't block.

func build() -> CardData:
	var c := CardData.new("Craven Knight", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human", "knight"])
	c.oracle("This creature can't block.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

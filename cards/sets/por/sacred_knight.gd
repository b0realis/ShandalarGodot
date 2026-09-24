extends CardScript
## Sacred Knight — {3}{W} — Creature — Human Knight (Portal, 1997).
## Oracle: This creature can't be blocked by black and/or red creatures.

func build() -> CardData:
	var c := CardData.new("Sacred Knight", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["human", "knight"])
	c.oracle("This creature can't be blocked by black and/or red creatures.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

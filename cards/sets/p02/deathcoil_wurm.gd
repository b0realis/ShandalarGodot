extends CardScript
## Deathcoil Wurm — {6}{G}{G} — Creature — Wurm — 7/6 (Portal Second Age, 1998).
## Oracle: You may have this creature assign its combat damage as though it weren't blocked.

func build() -> CardData:
	var c := CardData.new("Deathcoil Wurm", "{6}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(7, 6)
	c.with_subtypes(["wurm"])
	c.oracle("You may have this creature assign its combat damage as though it weren't blocked.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

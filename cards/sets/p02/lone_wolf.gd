extends CardScript
## Lone Wolf — {2}{G} — Creature — Wolf — 2/2 (Portal Second Age, 1998).
## Oracle: You may have this creature assign its combat damage as though it weren't blocked.

func build() -> CardData:
	var c := CardData.new("Lone Wolf", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["wolf"])
	c.oracle("You may have this creature assign its combat damage as though it weren't blocked.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

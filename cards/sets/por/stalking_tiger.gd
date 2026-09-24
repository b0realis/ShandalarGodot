extends CardScript
## Stalking Tiger — {3}{G} — Creature — Cat (Portal, 1997).
## Oracle: This creature can't be blocked by more than one creature.

func build() -> CardData:
	var c := CardData.new("Stalking Tiger", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["cat"])
	c.oracle("This creature can't be blocked by more than one creature.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

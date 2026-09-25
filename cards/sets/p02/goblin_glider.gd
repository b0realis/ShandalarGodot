extends CardScript
## Goblin Glider — {1}{R} — Creature — Goblin — 1/1 (Portal Second Age, 1998).
## Oracle: Flying
## Oracle: This creature can't block.

func build() -> CardData:
	var c := CardData.new("Goblin Glider", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nThis creature can't block.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

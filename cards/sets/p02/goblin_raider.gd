extends CardScript
## Goblin Raider — {1}{R} — Creature — Goblin Warrior — 2/2 (Portal Second Age, 1998).
## Oracle: This creature can't block.

func build() -> CardData:
	var c := CardData.new("Goblin Raider", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["goblin","warrior"])
	c.oracle("This creature can't block.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

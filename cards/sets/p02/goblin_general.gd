extends CardScript
## Goblin General — {1}{R}{R} — Creature — Goblin Warrior — 1/1 (Portal Second Age, 1998).
## Oracle: Whenever this creature attacks, Goblin creatures you control get +1/+1 until end of turn.

func build() -> CardData:
	var c := CardData.new("Goblin General", "{1}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin","warrior"])
	c.oracle("Whenever this creature attacks, Goblin creatures you control get +1/+1 until end of turn.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

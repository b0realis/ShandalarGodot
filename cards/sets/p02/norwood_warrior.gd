extends CardScript
## Norwood Warrior — {2}{G} — Creature — Elf Warrior — 2/2 (Portal Second Age, 1998).
## Oracle: Whenever this creature becomes blocked, it gets +1/+1 until end of turn.

func build() -> CardData:
	var c := CardData.new("Norwood Warrior", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["elf","warrior"])
	c.oracle("Whenever this creature becomes blocked, it gets +1/+1 until end of turn.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

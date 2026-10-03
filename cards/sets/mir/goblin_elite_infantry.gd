extends CardScript
## Goblin Elite Infantry — {1}{R} — Creature — Goblin Warrior (common, mir).
## Oracle: Whenever this creature blocks or becomes blocked, it gets -1/-1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Elite Infantry", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["goblin","warrior"])
	c.oracle("Whenever this creature blocks or becomes blocked, it gets -1/-1 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

extends CardScript
## Goblin Marshal — {4}{R}{R} — Creature — Goblin Warrior (rare, uds).
## Oracle: Echo {4}{R}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters or dies, create two 1/1 red Goblin creature tokens.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Marshal", "{4}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["goblin","warrior"])
	c.oracle("Echo {4}{R}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters or dies, create two 1/1 red Goblin creature tokens.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

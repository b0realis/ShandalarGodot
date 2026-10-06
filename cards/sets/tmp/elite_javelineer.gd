extends CardScript
## Elite Javelineer — {2}{W} — Creature — Human Soldier (common, tmp).
## Oracle: Whenever this creature blocks, it deals 1 damage to target attacking creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elite Javelineer", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","soldier"])
	c.oracle("Whenever this creature blocks, it deals 1 damage to target attacking creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

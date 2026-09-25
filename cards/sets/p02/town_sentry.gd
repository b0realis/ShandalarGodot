extends CardScript
## Town Sentry — {2}{W} — Creature — Human Soldier — 2/2 (Portal Second Age, 1998).
## Oracle: Whenever this creature blocks, it gets +0/+2 until end of turn.

func build() -> CardData:
	var c := CardData.new("Town Sentry", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","soldier"])
	c.oracle("Whenever this creature blocks, it gets +0/+2 until end of turn.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

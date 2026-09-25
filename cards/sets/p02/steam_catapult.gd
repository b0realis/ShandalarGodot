extends CardScript
## Steam Catapult — {3}{W}{W} — Creature — Human Soldier — 2/3 (Portal Second Age, 1998).
## Oracle: {T}: Destroy target tapped creature. Activate only during your turn, before attackers are declared.

func build() -> CardData:
	var c := CardData.new("Steam Catapult", "{3}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["human","soldier"])
	c.oracle("{T}: Destroy target tapped creature. Activate only during your turn, before attackers are declared.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

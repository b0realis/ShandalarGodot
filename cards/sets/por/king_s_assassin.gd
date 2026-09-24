extends CardScript
## King's Assassin — {1}{B}{B} — Creature — Human Assassin (Portal, 1997).
## Oracle: {T}: Destroy target tapped creature. Activate only during your turn, before attackers are declared.

func build() -> CardData:
	var c := CardData.new("King's Assassin", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human", "assassin"])
	c.oracle("{T}: Destroy target tapped creature. Activate only during your turn, before attackers are declared.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

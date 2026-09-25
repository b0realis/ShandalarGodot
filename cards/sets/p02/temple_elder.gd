extends CardScript
## Temple Elder — {2}{W} — Creature — Human Cleric — 1/2 (Portal Second Age, 1998).
## Oracle: {T}: You gain 1 life. Activate only during your turn, before attackers are declared.

func build() -> CardData:
	var c := CardData.new("Temple Elder", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","cleric"])
	c.oracle("{T}: You gain 1 life. Activate only during your turn, before attackers are declared.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

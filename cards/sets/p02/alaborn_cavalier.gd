extends CardScript
## Alaborn Cavalier — {2}{W}{W} — Creature — Human Knight — 2/2 (Portal Second Age, 1998).
## Oracle: Whenever this creature attacks, you may tap target creature.

func build() -> CardData:
	var c := CardData.new("Alaborn Cavalier", "{2}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.oracle("Whenever this creature attacks, you may tap target creature.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

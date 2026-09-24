extends CardScript
## Seasoned Marshal — {2}{W}{W} — Creature — Human Soldier (Portal, 1997).
## Oracle: Whenever this creature attacks, you may tap target creature.

func build() -> CardData:
	var c := CardData.new("Seasoned Marshal", "{2}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human", "soldier"])
	c.oracle("Whenever this creature attacks, you may tap target creature.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

extends CardScript
## Magma Giant — {5}{R}{R} — Creature — Giant — 5/5 (Portal Second Age, 1998).
## Oracle: When this creature enters, it deals 2 damage to each creature and each player.

func build() -> CardData:
	var c := CardData.new("Magma Giant", "{5}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["giant"])
	c.oracle("When this creature enters, it deals 2 damage to each creature and each player.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

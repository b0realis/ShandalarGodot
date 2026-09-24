extends CardScript
## Fire Imp — {2}{R} — Creature — Imp (Portal, 1997).
## Oracle: When this creature enters, it deals 2 damage to target creature.

func build() -> CardData:
	var c := CardData.new("Fire Imp", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["imp"])
	c.oracle("When this creature enters, it deals 2 damage to target creature.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

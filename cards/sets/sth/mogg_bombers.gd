extends CardScript
## Mogg Bombers — {3}{R} — Creature — Goblin (common, sth).
## Oracle: When another creature enters, sacrifice this creature and it deals 3 damage to target player or planeswalker.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mogg Bombers", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["goblin"])
	c.oracle("When another creature enters, sacrifice this creature and it deals 3 damage to target player or planeswalker.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

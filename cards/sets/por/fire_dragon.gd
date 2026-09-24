extends CardScript
## Fire Dragon — {6}{R}{R}{R} — Creature — Dragon (Portal, 1997).
## Oracle: Flying
## Oracle: When this creature enters, it deals damage to target creature equal to the number of Mountains you control.

func build() -> CardData:
	var c := CardData.new("Fire Dragon", "{6}{R}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(6, 6)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, it deals damage to target creature equal to the number of Mountains you control.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

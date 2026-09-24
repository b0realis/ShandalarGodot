extends CardScript
## Cloud Dragon — {5}{U} — Creature — Illusion Dragon (Portal, 1997).
## Oracle: Flying
## Oracle: This creature can block only creatures with flying.

func build() -> CardData:
	var c := CardData.new("Cloud Dragon", "{5}{U}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["illusion", "dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nThis creature can block only creatures with flying.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

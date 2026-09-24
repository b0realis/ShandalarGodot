extends CardScript
## Cloud Spirit — {2}{U} — Creature — Spirit (Portal, 1997).
## Oracle: Flying
## Oracle: This creature can block only creatures with flying.

func build() -> CardData:
	var c := CardData.new("Cloud Spirit", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 1)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nThis creature can block only creatures with flying.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

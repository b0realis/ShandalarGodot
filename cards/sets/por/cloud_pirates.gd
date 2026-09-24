extends CardScript
## Cloud Pirates — {U} — Creature — Human Pirate (Portal, 1997).
## Oracle: Flying
## Oracle: This creature can block only creatures with flying.

func build() -> CardData:
	var c := CardData.new("Cloud Pirates", "{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human", "pirate"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nThis creature can block only creatures with flying.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

extends CardScript
## Deep-Sea Serpent — {4}{U}{U} — Creature — Serpent (Portal, 1997).
## Oracle: This creature can't attack unless defending player controls an Island.

func build() -> CardData:
	var c := CardData.new("Deep-Sea Serpent", "{4}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["serpent"])
	c.oracle("This creature can't attack unless defending player controls an Island.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

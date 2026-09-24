extends CardScript
## Alabaster Dragon — {4}{W}{W} — Creature — Dragon (Portal, 1997).
## Oracle: Flying
## Oracle: When this creature dies, shuffle it into its owner's library.

func build() -> CardData:
	var c := CardData.new("Alabaster Dragon", "{4}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature dies, shuffle it into its owner's library.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

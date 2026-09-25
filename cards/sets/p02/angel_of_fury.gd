extends CardScript
## Angel of Fury — {4}{W}{W} — Creature — Angel — 3/5 (Portal Second Age, 1998).
## Oracle: Flying
## Oracle: When this creature dies, you may shuffle it into its owner's library.

func build() -> CardData:
	var c := CardData.new("Angel of Fury", "{4}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 5)
	c.with_subtypes(["angel"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature dies, you may shuffle it into its owner's library.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

extends CardScript
## Foul Spirit — {2}{B} — Creature — Spirit — 3/2 (Portal Second Age, 1998).
## Oracle: Flying
## Oracle: When this creature enters, sacrifice a land.

func build() -> CardData:
	var c := CardData.new("Foul Spirit", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, sacrifice a land.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

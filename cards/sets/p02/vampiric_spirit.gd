extends CardScript
## Vampiric Spirit — {2}{B}{B} — Creature — Spirit — 4/3 (Portal Second Age, 1998).
## Oracle: Flying
## Oracle: When this creature enters, you lose 4 life.

func build() -> CardData:
	var c := CardData.new("Vampiric Spirit", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, you lose 4 life.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

extends CardScript
## Dread Reaper — {3}{B}{B}{B} — Creature — Horror (Portal, 1997).
## Oracle: Flying
## Oracle: When this creature enters, you lose 5 life.

func build() -> CardData:
	var c := CardData.new("Dread Reaper", "{3}{B}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(6, 5)
	c.with_subtypes(["horror"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, you lose 5 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

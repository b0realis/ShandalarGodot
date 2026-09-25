extends CardScript
## Angel of Mercy — {4}{W} — Creature — Angel — 3/3 (Portal Second Age, 1998).
## Oracle: Flying
## Oracle: When this creature enters, you gain 3 life.

func build() -> CardData:
	var c := CardData.new("Angel of Mercy", "{4}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["angel"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, you gain 3 life.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

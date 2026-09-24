extends CardScript
## Ingenious Thief — {1}{U} — Creature — Human Rogue (Portal, 1997).
## Oracle: Flying
## Oracle: When this creature enters, look at target player's hand.

func build() -> CardData:
	var c := CardData.new("Ingenious Thief", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human", "rogue"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, look at target player's hand.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

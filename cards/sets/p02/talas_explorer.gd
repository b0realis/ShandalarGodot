extends CardScript
## Talas Explorer — {1}{U} — Creature — Human Pirate Scout — 1/1 (Portal Second Age, 1998).
## Oracle: Flying
## Oracle: When this creature enters, look at target opponent's hand.

func build() -> CardData:
	var c := CardData.new("Talas Explorer", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","pirate","scout"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, look at target opponent's hand.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

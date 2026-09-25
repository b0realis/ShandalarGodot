extends CardScript
## Temple Acolyte — {1}{W} — Creature — Human Cleric — 1/3 (Portal Second Age, 1998).
## Oracle: When this creature enters, you gain 3 life.

func build() -> CardData:
	var c := CardData.new("Temple Acolyte", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["human","cleric"])
	c.oracle("When this creature enters, you gain 3 life.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

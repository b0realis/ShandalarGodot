extends CardScript
## Alaborn Zealot — {W} — Creature — Human Soldier — 1/1 (Portal Second Age, 1998).
## Oracle: When this creature blocks a creature, destroy both creatures.

func build() -> CardData:
	var c := CardData.new("Alaborn Zealot", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","soldier"])
	c.oracle("When this creature blocks a creature, destroy both creatures.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

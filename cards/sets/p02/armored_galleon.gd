extends CardScript
## Armored Galleon — {4}{U} — Creature — Human Pirate — 5/4 (Portal Second Age, 1998).
## Oracle: This creature can't attack unless defending player controls an Island.

func build() -> CardData:
	var c := CardData.new("Armored Galleon", "{4}{U}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["human","pirate"])
	c.oracle("This creature can't attack unless defending player controls an Island.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

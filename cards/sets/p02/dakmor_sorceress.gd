extends CardScript
## Dakmor Sorceress — {5}{B} — Creature — Human Wizard Sorcerer — */4 (Portal Second Age, 1998).
## Oracle: Dakmor Sorceress's power is equal to the number of Swamps you control.

func build() -> CardData:
	var c := CardData.new("Dakmor Sorceress", "{5}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 4)
	c.with_subtypes(["human","wizard","sorcerer"])
	c.oracle("Dakmor Sorceress's power is equal to the number of Swamps you control.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

extends CardScript
## Carnophage — {B} — Creature — Zombie (common, exo).
## Oracle: At the beginning of your upkeep, tap this creature unless you pay 1 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Carnophage", "{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["zombie"])
	c.oracle("At the beginning of your upkeep, tap this creature unless you pay 1 life.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

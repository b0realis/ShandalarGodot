extends CardScript
## Zealots en-Dal — {3}{W} — Creature — Human Soldier (uncommon, exo).
## Oracle: At the beginning of your upkeep, if all nonland permanents you control are white, you gain 1 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Zealots en-Dal", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["human","soldier"])
	c.oracle("At the beginning of your upkeep, if all nonland permanents you control are white, you gain 1 life.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

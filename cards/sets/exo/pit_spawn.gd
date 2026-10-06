extends CardScript
## Pit Spawn — {4}{B}{B}{B} — Creature — Demon (rare, exo).
## Oracle: First strike
##         At the beginning of your upkeep, sacrifice this creature unless you pay {B}{B}.
##         Whenever this creature deals damage to a creature, exile that creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pit Spawn", "{4}{B}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(6, 4)
	c.with_subtypes(["demon"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike\nAt the beginning of your upkeep, sacrifice this creature unless you pay {B}{B}.\nWhenever this creature deals damage to a creature, exile that creature.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

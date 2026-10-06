extends CardScript
## Dauthi Jackal — {2}{B} — Creature — Dauthi Jackal (common, exo).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         {B}{B}, Sacrifice this creature: Destroy target blocking creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dauthi Jackal", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["dauthi","jackal"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\n{B}{B}, Sacrifice this creature: Destroy target blocking creature.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

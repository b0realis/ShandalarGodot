extends CardScript
## Spined Fluke — {2}{B} — Creature — Worm Horror (uncommon, usg).
## Oracle: When this creature enters, sacrifice a creature.
##         {B}: Regenerate this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spined Fluke", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(5, 1)
	c.with_subtypes(["worm","horror"])
	c.oracle("When this creature enters, sacrifice a creature.\n{B}: Regenerate this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

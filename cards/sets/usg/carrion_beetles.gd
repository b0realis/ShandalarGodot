extends CardScript
## Carrion Beetles — {B} — Creature — Insect (common, usg).
## Oracle: {2}{B}, {T}: Exile up to three target cards from a single graveyard.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Carrion Beetles", "{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.oracle("{2}{B}, {T}: Exile up to three target cards from a single graveyard.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

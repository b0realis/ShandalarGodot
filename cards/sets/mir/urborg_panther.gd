extends CardScript
## Urborg Panther — {2}{B} — Creature — Nightstalker Cat (common, mir).
## Oracle: {B}, Sacrifice this creature: Destroy target creature blocking it.
##         Sacrifice a creature named Feral Shadow, a creature named Breathstealer, and this creature: Search your library for a card named Spirit of the Night, put that card onto the battlefield, then shuffle.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Urborg Panther", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["nightstalker","cat"])
	c.oracle("{B}, Sacrifice this creature: Destroy target creature blocking it.\nSacrifice a creature named Feral Shadow, a creature named Breathstealer, and this creature: Search your library for a card named Spirit of the Night, put that card onto the battlefield, then shuffle.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

extends CardScript
## Jangling Automaton — {3} — Artifact Creature — Construct (common, wth).
## Oracle: Whenever this creature attacks, untap all creatures defending player controls.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jangling Automaton", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 2)
	c.with_subtypes(["construct"])
	c.oracle("Whenever this creature attacks, untap all creatures defending player controls.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

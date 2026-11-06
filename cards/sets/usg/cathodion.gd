extends CardScript
## Cathodion — {3} — Artifact Creature — Construct (uncommon, usg).
## Oracle: When this creature dies, add {C}{C}{C}.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cathodion", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 3)
	c.with_subtypes(["construct"])
	c.oracle("When this creature dies, add {C}{C}{C}.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

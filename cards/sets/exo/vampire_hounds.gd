extends CardScript
## Vampire Hounds — {2}{B} — Creature — Vampire Dog (common, exo).
## Oracle: Discard a creature card: This creature gets +2/+2 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vampire Hounds", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["vampire","dog"])
	c.oracle("Discard a creature card: This creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

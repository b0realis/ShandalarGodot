extends CardScript
## Sewer Rats — {B} — Creature — Rat (common, mir).
## Oracle: {B}, Pay 1 life: This creature gets +1/+0 until end of turn. Activate no more than three times each turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sewer Rats", "{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["rat"])
	c.oracle("{B}, Pay 1 life: This creature gets +1/+0 until end of turn. Activate no more than three times each turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

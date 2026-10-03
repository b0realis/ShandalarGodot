extends CardScript
## Foratog — {2}{G} — Creature — Atog (uncommon, mir).
## Oracle: {G}, Sacrifice a Forest: This creature gets +2/+2 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Foratog", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["atog"])
	c.oracle("{G}, Sacrifice a Forest: This creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

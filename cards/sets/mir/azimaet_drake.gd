extends CardScript
## Azimaet Drake — {2}{U} — Creature — Drake (common, mir).
## Oracle: Flying
##         {U}: This creature gets +1/+0 until end of turn. Activate only once each turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Azimaet Drake", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{U}: This creature gets +1/+0 until end of turn. Activate only once each turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

extends CardScript
## Floodgate — {3}{U} — Creature — Wall (uncommon, mir).
## Oracle: Defender
##         When this creature has flying, sacrifice it.
##         When this creature leaves the battlefield, it deals damage to each nonblue creature without flying equal to half the number of Islands you control, rounded down.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Floodgate", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(0, 5)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender\nWhen this creature has flying, sacrifice it.\nWhen this creature leaves the battlefield, it deals damage to each nonblue creature without flying equal to half the number of Islands you control, rounded down.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

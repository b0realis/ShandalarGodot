extends CardScript
## Bay Falcon — {1}{U} — Creature — Bird (common, mir).
## Oracle: Flying, vigilance
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bay Falcon", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.VIGILANCE])
	c.oracle("Flying, vigilance")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

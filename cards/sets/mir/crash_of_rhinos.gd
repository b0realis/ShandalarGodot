extends CardScript
## Crash of Rhinos — {6}{G}{G} — Creature — Rhino (common, mir).
## Oracle: Trample
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crash of Rhinos", "{6}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(8, 4)
	c.with_subtypes(["rhino"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

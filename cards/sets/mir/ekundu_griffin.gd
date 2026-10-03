extends CardScript
## Ekundu Griffin — {3}{W} — Creature — Griffin (common, mir).
## Oracle: Flying, first strike
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ekundu Griffin", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["griffin"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE])
	c.oracle("Flying, first strike")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

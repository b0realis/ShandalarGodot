extends CardScript
## Iron Tusk Elephant — {4}{W} — Creature — Elephant (uncommon, mir).
## Oracle: Trample
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Iron Tusk Elephant", "{4}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["elephant"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

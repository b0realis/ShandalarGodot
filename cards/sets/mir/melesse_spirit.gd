extends CardScript
## Melesse Spirit — {3}{W}{W} — Creature — Angel Spirit (uncommon, mir).
## Oracle: Flying, protection from black
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Melesse Spirit", "{3}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["angel","spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.with_protection_from(Mtg.ManaColor.B)
	c.oracle("Flying, protection from black")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

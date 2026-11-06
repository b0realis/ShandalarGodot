extends CardScript
## Voice of Grace — {3}{W} — Creature — Angel (uncommon, usg).
## Oracle: Flying, protection from black
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Voice of Grace", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["angel"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.with_protection_from(Mtg.ManaColor.B)
	c.oracle("Flying, protection from black")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

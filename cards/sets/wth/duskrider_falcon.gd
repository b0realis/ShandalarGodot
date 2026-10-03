extends CardScript
## Duskrider Falcon — {1}{W} — Creature — Bird (common, wth).
## Oracle: Flying, protection from black
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Duskrider Falcon", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.with_protection_from(Mtg.ManaColor.B)
	c.oracle("Flying, protection from black")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

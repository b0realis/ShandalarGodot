extends CardScript
## Freewind Falcon — {1}{W} — Creature — Bird (common, vis).
## Oracle: Flying, protection from red
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Freewind Falcon", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.with_protection_from(Mtg.ManaColor.R)
	c.oracle("Flying, protection from red")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

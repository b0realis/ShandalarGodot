extends CardScript
## Tempest Drake — {1}{W}{U} — Creature — Drake (uncommon, vis).
## Oracle: Flying, vigilance
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tempest Drake", "{1}{W}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.VIGILANCE])
	c.oracle("Flying, vigilance")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

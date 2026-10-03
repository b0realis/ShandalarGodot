extends CardScript
## Hazerider Drake — {2}{W}{U} — Creature — Drake (uncommon, mir).
## Oracle: Flying, protection from red
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hazerider Drake", "{2}{W}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.with_protection_from(Mtg.ManaColor.R)
	c.oracle("Flying, protection from red")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

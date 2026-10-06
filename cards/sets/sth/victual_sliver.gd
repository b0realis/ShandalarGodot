extends CardScript
## Victual Sliver — {G}{W} — Creature — Sliver (uncommon, sth).
## Oracle: All Slivers have "{2}, Sacrifice this permanent: You gain 4 life."
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Victual Sliver", "{G}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["sliver"])
	c.oracle("All Slivers have \"{2}, Sacrifice this permanent: You gain 4 life.\"")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

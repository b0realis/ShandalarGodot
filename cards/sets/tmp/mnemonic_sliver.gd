extends CardScript
## Mnemonic Sliver — {2}{U} — Creature — Sliver (uncommon, tmp).
## Oracle: All Slivers have "{2}, Sacrifice this permanent: Draw a card."
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mnemonic Sliver", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["sliver"])
	c.oracle("All Slivers have \"{2}, Sacrifice this permanent: Draw a card.\"")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

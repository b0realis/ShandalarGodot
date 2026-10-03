extends CardScript
## Noble Benefactor — {2}{U} — Creature — Human Cleric (uncommon, wth).
## Oracle: When this creature dies, each player may search their library for a card and put that card into their hand. Then each player who searched their library this way shuffles.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Noble Benefactor", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","cleric"])
	c.oracle("When this creature dies, each player may search their library for a card and put that card into their hand. Then each player who searched their library this way shuffles.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

extends CardScript
## Yavimaya Elder — {1}{G}{G} — Creature — Human Druid (common, uds).
## Oracle: When this creature dies, you may search your library for up to two basic land cards, reveal them, put them into your hand, then shuffle.
##         {2}, Sacrifice this creature: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Yavimaya Elder", "{1}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["human","druid"])
	c.oracle("When this creature dies, you may search your library for up to two basic land cards, reveal them, put them into your hand, then shuffle.\n{2}, Sacrifice this creature: Draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

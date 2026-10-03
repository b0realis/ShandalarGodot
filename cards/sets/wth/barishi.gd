extends CardScript
## Barishi — {2}{G}{G} — Creature — Elemental (uncommon, wth).
## Oracle: When this creature dies, exile it, then shuffle all creature cards from your graveyard into your library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Barishi", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["elemental"])
	c.oracle("When this creature dies, exile it, then shuffle all creature cards from your graveyard into your library.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

extends CardScript
## Veteran Explorer — {G} — Creature — Human Soldier Scout (uncommon, wth).
## Oracle: When this creature dies, each player may search their library for up to two basic land cards, put them onto the battlefield, then shuffle.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Veteran Explorer", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","soldier","scout"])
	c.oracle("When this creature dies, each player may search their library for up to two basic land cards, put them onto the battlefield, then shuffle.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

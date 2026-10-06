extends CardScript
## Sacred Guide — {W} — Creature — Human Cleric (rare, tmp).
## Oracle: {1}{W}, Sacrifice this creature: Reveal cards from the top of your library until you reveal a white card. Put that card into your hand and exile all other cards revealed this way.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sacred Guide", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","cleric"])
	c.oracle("{1}{W}, Sacrifice this creature: Reveal cards from the top of your library until you reveal a white card. Put that card into your hand and exile all other cards revealed this way.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

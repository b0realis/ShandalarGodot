extends CardScript
## Hermit Druid — {1}{G} — Creature — Human Druid (rare, sth).
## Oracle: {G}, {T}: Reveal cards from the top of your library until you reveal a basic land card. Put that card into your hand and all other cards revealed this way into your graveyard.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hermit Druid", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","druid"])
	c.oracle("{G}, {T}: Reveal cards from the top of your library until you reveal a basic land card. Put that card into your hand and all other cards revealed this way into your graveyard.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

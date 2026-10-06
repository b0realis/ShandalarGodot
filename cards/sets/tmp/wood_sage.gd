extends CardScript
## Wood Sage — {G}{U} — Creature — Human Druid (rare, tmp).
## Oracle: {T}: Choose a creature card name. Reveal the top four cards of your library and put all of them with that name into your hand. Put the rest into your graveyard.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wood Sage", "{G}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","druid"])
	c.oracle("{T}: Choose a creature card name. Reveal the top four cards of your library and put all of them with that name into your hand. Put the rest into your graveyard.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

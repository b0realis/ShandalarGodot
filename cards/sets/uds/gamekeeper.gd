extends CardScript
## Gamekeeper — {3}{G} — Creature — Elf (uncommon, uds).
## Oracle: When this creature dies, you may exile it. If you do, reveal cards from the top of your library until you reveal a creature card. Put that card onto the battlefield and put all other cards revealed this way into your graveyard.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gamekeeper", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["elf"])
	c.oracle("When this creature dies, you may exile it. If you do, reveal cards from the top of your library until you reveal a creature card. Put that card onto the battlefield and put all other cards revealed this way into your graveyard.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

extends CardScript
## Mask of the Mimic — {U} — Instant (uncommon, sth).
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
##         Search your library for a card with the same name as target nontoken creature, put that card onto the battlefield, then shuffle.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mask of the Mimic", "{U}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, sacrifice a creature.\nSearch your library for a card with the same name as target nontoken creature, put that card onto the battlefield, then shuffle.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

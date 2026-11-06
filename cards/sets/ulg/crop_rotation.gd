extends CardScript
## Crop Rotation — {G} — Instant (common, ulg).
## Oracle: As an additional cost to cast this spell, sacrifice a land.
##         Search your library for a land card, put that card onto the battlefield, then shuffle.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crop Rotation", "{G}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, sacrifice a land.\nSearch your library for a land card, put that card onto the battlefield, then shuffle.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

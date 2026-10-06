extends CardScript
## Harrow — {2}{G} — Instant (uncommon, tmp).
## Oracle: As an additional cost to cast this spell, sacrifice a land.
##         Search your library for up to two basic land cards, put them onto the battlefield, then shuffle.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Harrow", "{2}{G}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, sacrifice a land.\nSearch your library for up to two basic land cards, put them onto the battlefield, then shuffle.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

extends CardScript
## Worldly Tutor — {G} — Instant (uncommon, mir).
## Oracle: Search your library for a creature card, reveal it, then shuffle and put the card on top.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Worldly Tutor", "{G}", Mtg.CardType.INSTANT)
	c.oracle("Search your library for a creature card, reveal it, then shuffle and put the card on top.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

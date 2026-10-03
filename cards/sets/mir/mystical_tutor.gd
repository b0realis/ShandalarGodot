extends CardScript
## Mystical Tutor — {U} — Instant (uncommon, mir).
## Oracle: Search your library for an instant or sorcery card, reveal it, then shuffle and put that card on top.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mystical Tutor", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Search your library for an instant or sorcery card, reveal it, then shuffle and put that card on top.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

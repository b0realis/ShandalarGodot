extends CardScript
## Tithe — {W} — Instant (rare, vis).
## Oracle: Search your library for a Plains card. If target opponent controls more lands than you, you may search your library for an additional Plains card. Reveal those cards, put them into your hand, then shuffle.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tithe", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Search your library for a Plains card. If target opponent controls more lands than you, you may search your library for an additional Plains card. Reveal those cards, put them into your hand, then shuffle.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

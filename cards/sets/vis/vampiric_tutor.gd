extends CardScript
## Vampiric Tutor — {B} — Instant (rare, vis).
## Oracle: Search your library for a card, then shuffle and put that card on top. You lose 2 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vampiric Tutor", "{B}", Mtg.CardType.INSTANT)
	c.oracle("Search your library for a card, then shuffle and put that card on top. You lose 2 life.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

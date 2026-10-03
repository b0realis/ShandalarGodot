extends CardScript
## Ebony Charm — {B} — Instant (common, mir).
## Oracle: Choose one —
##         • Target opponent loses 1 life and you gain 1 life.
##         • Exile up to three target cards from a single graveyard.
##         • Target creature gains fear until end of turn. (It can't be blocked except by artifact creatures and/or black creatures.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ebony Charm", "{B}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• Target opponent loses 1 life and you gain 1 life.\n• Exile up to three target cards from a single graveyard.\n• Target creature gains fear until end of turn. (It can't be blocked except by artifact creatures and/or black creatures.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

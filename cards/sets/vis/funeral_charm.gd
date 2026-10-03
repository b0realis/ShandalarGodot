extends CardScript
## Funeral Charm — {B} — Instant (common, vis).
## Oracle: Choose one —
##         • Target player discards a card.
##         • Target creature gets +2/-1 until end of turn.
##         • Target creature gains swampwalk until end of turn. (It can't be blocked as long as defending player controls a Swamp.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Funeral Charm", "{B}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• Target player discards a card.\n• Target creature gets +2/-1 until end of turn.\n• Target creature gains swampwalk until end of turn. (It can't be blocked as long as defending player controls a Swamp.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

extends CardScript
## Lull — {1}{G} — Instant (common, usg).
## Oracle: Prevent all combat damage that would be dealt this turn.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lull", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Prevent all combat damage that would be dealt this turn.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

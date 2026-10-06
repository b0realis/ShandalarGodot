extends CardScript
## Provoke — {1}{G} — Instant (common, sth).
## Oracle: Untap target creature you don't control. That creature blocks this turn if able.
##         Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Provoke", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Untap target creature you don't control. That creature blocks this turn if able.\nDraw a card.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

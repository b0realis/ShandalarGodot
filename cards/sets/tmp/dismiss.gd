extends CardScript
## Dismiss — {2}{U}{U} — Instant (uncommon, tmp).
## Oracle: Counter target spell.
##         Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dismiss", "{2}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target spell.\nDraw a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

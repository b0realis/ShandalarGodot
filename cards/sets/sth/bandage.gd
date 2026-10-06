extends CardScript
## Bandage — {W} — Instant (common, sth).
## Oracle: Prevent the next 1 damage that would be dealt to any target this turn.
##         Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bandage", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Prevent the next 1 damage that would be dealt to any target this turn.\nDraw a card.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

extends CardScript
## Scrap — {2}{R} — Instant (common, usg).
## Oracle: Destroy target artifact.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scrap", "{2}{R}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target artifact.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

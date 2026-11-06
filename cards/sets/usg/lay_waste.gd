extends CardScript
## Lay Waste — {3}{R} — Sorcery (common, usg).
## Oracle: Destroy target land.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lay Waste", "{3}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target land.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

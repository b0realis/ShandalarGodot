extends CardScript
## Rejuvenate — {3}{G} — Sorcery (common, usg).
## Oracle: You gain 6 life.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rejuvenate", "{3}{G}", Mtg.CardType.SORCERY)
	c.oracle("You gain 6 life.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

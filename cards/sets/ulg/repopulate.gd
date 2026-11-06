extends CardScript
## Repopulate — {1}{G} — Instant (common, ulg).
## Oracle: Shuffle all creature cards from target player's graveyard into that player's library.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Repopulate", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Shuffle all creature cards from target player's graveyard into that player's library.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

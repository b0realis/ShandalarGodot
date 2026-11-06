extends CardScript
## Unearth — {B} — Sorcery (common, ulg).
## Oracle: Return target creature card with mana value 3 or less from your graveyard to the battlefield.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Unearth", "{B}", Mtg.CardType.SORCERY)
	c.oracle("Return target creature card with mana value 3 or less from your graveyard to the battlefield.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

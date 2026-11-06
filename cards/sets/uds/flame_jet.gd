extends CardScript
## Flame Jet — {1}{R} — Sorcery (common, uds).
## Oracle: Flame Jet deals 3 damage to target player or planeswalker.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flame Jet", "{1}{R}", Mtg.CardType.SORCERY)
	c.oracle("Flame Jet deals 3 damage to target player or planeswalker.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

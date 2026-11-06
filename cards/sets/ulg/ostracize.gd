extends CardScript
## Ostracize — {B} — Sorcery (common, ulg).
## Oracle: Target opponent reveals their hand. You choose a creature card from it. That player discards that card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ostracize", "{B}", Mtg.CardType.SORCERY)
	c.oracle("Target opponent reveals their hand. You choose a creature card from it. That player discards that card.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

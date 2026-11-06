extends CardScript
## Duress — {B} — Sorcery (common, usg).
## Oracle: Target opponent reveals their hand. You choose a noncreature, nonland card from it. That player discards that card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Duress", "{B}", Mtg.CardType.SORCERY)
	c.oracle("Target opponent reveals their hand. You choose a noncreature, nonland card from it. That player discards that card.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

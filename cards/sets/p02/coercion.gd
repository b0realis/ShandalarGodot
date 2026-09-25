extends CardScript
## Coercion — {2}{B} — Sorcery (Portal Second Age, 1998).
## Oracle: Target opponent reveals their hand. You choose a card from it. That player discards that card.

func build() -> CardData:
	var c := CardData.new("Coercion", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Target opponent reveals their hand. You choose a card from it. That player discards that card.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

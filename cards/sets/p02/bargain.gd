extends CardScript
## Bargain — {2}{W} — Sorcery (Portal Second Age, 1998).
## Oracle: Target opponent draws a card.
## Oracle: You gain 7 life.

func build() -> CardData:
	var c := CardData.new("Bargain", "{2}{W}", Mtg.CardType.SORCERY)
	c.oracle("Target opponent draws a card.\nYou gain 7 life.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

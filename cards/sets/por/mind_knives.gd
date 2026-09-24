extends CardScript
## Mind Knives — {1}{B} — Sorcery (Portal, 1997).
## Oracle: Target opponent discards a card at random.

func build() -> CardData:
	var c := CardData.new("Mind Knives", "{1}{B}", Mtg.CardType.SORCERY)
	c.oracle("Target opponent discards a card at random.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

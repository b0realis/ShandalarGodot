extends CardScript
## Baleful Stare — {2}{U} — Sorcery (Portal, 1997).
## Oracle: Target opponent reveals their hand. You draw a card for each Mountain and red card in it.

func build() -> CardData:
	var c := CardData.new("Baleful Stare", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Target opponent reveals their hand. You draw a card for each Mountain and red card in it.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

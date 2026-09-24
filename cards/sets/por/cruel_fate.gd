extends CardScript
## Cruel Fate — {4}{U} — Sorcery (Portal, 1997).
## Oracle: Look at the top five cards of target opponent's library. Put one of those cards into that player's graveyard and the rest on top of their library in any order.

func build() -> CardData:
	var c := CardData.new("Cruel Fate", "{4}{U}", Mtg.CardType.SORCERY)
	c.oracle("Look at the top five cards of target opponent's library. Put one of those cards into that player's graveyard and the rest on top of their library in any order.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

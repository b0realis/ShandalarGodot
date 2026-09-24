extends CardScript
## Ancestral Memories — {2}{U}{U}{U} — Sorcery (Portal, 1997).
## Oracle: Look at the top seven cards of your library. Put two of them into your hand and the rest into your graveyard.

func build() -> CardData:
	var c := CardData.new("Ancestral Memories", "{2}{U}{U}{U}", Mtg.CardType.SORCERY)
	c.oracle("Look at the top seven cards of your library. Put two of them into your hand and the rest into your graveyard.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

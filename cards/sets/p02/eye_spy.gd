extends CardScript
## Eye Spy — {U} — Sorcery (Portal Second Age, 1998).
## Oracle: Look at the top card of target player's library. You may put that card into their graveyard.

func build() -> CardData:
	var c := CardData.new("Eye Spy", "{U}", Mtg.CardType.SORCERY)
	c.oracle("Look at the top card of target player's library. You may put that card into their graveyard.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

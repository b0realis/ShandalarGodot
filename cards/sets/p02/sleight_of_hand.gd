extends CardScript
## Sleight of Hand — {U} — Sorcery (Portal Second Age, 1998).
## Oracle: Look at the top two cards of your library. Put one of them into your hand and the other on the bottom of your library.

func build() -> CardData:
	var c := CardData.new("Sleight of Hand", "{U}", Mtg.CardType.SORCERY)
	c.oracle("Look at the top two cards of your library. Put one of them into your hand and the other on the bottom of your library.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

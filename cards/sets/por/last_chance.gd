extends CardScript
## Last Chance — {R}{R} — Sorcery (Portal, 1997).
## Oracle: Take an extra turn after this one. At the beginning of that turn's end step, you lose the game.

func build() -> CardData:
	var c := CardData.new("Last Chance", "{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Take an extra turn after this one. At the beginning of that turn's end step, you lose the game.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

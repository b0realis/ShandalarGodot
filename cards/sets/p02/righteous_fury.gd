extends CardScript
## Righteous Fury — {4}{W}{W} — Sorcery (Portal Second Age, 1998).
## Oracle: Destroy all tapped creatures. You gain 2 life for each creature destroyed this way.

func build() -> CardData:
	var c := CardData.new("Righteous Fury", "{4}{W}{W}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all tapped creatures. You gain 2 life for each creature destroyed this way.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

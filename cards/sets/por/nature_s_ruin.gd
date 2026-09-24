extends CardScript
## Nature's Ruin — {2}{B} — Sorcery (Portal, 1997).
## Oracle: Destroy all green creatures.

func build() -> CardData:
	var c := CardData.new("Nature's Ruin", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all green creatures.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

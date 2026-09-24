extends CardScript
## Virtue's Ruin — {2}{B} — Sorcery (Portal, 1997).
## Oracle: Destroy all white creatures.

func build() -> CardData:
	var c := CardData.new("Virtue's Ruin", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all white creatures.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

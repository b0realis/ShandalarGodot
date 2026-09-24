extends CardScript
## Blinding Light — {2}{W} — Sorcery (Portal, 1997).
## Oracle: Tap all nonwhite creatures.

func build() -> CardData:
	var c := CardData.new("Blinding Light", "{2}{W}", Mtg.CardType.SORCERY)
	c.oracle("Tap all nonwhite creatures.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

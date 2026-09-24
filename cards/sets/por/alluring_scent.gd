extends CardScript
## Alluring Scent — {1}{G}{G} — Sorcery (Portal, 1997).
## Oracle: All creatures able to block target creature this turn do so.

func build() -> CardData:
	var c := CardData.new("Alluring Scent", "{1}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("All creatures able to block target creature this turn do so.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

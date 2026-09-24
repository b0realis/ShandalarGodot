extends CardScript
## Hand of Death — {2}{B} — Sorcery (Portal, 1997).
## Oracle: Destroy target nonblack creature.

func build() -> CardData:
	var c := CardData.new("Hand of Death", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target nonblack creature.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

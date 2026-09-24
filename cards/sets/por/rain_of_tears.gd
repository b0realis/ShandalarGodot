extends CardScript
## Rain of Tears — {1}{B}{B} — Sorcery (Portal, 1997).
## Oracle: Destroy target land.

func build() -> CardData:
	var c := CardData.new("Rain of Tears", "{1}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target land.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

extends CardScript
## Winter's Grasp — {1}{G}{G} — Sorcery (Portal, 1997).
## Oracle: Destroy target land.

func build() -> CardData:
	var c := CardData.new("Winter's Grasp", "{1}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target land.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

extends CardScript
## Needle Storm — {2}{G} — Sorcery (Portal, 1997).
## Oracle: Needle Storm deals 4 damage to each creature with flying.

func build() -> CardData:
	var c := CardData.new("Needle Storm", "{2}{G}", Mtg.CardType.SORCERY)
	c.oracle("Needle Storm deals 4 damage to each creature with flying.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

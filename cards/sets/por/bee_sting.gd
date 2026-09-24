extends CardScript
## Bee Sting — {3}{G} — Sorcery (Portal, 1997).
## Oracle: Bee Sting deals 2 damage to any target.

func build() -> CardData:
	var c := CardData.new("Bee Sting", "{3}{G}", Mtg.CardType.SORCERY)
	c.oracle("Bee Sting deals 2 damage to any target.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

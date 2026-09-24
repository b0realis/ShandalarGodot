extends CardScript
## Elven Cache — {2}{G}{G} — Sorcery (Portal, 1997).
## Oracle: Return target card from your graveyard to your hand.

func build() -> CardData:
	var c := CardData.new("Elven Cache", "{2}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Return target card from your graveyard to your hand.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

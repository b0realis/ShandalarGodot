extends CardScript
## Breath of Life — {3}{W} — Sorcery (Portal, 1997).
## Oracle: Return target creature card from your graveyard to the battlefield.

func build() -> CardData:
	var c := CardData.new("Breath of Life", "{3}{W}", Mtg.CardType.SORCERY)
	c.oracle("Return target creature card from your graveyard to the battlefield.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

extends CardScript
## Déjà Vu — {2}{U} — Sorcery (Portal, 1997).
## Oracle: Return target sorcery card from your graveyard to your hand.

func build() -> CardData:
	var c := CardData.new("Déjà Vu", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Return target sorcery card from your graveyard to your hand.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

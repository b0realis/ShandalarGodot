extends CardScript
## Fruition — {G} — Sorcery (Portal, 1997).
## Oracle: You gain 1 life for each Forest on the battlefield.

func build() -> CardData:
	var c := CardData.new("Fruition", "{G}", Mtg.CardType.SORCERY)
	c.oracle("You gain 1 life for each Forest on the battlefield.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

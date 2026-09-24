extends CardScript
## Theft of Dreams — {2}{U} — Sorcery (Portal, 1997).
## Oracle: Draw a card for each tapped creature target opponent controls.

func build() -> CardData:
	var c := CardData.new("Theft of Dreams", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Draw a card for each tapped creature target opponent controls.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

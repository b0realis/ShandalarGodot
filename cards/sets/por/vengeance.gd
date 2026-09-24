extends CardScript
## Vengeance — {3}{W} — Sorcery (Portal, 1997).
## Oracle: Destroy target tapped creature.

func build() -> CardData:
	var c := CardData.new("Vengeance", "{3}{W}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target tapped creature.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

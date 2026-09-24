extends CardScript
## Starlight — {1}{W} — Sorcery (Portal, 1997).
## Oracle: You gain 3 life for each black creature target opponent controls.

func build() -> CardData:
	var c := CardData.new("Starlight", "{1}{W}", Mtg.CardType.SORCERY)
	c.oracle("You gain 3 life for each black creature target opponent controls.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

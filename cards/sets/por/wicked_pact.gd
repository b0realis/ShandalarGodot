extends CardScript
## Wicked Pact — {1}{B}{B} — Sorcery (Portal, 1997).
## Oracle: Destroy two target nonblack creatures. You lose 5 life.

func build() -> CardData:
	var c := CardData.new("Wicked Pact", "{1}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy two target nonblack creatures. You lose 5 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

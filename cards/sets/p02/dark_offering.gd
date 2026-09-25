extends CardScript
## Dark Offering — {4}{B}{B} — Sorcery (Portal Second Age, 1998).
## Oracle: Destroy target nonblack creature. You gain 3 life.

func build() -> CardData:
	var c := CardData.new("Dark Offering", "{4}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target nonblack creature. You gain 3 life.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

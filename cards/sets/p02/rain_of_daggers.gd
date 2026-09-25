extends CardScript
## Rain of Daggers — {4}{B}{B} — Sorcery (Portal Second Age, 1998).
## Oracle: Destroy all creatures target opponent controls. You lose 2 life for each creature destroyed this way.

func build() -> CardData:
	var c := CardData.new("Rain of Daggers", "{4}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all creatures target opponent controls. You lose 2 life for each creature destroyed this way.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

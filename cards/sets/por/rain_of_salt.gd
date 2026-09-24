extends CardScript
## Rain of Salt — {4}{R}{R} — Sorcery (Portal, 1997).
## Oracle: Destroy two target lands.

func build() -> CardData:
	var c := CardData.new("Rain of Salt", "{4}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy two target lands.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

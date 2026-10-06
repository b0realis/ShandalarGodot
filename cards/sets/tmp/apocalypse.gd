extends CardScript
## Apocalypse — {2}{R}{R}{R} — Sorcery (rare, tmp).
## Oracle: Exile all permanents. You discard your hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Apocalypse", "{2}{R}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Exile all permanents. You discard your hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

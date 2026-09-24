extends CardScript
## Howling Fury — {2}{B} — Sorcery (Portal, 1997).
## Oracle: Target creature gets +4/+0 until end of turn.

func build() -> CardData:
	var c := CardData.new("Howling Fury", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Target creature gets +4/+0 until end of turn.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

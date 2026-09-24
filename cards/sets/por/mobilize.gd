extends CardScript
## Mobilize — {G} — Sorcery (Portal, 1997).
## Oracle: Untap all creatures you control.

func build() -> CardData:
	var c := CardData.new("Mobilize", "{G}", Mtg.CardType.SORCERY)
	c.oracle("Untap all creatures you control.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

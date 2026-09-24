extends CardScript
## Nature's Cloak — {2}{G} — Sorcery (Portal, 1997).
## Oracle: Green creatures you control gain forestwalk until end of turn. (They can't be blocked as long as defending player controls a Forest.)

func build() -> CardData:
	var c := CardData.new("Nature's Cloak", "{2}{G}", Mtg.CardType.SORCERY)
	c.oracle("Green creatures you control gain forestwalk until end of turn. (They can't be blocked as long as defending player controls a Forest.)")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

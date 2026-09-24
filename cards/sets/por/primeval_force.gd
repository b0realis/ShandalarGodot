extends CardScript
## Primeval Force — {2}{G}{G}{G} — Creature — Elemental (Portal, 1997).
## Oracle: When this creature enters, sacrifice it unless you sacrifice three Forests.

func build() -> CardData:
	var c := CardData.new("Primeval Force", "{2}{G}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(8, 8)
	c.with_subtypes(["elemental"])
	c.oracle("When this creature enters, sacrifice it unless you sacrifice three Forests.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

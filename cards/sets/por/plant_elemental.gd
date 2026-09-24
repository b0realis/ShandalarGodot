extends CardScript
## Plant Elemental — {1}{G} — Creature — Plant Elemental (Portal, 1997).
## Oracle: When this creature enters, sacrifice it unless you sacrifice a Forest.

func build() -> CardData:
	var c := CardData.new("Plant Elemental", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["plant", "elemental"])
	c.oracle("When this creature enters, sacrifice it unless you sacrifice a Forest.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

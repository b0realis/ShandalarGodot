extends CardScript
## Man-o'-War — {2}{U} — Creature — Jellyfish (Portal, 1997).
## Oracle: When this creature enters, return target creature to its owner's hand.

func build() -> CardData:
	var c := CardData.new("Man-o'-War", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["jellyfish"])
	c.oracle("When this creature enters, return target creature to its owner's hand.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

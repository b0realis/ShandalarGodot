extends CardScript
## Thing from the Deep — {6}{U}{U}{U} — Creature — Leviathan (Portal, 1997).
## Oracle: Whenever this creature attacks, sacrifice it unless you sacrifice an Island.

func build() -> CardData:
	var c := CardData.new("Thing from the Deep", "{6}{U}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(9, 9)
	c.with_subtypes(["leviathan"])
	c.oracle("Whenever this creature attacks, sacrifice it unless you sacrifice an Island.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)

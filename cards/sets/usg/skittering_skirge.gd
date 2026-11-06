extends CardScript
## Skittering Skirge — {B}{B} — Creature — Phyrexian Imp (common, usg).
## Oracle: Flying
##         When you cast a creature spell, sacrifice this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skittering Skirge", "{B}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["phyrexian","imp"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen you cast a creature spell, sacrifice this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

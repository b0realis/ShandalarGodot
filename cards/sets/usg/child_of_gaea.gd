extends CardScript
## Child of Gaea — {3}{G}{G}{G} — Creature — Elemental (rare, usg).
## Oracle: Trample
##         At the beginning of your upkeep, sacrifice this creature unless you pay {G}{G}.
##         {1}{G}: Regenerate this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Child of Gaea", "{3}{G}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(7, 7)
	c.with_subtypes(["elemental"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nAt the beginning of your upkeep, sacrifice this creature unless you pay {G}{G}.\n{1}{G}: Regenerate this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

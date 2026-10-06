extends CardScript
## Mirozel — {3}{U} — Creature — Illusion (uncommon, exo).
## Oracle: Flying
##         When this creature becomes the target of a spell or ability, return this creature to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mirozel", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["illusion"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature becomes the target of a spell or ability, return this creature to its owner's hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

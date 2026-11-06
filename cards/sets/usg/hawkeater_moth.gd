extends CardScript
## Hawkeater Moth — {3}{G} — Creature — Insect (uncommon, usg).
## Oracle: Flying
##         Shroud (This creature can't be the target of spells or abilities.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hawkeater Moth", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["insect"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nShroud (This creature can't be the target of spells or abilities.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

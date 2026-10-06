extends CardScript
## Pincher Beetles — {2}{G} — Creature — Insect (common, tmp).
## Oracle: Shroud (This creature can't be the target of spells or abilities.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pincher Beetles", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 1)
	c.with_subtypes(["insect"])
	c.oracle("Shroud (This creature can't be the target of spells or abilities.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

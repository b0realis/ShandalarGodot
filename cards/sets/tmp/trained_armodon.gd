extends CardScript
## Trained Armodon — {1}{G}{G} — Creature — Elephant (common, tmp).
## Oracle: (No rules text.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Trained Armodon", "{1}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["elephant"])
	c.oracle("")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

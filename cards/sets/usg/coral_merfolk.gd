extends CardScript
## Coral Merfolk — {1}{U} — Creature — Merfolk (common, usg).
## Oracle: (No rules text.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Coral Merfolk", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["merfolk"])
	c.oracle("")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

extends CardScript
## Blanchwood Treefolk — {4}{G} — Creature — Treefolk (common, usg).
## Oracle: (No rules text.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blanchwood Treefolk", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 5)
	c.with_subtypes(["treefolk"])
	c.oracle("")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

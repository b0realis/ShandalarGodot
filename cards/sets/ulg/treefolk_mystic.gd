extends CardScript
## Treefolk Mystic — {3}{G} — Creature — Treefolk (common, ulg).
## Oracle: Whenever this creature blocks or becomes blocked by a creature, destroy all Auras attached to that creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Treefolk Mystic", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["treefolk"])
	c.oracle("Whenever this creature blocks or becomes blocked by a creature, destroy all Auras attached to that creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

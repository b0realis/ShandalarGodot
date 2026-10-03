extends CardScript
## Goblin Swine-Rider — {R} — Creature — Goblin (common, vis).
## Oracle: Whenever this creature becomes blocked, it deals 2 damage to each attacking creature and each blocking creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Swine-Rider", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin"])
	c.oracle("Whenever this creature becomes blocked, it deals 2 damage to each attacking creature and each blocking creature.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

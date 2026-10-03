extends CardScript
## Rock Basilisk — {4}{R}{G} — Creature — Basilisk (rare, mir).
## Oracle: Whenever this creature blocks or becomes blocked by a non-Wall creature, destroy that creature at end of combat.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rock Basilisk", "{4}{R}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 5)
	c.with_subtypes(["basilisk"])
	c.oracle("Whenever this creature blocks or becomes blocked by a non-Wall creature, destroy that creature at end of combat.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

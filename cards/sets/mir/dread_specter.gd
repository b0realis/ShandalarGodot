extends CardScript
## Dread Specter — {3}{B} — Creature — Specter (uncommon, mir).
## Oracle: Whenever this creature blocks or becomes blocked by a nonblack creature, destroy that creature at end of combat.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dread Specter", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["specter"])
	c.oracle("Whenever this creature blocks or becomes blocked by a nonblack creature, destroy that creature at end of combat.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

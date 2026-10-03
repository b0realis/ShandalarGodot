extends CardScript
## Restless Dead — {1}{B} — Creature — Skeleton (common, mir).
## Oracle: {B}: Regenerate this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Restless Dead", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["skeleton"])
	c.oracle("{B}: Regenerate this creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

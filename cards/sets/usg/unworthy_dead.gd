extends CardScript
## Unworthy Dead — {1}{B} — Creature — Phyrexian Skeleton (common, usg).
## Oracle: {B}: Regenerate this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Unworthy Dead", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["phyrexian","skeleton"])
	c.oracle("{B}: Regenerate this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

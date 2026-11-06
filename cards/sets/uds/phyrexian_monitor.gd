extends CardScript
## Phyrexian Monitor — {3}{B} — Creature — Phyrexian Skeleton (common, uds).
## Oracle: {B}: Regenerate this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Monitor", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["phyrexian","skeleton"])
	c.oracle("{B}: Regenerate this creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

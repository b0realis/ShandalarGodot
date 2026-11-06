extends CardScript
## Eastern Paladin — {2}{B}{B} — Creature — Phyrexian Zombie Knight (rare, usg).
## Oracle: {B}{B}, {T}: Destroy target green creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Eastern Paladin", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["phyrexian","zombie","knight"])
	c.oracle("{B}{B}, {T}: Destroy target green creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

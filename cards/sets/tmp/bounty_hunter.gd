extends CardScript
## Bounty Hunter — {2}{B}{B} — Creature — Human Archer Minion (rare, tmp).
## Oracle: {T}: Put a bounty counter on target nonblack creature.
##         {T}: Destroy target creature with a bounty counter on it.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bounty Hunter", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","archer","minion"])
	c.oracle("{T}: Put a bounty counter on target nonblack creature.\n{T}: Destroy target creature with a bounty counter on it.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

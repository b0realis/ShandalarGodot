extends CardScript
## Stronghold Assassin — {1}{B}{B} — Creature — Phyrexian Zombie Assassin (rare, sth).
## Oracle: {T}, Sacrifice a creature: Destroy target nonblack creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Stronghold Assassin", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["phyrexian","zombie","assassin"])
	c.oracle("{T}, Sacrifice a creature: Destroy target nonblack creature.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

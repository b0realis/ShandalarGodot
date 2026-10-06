extends CardScript
## Jackal Pup — {R} — Creature — Jackal (uncommon, tmp).
## Oracle: Whenever this creature is dealt damage, it deals that much damage to you.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jackal Pup", "{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["jackal"])
	c.oracle("Whenever this creature is dealt damage, it deals that much damage to you.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

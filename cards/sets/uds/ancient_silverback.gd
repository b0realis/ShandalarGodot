extends CardScript
## Ancient Silverback — {4}{G}{G} — Creature — Ape (rare, uds).
## Oracle: {G}: Regenerate this creature. (The next time this creature would be destroyed this turn, instead tap it, remove it from combat, and heal all damage on it.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ancient Silverback", "{4}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(6, 5)
	c.with_subtypes(["ape"])
	c.oracle("{G}: Regenerate this creature. (The next time this creature would be destroyed this turn, instead tap it, remove it from combat, and heal all damage on it.)")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

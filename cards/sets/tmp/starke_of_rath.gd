extends CardScript
## Starke of Rath — {1}{R}{R} — Legendary Creature — Human Rogue (rare, tmp).
## Oracle: {T}: Destroy target artifact or creature. That permanent's controller gains control of Starke. (This effect lasts indefinitely.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Starke of Rath", "{1}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","rogue"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Destroy target artifact or creature. That permanent's controller gains control of Starke. (This effect lasts indefinitely.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

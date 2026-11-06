extends CardScript
## Rofellos, Llanowar Emissary — {G}{G} — Legendary Creature — Elf Druid (rare, uds).
## Oracle: {T}: Add {G} for each Forest you control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rofellos, Llanowar Emissary", "{G}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["elf","druid"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Add {G} for each Forest you control.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

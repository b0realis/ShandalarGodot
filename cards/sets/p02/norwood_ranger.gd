extends CardScript
## Norwood Ranger — {G} — Creature — Elf Scout Ranger — 1/2 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Norwood Ranger", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["elf","scout","ranger"])
	c.oracle("")
	return c

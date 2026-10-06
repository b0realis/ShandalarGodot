extends CardScript
## Seeker of Skybreak — {1}{G} — Creature — Elf (common, tmp).
## Oracle: {T}: Untap target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Seeker of Skybreak", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["elf"])
	c.oracle("{T}: Untap target creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

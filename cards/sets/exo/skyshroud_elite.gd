extends CardScript
## Skyshroud Elite — {G} — Creature — Elf (uncommon, exo).
## Oracle: This creature gets +1/+2 as long as an opponent controls a nonbasic land.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshroud Elite", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf"])
	c.oracle("This creature gets +1/+2 as long as an opponent controls a nonbasic land.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

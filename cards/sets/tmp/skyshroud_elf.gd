extends CardScript
## Skyshroud Elf — {1}{G} — Creature — Elf Druid (common, tmp).
## Oracle: {T}: Add {G}.
##         {1}: Add {R} or {W}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshroud Elf", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","druid"])
	c.oracle("{T}: Add {G}.\n{1}: Add {R} or {W}.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

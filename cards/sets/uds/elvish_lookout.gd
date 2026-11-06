extends CardScript
## Elvish Lookout — {G} — Creature — Elf (common, uds).
## Oracle: Shroud (This creature can't be the target of spells or abilities.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elvish Lookout", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf"])
	c.oracle("Shroud (This creature can't be the target of spells or abilities.)")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

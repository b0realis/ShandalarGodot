extends CardScript
## Elvish Herder — {G} — Creature — Elf (common, usg).
## Oracle: {G}: Target creature gains trample until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elvish Herder", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf"])
	c.oracle("{G}: Target creature gains trample until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

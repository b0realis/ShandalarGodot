extends CardScript
## Taunting Elf — {G} — Creature — Elf (common, uds).
## Oracle: All creatures able to block this creature do so.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Taunting Elf", "{G}", Mtg.CardType.CREATURE)
	c.pt(0, 1)
	c.with_subtypes(["elf"])
	c.oracle("All creatures able to block this creature do so.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
